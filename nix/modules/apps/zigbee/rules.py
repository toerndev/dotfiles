"""rules.toml -> validated, immutable rules. Pure: no MQTT, no clock.

Everything a person edits lives in rules.toml; this module only parses it and
answers "what should lamp X look like during phase P". Loading is strict --
unknown keys are errors -- because in a file that is edited live, a typo'd key
that is silently ignored is the worst possible failure mode.
"""
import re, tomllib
from dataclasses import dataclass, field
from datetime import timedelta

MAX_FADE_S = 6553          # ZCL transition time is a uint16 of deciseconds
LEVEL_MAX = 254

LAMP_KEYS = {"min_brightness", "max_brightness", "min_kelvin", "max_kelvin",
             "cct_reversed", "sensors", "program"}
PHASE_OVERRIDES = {"brightness", "kelvin", "program"}
PHASE = "phase"            # a program brightness that means "the lamp's phase look"


class RulesError(ValueError):
    pass


def level(percent):
    """Percent -> ZCL level. Anything above 0 is at least level 1 (on)."""
    if percent <= 0:
        return 0
    return max(1, min(LEVEL_MAX, round(percent * LEVEL_MAX / 100)))


def mireds(kelvin):
    return round(1_000_000 / kelvin)


_DURATION = re.compile(r"(?:(\d+)h)?(?:(\d+)m)?(?:(\d+(?:\.\d+)?)s)?")


def _duration(v, where, cap=None):
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        s = float(v)
    elif isinstance(v, str) and (m := _DURATION.fullmatch(v.strip())) and any(m.groups()):
        h, mi, se = m.groups()
        s = int(h or 0) * 3600 + int(mi or 0) * 60 + float(se or 0)
    else:
        raise RulesError(f"{where}: expected seconds or a duration like "
                         f"'90s', '5m', '1h30m', got {v!r}")
    if s < 0 or (cap is not None and s > cap):
        raise RulesError(f"{where}: {s:g}s is outside 0..{cap}s "
                         f"(a Zigbee fade can last at most ~1h49m)")
    return int(s) if s == int(s) else s


def _percent(v, where):
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not 0 <= v <= 100:
        raise RulesError(f"{where}: expected a percentage 0-100, got {v!r}")
    return float(v)


def _kelvin(v, where):
    if isinstance(v, bool) or not isinstance(v, int) or not 1000 <= v <= 10000:
        raise RulesError(f"{where}: expected a colour temperature in kelvin "
                         f"(e.g. 2222 warm, 6250 cold), got {v!r}")
    return v


def _keys(table, allowed, where, required=()):
    if not isinstance(table, dict):
        raise RulesError(f"{where}: expected a table")
    unknown = sorted(set(table) - set(allowed))
    if unknown:
        raise RulesError(f"{where}: unknown key(s) {', '.join(unknown)}; "
                         f"allowed: {', '.join(sorted(allowed))}")
    missing = sorted(set(required) - set(table))
    if missing:
        raise RulesError(f"{where}: missing {', '.join(missing)}")


@dataclass(frozen=True)
class Phase:
    name: str
    start: int                 # minutes after midnight
    brightness: float          # percent
    kelvin: int
    fade: float | None         # seconds; None = only applies when a lamp turns on

    @property
    def at(self):
        return f"{self.start // 60:02d}:{self.start % 60:02d}"


@dataclass(frozen=True)
class Look:
    brightness: float          # percent; 0 = off
    kelvin: int


@dataclass(frozen=True)
class Step:
    secs: float
    to: float | None = None    # percent to fade to; None = hold where it is


@dataclass(frozen=True, eq=False)
class Program:
    """What a lamp does when an input lights it, and after the input lets go."""
    name: str
    brightness: float | str = PHASE    # while held on; PHASE = the phase look
    after: tuple = ()                  # Steps, in order; the last level stays


