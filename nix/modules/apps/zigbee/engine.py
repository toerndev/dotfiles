"""Behaviour: rules + z2m events + the clock -> lamp commands.

Two kinds of lamp, decided by whether rules.toml gives it a `program`:

  plain       follows the phase. Goes to it when it turns on; at a phase start
              with a `fade`, lamps that are on fade to whatever changed.
  programmed  runs its program (the one for the current phase). An input --
              any of its sensors seeing occupancy -- holds it at the program's
              brightness; when every input has let go, the program's `after`
              steps run in order and the last level stays. Turning the lamp on
              counts as an input that has just let go, lit to the phase look.

Each programmed lamp that is doing something has one Run: where it is in its
program. Inputs and lamps are n:m -- a sensor can drive several lamps, each
with its own program, and a lamp stays held while any of its sensors is.

"Turns on" mostly means MAINS on: wall switches cut power to the drivers, so
z2m's cached state stays ON while a lamp is dark. The reliable signal is the
lamp re-announcing itself (~5s after power returns, README "Lamp facts"), backed up
by availability offline->online and a plain state OFF->ON.

Safety (README "Lamp facts"): colour temperature never switches a lamp on, so it may
go to any lamp. Brightness uses moveToLevelWithOnOff, which does, so it only
goes to lamps already on -- except where lighting up is the point (power on,
an input).
"""
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta

from rules import PHASE, Look, level, mireds

log = logging.getLogger("engine")

DEBOUNCE = timedelta(seconds=15)       # announce + availability + state together
PROBE_WINDOW = timedelta(seconds=10)


def _secs(s):
    return f"{s:g}s" if s < 120 else f"{s / 60:g}m"


def _pct(b):
    return "phase" if b == PHASE else f"{b:g}%"


@dataclass
class Run:
    """Where a programmed lamp is in its program."""
    level: float | str          # what it shows or is fading to; PHASE = the phase look
    held: bool = True           # an input holds it; `after` starts when it lets go
    steps: tuple = ()           # after-steps still to come
    until: datetime | None = None   # end of the current step
    fading: bool = False        # the current step is a fade
    since: datetime | None = None   # when the input let go


