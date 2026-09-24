"""Tests: rule parsing, and the engine against a fake z2m and a fake clock.

  python3 -m unittest -v        # from this directory; needs no broker
"""
import os, tomllib, unittest
from datetime import datetime, timedelta

from engine import Engine
from rules import RulesError, level, load, parse
from z2m import Device, Event

HERE = os.path.dirname(os.path.abspath(__file__))

BASE = """
[[phase]]
name = "day"
at = "06:00"
brightness = 100
kelvin = 6250
[[phase]]
name = "evening"
at = "16:00"
brightness = 100
kelvin = 2222
fade = "30m"
[[phase]]
name = "night"
at = "20:00"
brightness = 0.4
kelvin = 2222
fade = "30m"
[lamp.bedroom]
min_brightness = 30
[lamp.stairs]
[lamp.porch]
sensors = ["pir"]
hold = "10s"
fade_out = "2m"
night.fade_out = "45s"
night.idle_brightness = 5
"""


def rules(extra="", base=BASE):
    return parse(tomllib.loads(base + extra))


def at(h, m=0, s=0):
    return datetime(2026, 9, 24, h, m, s)


class TestRules(unittest.TestCase):
    def test_shipped_rules_file_is_valid(self):
        r = load(os.path.join(HERE, "rules.toml"))
        self.assertIn("bedroom-ceiling", r.lamps)

    def test_phase_lookup_wraps_past_midnight(self):
        r = rules()
        self.assertEqual(r.phase_at(at(5, 59)).name, "night")
        self.assertEqual(r.phase_at(at(6)).name, "day")
        self.assertEqual(r.phase_at(at(16)).name, "evening")
        self.assertEqual(r.phase_at(at(23)).name, "night")

    def test_next_boundary_skips_phases_without_fade(self):
        r = rules()
        self.assertEqual(r.next_boundary(at(3)), (at(16), r.phases[1]))
        self.assertEqual(r.next_boundary(at(17))[1].name, "night")
        when, p = r.next_boundary(at(21))
        self.assertEqual((when, p.name), (at(16) + timedelta(days=1), "evening"))

    def test_min_brightness_and_per_phase_overrides(self):
        r = rules()
        night = r.phases[2]
        self.assertEqual(r.lamps["bedroom"].look(night).brightness, 30)
        self.assertEqual(level(r.lamps["bedroom"].look(night).brightness), 76)
        self.assertEqual(level(r.lamps["stairs"].look(night).brightness), 1)
        self.assertEqual(r.lamps["porch"].param("fade_out", night), 45)
        self.assertEqual(r.lamps["porch"].param("fade_out", r.phases[0]), 120)

    def test_typos_are_errors(self):
        for bad, needle in [
            ("[lamp.x]\nmin_brightnes = 3", "unknown key"),
            ("[lamp.x]\nnigth.fade_out = '1m'", "unknown key"),
            ("[lamp.x]\nnight.fade_ot = '1m'", "unknown key"),
            ("[lamp.x]\nfade_out = '5 minutes'", "duration"),
            ("[lamp.x]\nfade_out = '2h'", "1h49m"),
            ("[lamp.x]\nmin_brightness = 130", "percentage"),
            ("[lamp.x]\nsensors = 'pir'", "list"),
            ("[lamp.x]\nmin_brightness = 50\nmax_brightness = 40", "above"),
        ]:
            with self.subTest(bad), self.assertRaisesRegex(RulesError, needle):
                rules(bad, base=BASE.split("[lamp.bedroom]")[0])


class FakeZ2M:
    def __init__(self, names):
        self.devices = {n: Device(n, "0x" + n, "Router", "m", "v", "", True,
                                  (160, 450), True, False) for n in names}
        self.devices["pir"] = Device("pir", "0xpir", "EndDevice", "m", "v", "", True,
                                     None, False, True)
        self.state, self.online, self.sent, self.gets = {}, {}, [], []

    def set(self, name, payload):
        self.sent.append((name, payload))

    def get(self, name, keys=("state",)):
        self.gets.append(name)

    def is_on(self, name):
        return self.state.get(name, {}).get("state") == "ON" and self.online.get(name, True)

    def take(self):
        out, self.sent = self.sent, []
        return out