@dataclass(frozen=True, eq=False)
class Lamp:
    name: str
    min_brightness: float = 0.0
    max_brightness: float = 100.0
    min_kelvin: int = 1000
    max_kelvin: int = 10000
    cct_reversed: bool = False     # WW/CW wired the wrong way round
    sensors: tuple = ()
    program: Program | None = None
    per_phase: dict = field(default_factory=dict)   # phase name -> {key: value}

    def program_at(self, phase):
        return self.per_phase.get(phase.name, {}).get("program", self.program)

    def look(self, phase):
        o = self.per_phase.get(phase.name, {})
        b = o.get("brightness", phase.brightness)
        k = o.get("kelvin", phase.kelvin)
        return Look(min(self.max_brightness, max(self.min_brightness, b)),
                    min(self.max_kelvin, max(self.min_kelvin, k)))


@dataclass(frozen=True, eq=False)
class Rules:
    phases: tuple              # sorted by start
    lamps: dict                # name -> Lamp
    programs: dict             # name -> Program
    power_on_fade: float = 1.0
    reconcile_fade: float = 3.0

    @property
    def sensor_lamps(self):
        """sensor name -> names of the lamps it drives."""
        out = {}
        for lamp in self.lamps.values():
            for s in lamp.sensors:
                out.setdefault(s, []).append(lamp.name)
        return out

    def phase_at(self, now):
        minute = now.hour * 60 + now.minute
        current = self.phases[-1]          # before the first phase: wrap
        for p in self.phases:
            if p.start <= minute:
                current = p
        return current

    def previous(self, phase):
        return self.phases[self.phases.index(phase) - 1]

    def next_boundary(self, now):
        """(when, phase) of the next phase start that has a fade, else None."""
        best = None
        for days in (0, 1):
            for p in self.phases:
                if p.fade is None:
                    continue
                t = now.replace(hour=p.start // 60, minute=p.start % 60,
                                second=0, microsecond=0) + timedelta(days=days)
                if t > now and (best is None or t < best[0]):
                    best = (t, p)
        return best


def _phase(i, p):
    where = f"[[phase]] #{i + 1}"
    _keys(p, {"name", "at", "brightness", "kelvin", "fade"}, where,
          required={"name", "at", "brightness", "kelvin"})
    name = p["name"]
    if not isinstance(name, str) or not re.fullmatch(r"[a-z][a-z0-9_-]*", name):
        raise RulesError(f"{where}: name must be lowercase letters, digits, - or _")
    where = f"[[phase]] {name}"
    m = re.fullmatch(r"(\d{1,2}):(\d{2})", str(p["at"]))
    if not m or int(m[1]) > 23 or int(m[2]) > 59:
        raise RulesError(f"{where}: at must be \"HH:MM\", got {p['at']!r}")
    fade = p.get("fade")
    return Phase(name, int(m[1]) * 60 + int(m[2]),
                 _percent(p["brightness"], f"{where} brightness"),
                 _kelvin(p["kelvin"], f"{where} kelvin"),
                 None if fade is None else _duration(fade, f"{where} fade", MAX_FADE_S))


def _step(i, t, where):
    where = f"{where} after #{i + 1}"
    _keys(t, {"hold", "fade", "to"}, where)
    if ("hold" in t) == ("fade" in t):
        raise RulesError(f"{where}: expected either {{ hold = ... }} "
                         f"or {{ fade = ..., to = ... }}")
    if "hold" in t:
        if "to" in t:
            raise RulesError(f"{where}: a hold stays where it is; `to` needs a fade")
        return Step(_duration(t["hold"], f"{where} hold"))
    if "to" not in t:
        raise RulesError(f"{where}: a fade needs `to` (percent, 0 = off)")
    return Step(_duration(t["fade"], f"{where} fade", MAX_FADE_S),
                _percent(t["to"], f"{where} to"))


def _program(name, t):
    where = f"[program.{name}]"
    _keys(t, {"brightness", "after"}, where)
    b = t.get("brightness", PHASE)
    if b != PHASE:
        try:
            b = _percent(b, f"{where} brightness")
        except RulesError:
            raise RulesError(f"{where} brightness: expected a percentage 0-100 "
                             f"or \"phase\", got {b!r}") from None
    after = t.get("after", [])
    if not isinstance(after, list):
        raise RulesError(f"{where} after: expected a list of steps")
    steps = tuple(_step(i, s, where) for i, s in enumerate(after))
    if any(s.to == 0 for s in steps[:-1]):
        raise RulesError(f"{where} after: a fade to 0 switches the lamp off, "
                         f"which ends the program; it can only be the last step")
    return Program(name, b, steps)


