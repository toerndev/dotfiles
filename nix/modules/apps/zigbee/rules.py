"""rules.toml -> validated, immutable rules. Pure: no MQTT, no clock.

Everything a person edits lives in rules.toml; this module only parses it and
answers "what should lamp X look like during phase P". Loading is strict --
unknown keys are errors -- because in a file that is edited live, a typo'd key
that is silently ignored is the worst possible failure mode.
"""
import re, tomllib
from dataclasses import dataclass, field, replace
from datetime import timedelta

MAX_FADE_S = 6553          # ZCL transition time is a uint16 of deciseconds
LEVEL_MAX = 254

LAMP_KEYS = {"min_brightness", "max_brightness", "min_kelvin", "max_kelvin",
             "sensors", "program"}
PHASE_OVERRIDES = {"brightness", "kelvin", "program"}
PHASE = "phase"            # a program brightness that means "the lamp's phase look"
MIN = "min"                # a brightness that means "the lamp's min_brightness"


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


def _brightness(v, where, words):
    """A percentage, or one of `words` (PHASE, MIN)."""
    if v in words:
        return v
    try:
        return _percent(v, where)
    except RulesError:
        raise RulesError(f"{where}: expected a percentage 0-100 or "
                         + " or ".join(f'"{w}"' for w in words) + f", got {v!r}") from None


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
    brightness: float | str    # percent, or MIN
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
    sensors: tuple = ()
    program: Program | None = None
    per_phase: dict = field(default_factory=dict)   # phase name -> {key: value}

    def program_at(self, phase):
        return self.per_phase.get(phase.name, {}).get("program", self.program)

    def look(self, phase):
        o = self.per_phase.get(phase.name, {})
        b = o.get("brightness", phase.brightness)
        if b == MIN:
            b = self.min_brightness
        k = o.get("kelvin", phase.kelvin)
        return Look(min(self.max_brightness, max(self.min_brightness, b)),
                    min(self.max_kelvin, max(self.min_kelvin, k)))


@dataclass(frozen=True)
class Sensor:
    name: str
    max_lux: float | None = None   # motion only lights a lamp that is off at or below this


@dataclass(frozen=True, eq=False)
class Rules:
    phases: tuple              # sorted by start
    lamps: dict                # name -> Lamp
    programs: dict             # name -> Program
    sensors: dict = field(default_factory=dict)   # name -> Sensor; only those with settings
    min_brightness: float = 0.0    # [defaults]; lamps without their own inherit it
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
                 _brightness(p["brightness"], f"{where} brightness", (MIN,)),
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
        raise RulesError(f"{where}: a fade needs `to` (percent, 0 = off, or \"min\")")
    return Step(_duration(t["fade"], f"{where} fade", MAX_FADE_S),
                _brightness(t["to"], f"{where} to", (MIN,)))


def _program(name, t):
    where = f"[program.{name}]"
    _keys(t, {"brightness", "after"}, where)
    b = _brightness(t.get("brightness", PHASE), f"{where} brightness", (PHASE, MIN))
    after = t.get("after", [])
    if not isinstance(after, list):
        raise RulesError(f"{where} after: expected a list of steps")
    steps = tuple(_step(i, s, where) for i, s in enumerate(after))
    if any(s.to == 0 for s in steps[:-1]):
        raise RulesError(f"{where} after: a fade to 0 switches the lamp off, "
                         f"which ends the program; it can only be the last step")
    return Program(name, b, steps)


def _resolved(prog, floor, where):
    """`prog` with "min" replaced by this lamp's floor. Programs are shared, so
    "min" can only be resolved per lamp."""
    if MIN not in (prog.brightness, *(s.to for s in prog.after)):
        return prog
    if not floor:
        raise RulesError(f"{where}: [program.{prog.name}] uses \"min\", "
                         f"which needs min_brightness above 0")
    return replace(prog, brightness=floor if prog.brightness == MIN else prog.brightness,
                   after=tuple(replace(s, to=floor) if s.to == MIN else s for s in prog.after))


def _lamp_value(key, v, where, programs):
    if key == "program":
        if v not in programs:
            raise RulesError(f"{where}: no [program.{v}]; defined: "
                             f"{', '.join(sorted(programs)) or 'none'}")
        return programs[v]
    if key in ("kelvin", "min_kelvin", "max_kelvin"):
        return _kelvin(v, where)
    return _percent(v, where)


def _lamp(name, t, phase_names, programs, min_brightness):
    where = f"[lamp.{name}]"
    _keys(t, LAMP_KEYS | phase_names, where)
    kw = {"min_brightness": min_brightness}
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
    floor = kw["min_brightness"]
    if "program" in kw:
        kw["program"] = _resolved(kw["program"], floor, where)
    for pn, o in per_phase.items():
        if "program" in o:
            o["program"] = _resolved(o["program"], floor, f"{where} {pn}.program")
    lamp = Lamp(name, sensors=tuple(sensors), per_phase=per_phase, **kw)
    if lamp.min_brightness > lamp.max_brightness:
        raise RulesError(f"{where}: min_brightness is above max_brightness")
    if lamp.min_kelvin > lamp.max_kelvin:
        raise RulesError(f"{where}: min_kelvin is above max_kelvin")
    if lamp.program is None and (sensors or any("program" in o for o in per_phase.values())):
        raise RulesError(f"{where}: sensors and <phase>.program need a `program` "
                         f"(what the lamp does the rest of the day)")
    return lamp


def _sensor(name, t, used):
    where = f"[sensor.{name}]"
    _keys(t, {"max_lux"}, where)
    if name not in used:
        raise RulesError(f"{where}: no lamp lists {name!r} in its sensors"
                         + (f"; they list: {', '.join(sorted(used))}" if used else ""))
    lux = t.get("max_lux")
    if lux is not None and (isinstance(lux, bool) or not isinstance(lux, (int, float))
                            or lux < 0):
        raise RulesError(f"{where} max_lux: expected lux, a number 0 or above, got {lux!r}")
    return Sensor(name, lux)


def parse(raw):
    _keys(raw, {"defaults", "phase", "lamp", "program", "sensor"}, "top level")
    d = raw.get("defaults", {})
    _keys(d, {"min_brightness", "power_on_fade", "reconcile_fade"}, "[defaults]")
    floor = _percent(d.get("min_brightness", 0), "[defaults] min_brightness")

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
    lamps = {n: _lamp(n, t, set(names), programs, floor) for n, t in lamps.items()}
    sensors = raw.get("sensor", {})
    _keys(sensors, sensors.keys(), "[sensor]")
    used = {s for lamp in lamps.values() for s in lamp.sensors}
    sensors = {n: _sensor(n, t, used) for n, t in sensors.items()}
    for p in phases:
        for lamp in lamps.values():
            if p.brightness == MIN and not lamp.min_brightness and "brightness" not in lamp.per_phase.get(p.name, {}):
                raise RulesError(f"[[phase]] {p.name}: brightness \"min\" would switch "
                                 f"[lamp.{lamp.name}] off; it needs min_brightness above 0")
    return Rules(
        phases=tuple(phases),
        lamps=lamps,
        programs=programs,
        sensors=sensors,
        min_brightness=floor,
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