class TestEngine(unittest.TestCase):
    def setUp(self):
        self.t = at(12)
        self.z = FakeZ2M(["bedroom", "stairs", "porch"])
        self.e = Engine(rules(), self.z, now=lambda: self.t)

    def ev(self, kind, name="", data=None, prev=None):
        if kind == "state":
            prev = self.z.state.get(name, {})
            self.z.state[name] = {**prev, **data}
        self.e.on_event(Event(kind, name, data or {}, prev))

    def jump(self, t):
        self.t = t
        self.e._plan()

    def advance(self, **kw):
        self.t += timedelta(**kw)
        self.e.tick()

    def test_power_on_day_and_night(self):
        self.ev("announce", "bedroom")
        self.assertEqual(self.z.take(), [("bedroom", {"brightness": 254, "color_temp": 160, "transition": 1})])
        self.jump(at(21))
        self.ev("announce", "bedroom")
        self.ev("announce", "stairs")
        self.assertEqual(self.z.take(), [
            ("bedroom", {"brightness": 76, "color_temp": 450, "transition": 1}),
            ("stairs", {"brightness": 1, "color_temp": 450, "transition": 1})])

    def test_debounce_and_unmanaged_devices(self):
        self.ev("announce", "stairs")
        self.ev("availability", "stairs", {"online": False}, prev=True)
        self.ev("availability", "stairs", {"online": True}, prev=False)
        self.ev("announce", "some-plug")
        self.assertEqual(len(self.z.take()), 1)

    def test_boundaries_send_only_what_changed(self):
        self.ev("state", "bedroom", {"state": "ON"})
        self.ev("state", "stairs", {"state": "OFF"})
        self.z.take()
        self.jump(at(15, 59, 59))
        self.advance(seconds=1)                  # 16:00: colour only, to every lamp
        self.assertEqual(self.z.take(), [
            ("bedroom", {"color_temp": 450, "transition": 1800}),
            ("stairs", {"color_temp": 450, "transition": 1800}),
            ("porch", {"color_temp": 450, "transition": 1800})])
        self.t = at(19, 59, 59)
        self.advance(seconds=1)                  # 20:00: brightness, only lamps ON
        self.assertEqual(self.z.take(), [("bedroom", {"brightness": 76, "transition": 1800})])

    def test_reconcile_touches_only_lamps_that_answer_on(self):
        self.jump(at(21))
        self.ev("bridge", data={"online": True})
        self.assertEqual(self.z.gets, ["bedroom", "stairs", "porch"])
        self.ev("state", "bedroom", {"state": "ON"})
        self.assertEqual(self.z.take(), [("bedroom", {"brightness": 76, "color_temp": 450, "transition": 3})])
        self.advance(seconds=11)                 # stairs never answered
        self.ev("state", "stairs", {"state": "ON"})   # late: not treated as reconcile
        self.assertEqual(self.z.take(), [])

    def test_motion_lamp_cycle(self):
        self.ev("state", "pir", {"occupancy": True})
        self.assertEqual(self.z.take(), [("porch", {"brightness": 254, "color_temp": 160, "transition": 1})])
        self.ev("state", "porch", {"state": "ON"})     # our own echo: no retrigger
        self.ev("state", "pir", {"occupancy": True})   # repeat: nothing
        self.ev("state", "pir", {"occupancy": False})
        self.advance(seconds=9)
        self.assertEqual(self.z.take(), [])            # still in hold
        self.advance(seconds=1)
        self.assertEqual(self.z.take(), [("porch", {"state": "OFF", "transition": 120})])

    def test_motion_during_hold_cancels_fade(self):
        self.ev("state", "pir", {"occupancy": True})
        self.ev("state", "pir", {"occupancy": False})
        self.advance(seconds=5)
        self.ev("state", "pir", {"occupancy": True})
        self.advance(seconds=60)
        self.assertEqual(len(self.z.take()), 1)        # only the first activation

    def test_motion_night_uses_phase_overrides(self):
        self.jump(at(22))
        self.ev("state", "pir", {"occupancy": True})
        self.ev("state", "pir", {"occupancy": False})
        self.advance(seconds=10)
        self.assertEqual(self.z.take(), [
            ("porch", {"brightness": 1, "color_temp": 450, "transition": 1}),
            ("porch", {"brightness": 13, "transition": 45})])

    def test_power_on_of_motion_lamp_lights_then_fades(self):
        self.ev("announce", "porch")
        self.advance(seconds=10)
        self.assertEqual(self.z.take(), [
            ("porch", {"brightness": 254, "color_temp": 160, "transition": 1}),
            ("porch", {"state": "OFF", "transition": 120})])

    def test_stale_boundary_after_suspend_fades_to_current_phase(self):
        self.ev("state", "bedroom", {"state": "ON"})
        self.advance(hours=9)                    # planned 16:00, woke at 21:00
        self.assertEqual(self.z.take(), [("bedroom", {"brightness": 76, "transition": 1800})])
        self.assertEqual(self.e.boundary_at, at(16) + timedelta(days=1))

    def test_lamp_that_appears_in_z2m_is_reconciled(self):
        self.e.check_names()                     # startup: all three known
        self.z.devices["bedroom-new"] = self.z.devices.pop("bedroom")
        self.ev("devices")                       # renamed away: warn, nothing to do
        self.assertEqual(self.z.gets, [])
        self.z.devices["bedroom"] = self.z.devices.pop("bedroom-new")
        self.ev("devices")                       # renamed back to the rules' name
        self.assertEqual(self.z.gets, ["bedroom"])
        self.ev("state", "bedroom", {"state": "ON"})
        self.assertEqual(self.z.take(), [("bedroom", {"brightness": 254, "color_temp": 160, "transition": 3})])

    def test_rules_reload_reconciles(self):
        self.e.set_rules(rules("[lamp.bedroom.day]\nbrightness = 60",
                               base=BASE.replace("[lamp.bedroom]\nmin_brightness = 30\n", "")))
        self.ev("state", "bedroom", {"state": "ON"})
        self.assertEqual(self.z.take(), [("bedroom", {"brightness": 152, "color_temp": 160, "transition": 3})])


if __name__ == "__main__":
    unittest.main()