def _lamp_value(key, v, where, programs):
    if key == "program":
        if v not in programs:
            raise RulesError(f"{where}: no [program.{v}]; defined: "
                             f"{', '.join(sorted(programs)) or 'none'}")
        return programs[v]
    if key in ("kelvin", "min_kelvin", "max_kelvin"):
        return _kelvin(v, where)
    if key == "cct_reversed":
        if not isinstance(v, bool):
            raise RulesError(f"{where}: expected true or false, got {v!r}")
        return v
    return _percent(v, where)


def _lamp(name, t, phase_names, programs):
    where = f"[lamp.{name}]"
    _keys(t, LAMP_KEYS | phase_names, where)
    kw = {}
    for key in LAMP_KEYS - {"sensors"}:
        if key in t:
            kw[key] = _lamp_value(key, t[key], f"{where} {key}", programs)
    sensors = t.get("sensors", [])
    if not isinstance(sensors, list) or not all(isinstance(s, str) and s for s in sensors):
        raise RulesError(f"{where} sensors: expected a list of z2m names")
    per_phase = {}
    for pn in phase_names & set(t):
        _keys(t[pn], PHASE_OVERRIDES, f"{where} {pn}.*")
        per_phase[pn] = {k: _lamp_value(k, v, f"{where} {pn}.{k}", programs)
                         for k, v in t[pn].items()}
    lamp = Lamp(name, sensors=tuple(sensors), per_phase=per_phase, **kw)
    if lamp.min_brightness > lamp.max_brightness:
        raise RulesError(f"{where}: min_brightness is above max_brightness")
    if lamp.min_kelvin > lamp.max_kelvin:
        raise RulesError(f"{where}: min_kelvin is above max_kelvin")
    if lamp.program is None and (sensors or any("program" in o for o in per_phase.values())):
        raise RulesError(f"{where}: sensors and <phase>.program need a `program` "
                         f"(what the lamp does the rest of the day)")
    return lamp


def parse(raw):
    _keys(raw, {"defaults", "phase", "lamp", "program"}, "top level")
    d = raw.get("defaults", {})
    _keys(d, {"power_on_fade", "reconcile_fade"}, "[defaults]")

    phases = sorted((_phase(i, p) for i, p in enumerate(raw.get("phase", []))),
                    key=lambda p: p.start)
    if not phases:
        raise RulesError("at least one [[phase]] is required")
    names = [p.name for p in phases]
    for dup in {n for n in names if names.count(n) > 1}:
        raise RulesError(f"phase name {dup!r} is used twice")
    starts = [p.at for p in phases]
    for dup in {s for s in starts if starts.count(s) > 1}:
        raise RulesError(f"two phases start at {dup}")
    for clash in set(names) & LAMP_KEYS:
        raise RulesError(f"phase name {clash!r} clashes with a lamp setting")

    programs = raw.get("program", {})
    _keys(programs, programs.keys(), "[program]")
    programs = {n: _program(n, t) for n, t in programs.items()}
    lamps = raw.get("lamp", {})
    _keys(lamps, lamps.keys(), "[lamp]")
    return Rules(
        phases=tuple(phases),
        lamps={n: _lamp(n, t, set(names), programs) for n, t in lamps.items()},
        programs=programs,
        power_on_fade=_duration(d.get("power_on_fade", 1), "[defaults] power_on_fade", MAX_FADE_S),
        reconcile_fade=_duration(d.get("reconcile_fade", 3), "[defaults] reconcile_fade", MAX_FADE_S),
    )


def load(path):
    try:
        with open(path, "rb") as f:
            raw = tomllib.load(f)
    except tomllib.TOMLDecodeError as e:
        raise RulesError(f"{path}: {e}") from None
    return parse(raw)