class Engine:
    def __init__(self, rules, z2m, now=datetime.now):
        self.rules, self.z2m, self.now = rules, z2m, now
        self.last_power_on = {}    # lamp -> when, for DEBOUNCE
        self.probing = {}          # lamp -> deadline for its /get answer
        self.occupied = {}         # sensor -> bool
        self.runs = {}             # programmed lamp -> Run
        self._warned = None
        self._known = set()        # rule lamps z2m currently has a device for
        self._plan()

    # -- rules -----------------------------------------------------------
    def set_rules(self, rules):
        """A program edit applies at once: running after-steps are redone as if
        the new ones had been in force since the input let go, catching up."""
        self.rules = rules
        for name, run in list(self.runs.items()):
            if name not in rules.lamps or rules.lamps[name].program is None:
                del self.runs[name]
            elif not run.held:
                run.steps, run.until, run.fading = self._program(name).after, run.since, False
                self._advance(name)
        self._plan()
        self.check_names()
        self.reconcile("rules reloaded")

    def _plan(self):
        nb = self.rules.next_boundary(self.now())
        self.boundary_at, self.boundary_phase = nb or (None, None)
        if nb:
            log.info("next scheduled fade: %s at %s", nb[1].name, f"{nb[0]:%a %H:%M}")

    def check_names(self):
        """Warn once about names z2m does not know; pick up lamps that appear.

        A lamp appears when it is paired, or renamed to match the rules. It
        is reconciled at once rather than waiting for its next power-on.
        """
        if not self.z2m.devices:
            return
        known = {n for n in self.rules.lamps if n in self.z2m.devices}
        new, self._known = known - self._known, known
        problems = []
        for name, lamp in self.rules.lamps.items():
            if name not in self.z2m.devices:
                problems.append(f"lamp {name!r} is not a z2m device (not paired, or renamed?)")
            for s in lamp.sensors:
                dev = self.z2m.devices.get(s)
                if dev is None:
                    problems.append(f"sensor {s!r} of {name!r} is not a z2m device")
                elif not dev.occupancy:
                    problems.append(f"sensor {s!r} of {name!r} has no occupancy")
        if problems != self._warned:
            for p in problems:
                log.warning("%s", p)
            if self._warned and not problems:
                log.info("every name in the rules is a z2m device again")
            self._warned = problems
        return new

    # -- commands --------------------------------------------------------
    def _payload(self, name, look, transition, brightness=True, color=True):
        p = {}
        if brightness:
            lvl = level(look.brightness)
            p.update({"brightness": lvl} if lvl else {"state": "OFF"})
        dev = self.z2m.devices.get(name)
        if color and (dev is None or dev.color_temp):
            lamp = self.rules.lamps[name]
            lo, hi = mireds(lamp.max_kelvin), mireds(lamp.min_kelvin)
            if dev:
                lo, hi = max(lo, dev.color_temp[0]), min(hi, dev.color_temp[1])
            ct = max(lo, min(hi, mireds(look.kelvin)))
            if lamp.cct_reversed:
                ct = lo + hi - ct        # mirrored within the lamp's own range
            p["color_temp"] = ct
        if p:
            p["transition"] = transition
        return p

    def light(self, name, transition, why, brightness=PHASE):
        """The phase look, or the phase's colour at a program's brightness."""
        phase = self.rules.phase_at(self.now())
        look = self.rules.lamps[name].look(phase)
        if brightness != PHASE:
            look = Look(brightness, look.kelvin)
        log.info("%s: %s -> %s (%g%%, %dK)", name, why, phase.name,
                 look.brightness, look.kelvin)
        self.z2m.set(name, self._payload(name, look, transition))

    def _occupied(self, lamp):
        return any(self.occupied.get(s) for s in lamp.sensors)

    def _program(self, name):
        return self.rules.lamps[name].program_at(self.rules.phase_at(self.now()))

    def hold(self, name, why):
        """An input holds the lamp on at its program's brightness."""
        prog = self._program(name)
        run = self.runs.get(name)
        if run and run.held:
            return
        if run and run.level == prog.brightness and not run.fading:
            log.info("%s: %s, staying at %s", name, why, _pct(run.level))
        else:
            self.light(name, self.rules.power_on_fade, f"{why} [{prog.name}]", prog.brightness)
        self.runs[name] = Run(prog.brightness)

    def let_go(self, name, why):
        """Every input has let go: run the program's after-steps."""
        run = self.runs.get(name)
        if not run or not run.held:
            return
        prog = self._program(name)
        run.held, run.steps, run.until = False, prog.after, self.now()
        run.since = run.until
        log.info("%s: %s [%s: %s]", name, why, prog.name,
                 ", ".join(f"fade {_secs(s.secs)} to {s.to:g}%" if s.to is not None
                           else f"hold {_secs(s.secs)}" for s in prog.after) or "stay")
        self._advance(name)

    def _advance(self, name):
        run, now = self.runs[name], self.now()
        while run.until is not None and run.until <= now:
            if not run.steps:
                run.until, run.fading = None, False
                if run.level == 0:
                    del self.runs[name]
                log.info("%s: program done, %s", name, "off" if run.level == 0
                         else f"resting at {_pct(run.level)}")
                return
            # From when the last step was due, not when we got here: no drift,
            # and after a suspend the steps catch up to where they should be.
            step, run.steps = run.steps[0], run.steps[1:]
            run.until += timedelta(seconds=step.secs)
            run.fading = step.to is not None
            if run.fading:
                run.level = step.to
                log.info("%s: fading to %g%% over %s", name, step.to, _secs(step.secs))
                lvl = level(step.to)
                self.z2m.set(name, {"brightness": lvl, "transition": step.secs} if lvl
                             else {"state": "OFF", "transition": step.secs})

    def _start(self, name, why, transition):
        """The lamp came on by itself: someone is there, so treat it as an
        input that has just let go -- unless one is still holding."""
        if self._occupied(self.rules.lamps[name]):
            self.runs.pop(name, None)
            self.hold(name, why)
            return
        self.runs[name] = Run(PHASE)
        self.light(name, transition, why)
        self.let_go(name, "nothing holding it")

    # -- triggers --------------------------------------------------------
    def power_on(self, name, why, mains=True):
        lamp = self.rules.lamps[name]
        if not mains and name in self.runs:
            return          # OFF->ON while a run exists: our own command lit it
        now = self.now()
        if now - self.last_power_on.get(name, datetime.min) < DEBOUNCE:
            log.debug("%s: %s ignored (debounce)", name, why)
            return
        self.last_power_on[name] = now
        run = self.runs.get(name)
        if lamp.program is None:
            self.light(name, self.rules.power_on_fade, why)
        elif run and run.held:
            # Mains came back while held: it shows its power-on defaults now.
            self.light(name, self.rules.power_on_fade, why, run.level)
        else:
            self._start(name, why, self.rules.power_on_fade)

    def on_occupancy(self, sensor, occupied):
        """A repeated `true` is motion seen again (~10s apart while it lasts):
        it re-lights a lamp switched off meanwhile; held lamps ignore it."""
        changed = self.occupied.get(sensor) != occupied
        self.occupied[sensor] = occupied
        if not occupied and not changed:
            return
        for name in self.rules.sensor_lamps.get(sensor, []):
            if occupied:
                self.hold(name, f"motion on {sensor}")
            elif not self._occupied(self.rules.lamps[name]):
                self.let_go(name, f"clear on {sensor}")

    def boundary(self, phase):
        """A phase with a fade has started: fade lamps to whatever changed."""
        prev = self.rules.previous(phase)
        log.info("phase %s starts, fading over %s", phase.name, _secs(phase.fade))
        for name, lamp in self.rules.lamps.items():
            new, old = lamp.look(phase), lamp.look(prev)
            run = self.runs.get(name)
            follows = lamp.program is None or (run is not None and run.level == PHASE)
            color = new.kelvin != old.kelvin            # safe on any lamp
            bright = new.brightness != old.brightness and self.z2m.is_on(name) and follows
            payload = self._payload(name, new, phase.fade, brightness=bright, color=color)
            if payload:
                self.z2m.set(name, payload)

    def reconcile(self, why, names=None):
        """Live-read lamps; the ones that answer ON get the current phase.

        A /get is a real ZCL read, so a lamp with its mains cut never answers --
        unlike z2m's cache, which goes on saying ON.
        """
        now = self.now()
        names = [n for n in (names or self.rules.lamps)
                 if self.probing.get(n, datetime.min) < now]     # not already asked
        if not names:
            return
        log.info("%s: reconciling %s", why, ", ".join(names))
        for name in names:
            self.probing[name] = now + PROBE_WINDOW
            self.z2m.get(name)

    def _reconciled(self, name):
        run = self.runs.get(name)
        if self.rules.lamps[name].program is None:
            self.light(name, self.rules.reconcile_fade, "on at reconcile")
        elif run is None:
            # On, and nothing of ours is running (e.g. this service restarted).
            self._start(name, "on at reconcile", self.rules.reconcile_fade)
        elif not run.fading:
            self.light(name, self.rules.reconcile_fade, "on at reconcile", run.level)
        # mid fade: leave it

    # -- event loop hooks ------------------------------------------------
    def on_event(self, ev):
        lamps = self.rules.lamps
        if ev.kind == "bridge" and ev.data.get("online"):
            self.reconcile("z2m online")
        elif ev.kind == "devices":
            new = self.check_names()
            if new:
                self.reconcile("now a z2m device", sorted(new))
        elif ev.kind == "announce" and ev.name in lamps:
            self.power_on(ev.name, "announced (power on)")
        elif ev.kind == "availability" and ev.name in lamps:
            if ev.prev is False and ev.data["online"]:
                self.power_on(ev.name, "back online")
        elif ev.kind == "state":
            if "occupancy" in ev.data and ev.name in self.rules.sensor_lamps:
                self.on_occupancy(ev.name, bool(ev.data["occupancy"]))
            if ev.name in lamps:
                self._lamp_state(ev)

    def _lamp_state(self, ev):
        deadline = self.probing.pop(ev.name, None)
        if ev.data.get("state") == "OFF":
            # Switched off (or our fade to 0): whatever ran is over. A later
            # OFF->ON is then someone switching it on, not our echo.
            self.runs.pop(ev.name, None)
            return
        if ev.data.get("state") != "ON":
            return
        if deadline and self.now() <= deadline:
            self._reconciled(ev.name)
        elif ev.prev.get("state") == "OFF":
            self.power_on(ev.name, "switched on", mains=False)

    def tick(self):
        now = self.now()
        for name, run in list(self.runs.items()):
            if run.until is not None and now >= run.until:
                self._advance(name)
        for name, deadline in list(self.probing.items()):
            if now > deadline:
                del self.probing[name]
                log.info("%s: did not answer (unpowered?), left alone", name)
        if self.boundary_at and now >= self.boundary_at:
            # Normally the planned phase. After a suspend or clock jump the plan
            # can be hours stale, so fade to the phase that is actually current.
            phase = self.rules.phase_at(now)
            if phase.fade is not None:
                self.boundary(phase)
            self._plan()

    def seconds_to_next(self, cap):
        times = [r.until for r in self.runs.values() if r.until is not None]
        times += self.probing.values()
        if self.boundary_at:
            times.append(self.boundary_at)
        if not times:
            return cap
        return max(0.0, min(cap, (min(times) - self.now()).total_seconds()))
