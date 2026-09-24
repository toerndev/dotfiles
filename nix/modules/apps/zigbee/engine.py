"""Behaviour: rules + z2m events + the clock -> lamp commands.

Two kinds of lamp, decided by whether rules.toml gives it `sensors`:

  plain   follows the phase. Goes to it when it turns on; at a phase start
          with a `fade`, lamps that are on fade to whatever changed.
  motion  lit to the phase on occupancy (or power on); when every sensor has
          cleared, waits `hold`, then fades to `idle_brightness` (0 = off)
          over `fade_out`. All three can differ per phase.

"Turns on" mostly means MAINS on: wall switches cut power to the drivers, so
z2m's cached state stays ON while a lamp is dark. The reliable signal is the
lamp re-announcing itself (~5s after power returns, README "Lamp facts"), backed up
by availability offline->online and a plain state OFF->ON.

Safety (README "Lamp facts"): colour temperature never switches a lamp on, so it may
go to any lamp. Brightness uses moveToLevelWithOnOff, which does, so it only
goes to lamps already on -- except where lighting up is the point (power on,
motion).
"""
import logging
from datetime import datetime, timedelta

from rules import level, mireds

log = logging.getLogger("engine")

DEBOUNCE = timedelta(seconds=15)       # announce + availability + state together
PROBE_WINDOW = timedelta(seconds=10)


def _secs(s):
    return f"{s:g}s" if s < 120 else f"{s / 60:g}m"


class Engine:
    def __init__(self, rules, z2m, now=datetime.now):
        self.rules, self.z2m, self.now = rules, z2m, now
        self.last_power_on = {}    # lamp -> when, for DEBOUNCE
        self.probing = {}          # lamp -> deadline for its /get answer
        self.occupied = {}         # sensor -> bool
        self.active = set()        # motion lamps currently lit
        self.fade_at = {}          # motion lamp -> when to start fading out
        self.fading = {}           # motion lamp -> when its fade-out ends
        self._warned = None
        self._known = set()        # rule lamps z2m currently has a device for
        self._plan()

    # -- rules -----------------------------------------------------------
    def set_rules(self, rules):
        self.rules = rules
        for name in list(self.fade_at) + list(self.active):
            if name not in rules.lamps or not rules.lamps[name].motion:
                self.fade_at.pop(name, None)
                self.active.discard(name)
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
            ct = mireds(look.kelvin)
            if dev:
                ct = max(dev.color_temp[0], min(dev.color_temp[1], ct))
            p["color_temp"] = ct
        if p:
            p["transition"] = transition
        return p

    def light(self, name, transition, why):
        phase = self.rules.phase_at(self.now())
        look = self.rules.lamps[name].look(phase)
        log.info("%s: %s -> %s (%g%%, %dK)", name, why, phase.name,
                 look.brightness, look.kelvin)
        self.z2m.set(name, self._payload(name, look, transition))

    def activate(self, name, why):
        self.fade_at.pop(name, None)
        self.fading.pop(name, None)
        self.active.add(name)
        self.light(name, self.rules.power_on_fade, why)

    def _occupied(self, lamp):
        return any(self.occupied.get(s) for s in lamp.sensors)

    def _schedule_fade(self, name):
        lamp = self.rules.lamps[name]
        hold = lamp.param("hold", self.rules.phase_at(self.now()))
        self.fade_at[name] = self.now() + timedelta(seconds=hold)
        log.info("%s: clear, fading out in %s", name, _secs(hold))

    def fade_out(self, name):
        lamp = self.rules.lamps[name]
        phase = self.rules.phase_at(self.now())
        secs, idle = lamp.param("fade_out", phase), lamp.param("idle_brightness", phase)
        self.active.discard(name)
        self.fading[name] = self.now() + timedelta(seconds=secs)
        log.info("%s: fading to %g%% over %s", name, idle, _secs(secs))
        lvl = level(idle)
        self.z2m.set(name, {"brightness": lvl, "transition": secs} if lvl
                     else {"state": "OFF", "transition": secs})

    # -- triggers --------------------------------------------------------
    def power_on(self, name, why):
        now = self.now()
        if now - self.last_power_on.get(name, datetime.min) < DEBOUNCE:
            log.debug("%s: %s ignored (debounce)", name, why)
            return
        self.last_power_on[name] = now
        lamp = self.rules.lamps[name]
        if not lamp.motion:
            self.light(name, self.rules.power_on_fade, why)
        elif name not in self.active:
            # Someone just switched it on, so someone is there: light it, then
            # treat it like motion that has just cleared.
            self.activate(name, why)
            if not self._occupied(lamp):
                self._schedule_fade(name)

    def on_occupancy(self, sensor, occupied):
        if self.occupied.get(sensor) == occupied:
            return
        self.occupied[sensor] = occupied
        for name in self.rules.sensor_lamps.get(sensor, []):
            lamp = self.rules.lamps[name]
            if occupied:
                self.fade_at.pop(name, None)
                if name not in self.active:
                    self.activate(name, f"motion on {sensor}")
            elif name in self.active and not self._occupied(lamp):
                self._schedule_fade(name)

    def boundary(self, phase):
        """A phase with a fade has started: fade lamps to whatever changed."""
        prev = self.rules.previous(phase)
        log.info("phase %s starts, fading over %s", phase.name, _secs(phase.fade))
        for name, lamp in self.rules.lamps.items():
            new, old = lamp.look(phase), lamp.look(prev)
            color = new.kelvin != old.kelvin            # safe on any lamp
            bright = (new.brightness != old.brightness and self.z2m.is_on(name)
                      and (not lamp.motion or name in self.active))
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
        lamp = self.rules.lamps[name]
        if not lamp.motion:
            self.light(name, self.rules.reconcile_fade, "on at reconcile")
            return
        if self.fading.get(name, datetime.min) > self.now():
            return                                  # mid fade-out: leave it
        self.active.add(name)
        self.light(name, self.rules.reconcile_fade, "on at reconcile")
        if not self._occupied(lamp) and name not in self.fade_at:
            self._schedule_fade(name)

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
        if ev.data.get("state") != "ON":
            return
        if deadline and self.now() <= deadline:
            self._reconciled(ev.name)
        elif ev.prev.get("state") == "OFF":
            self.power_on(ev.name, "switched on")

    def tick(self):
        now = self.now()
        for name, at in list(self.fade_at.items()):
            if now >= at:
                del self.fade_at[name]
                self.fade_out(name)
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
        times = [*self.fade_at.values(), *self.probing.values()]
        if self.boundary_at:
            times.append(self.boundary_at)
        if not times:
            return cap
        return max(0.0, min(cap, (min(times) - self.now()).total_seconds()))
