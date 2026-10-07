"""Tests: rule parsing, and the engine against a fake z2m and a fake clock.

  python3 -m unittest -v        # from this directory; needs no broker
"""
import os, tomllib, unittest
from datetime import datetime, timedelta

from engine import RECONCILE_EVERY, Engine
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
program = "porch"
night.program = "porch-night"
[program.porch]
after = [{ hold = "10s" }, { fade = "2m", to = 0 }]
[program.porch-night]
after = [{ hold = "10s" }, { fade = "45s", to = 5 }]
"""

HALL = """
[program.hall]
brightness = 100
after = [
  { hold = "3m" },
  { fade = "2m", to = 10 },
  { hold = "15m" },
  { fade = "5s", to = 0 },
]
[lamp.hall]
sensors = ["pir", "pir2"]
program = "hall"
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
        self.assertEqual(r.lamps["porch"].program_at(night).name, "porch-night")
        self.assertEqual(r.lamps["porch"].program_at(r.phases[0]).after[1].secs, 120)

    def test_min_is_each_lamps_floor(self):
        r = rules("""
[defaults]
min_brightness = 11.8
[program.m]
brightness = "min"
after = [{ fade = "4m", to = "min" }, { fade = "0s", to = 0 }]
[lamp.a]
program = "m"
[lamp.b]
min_brightness = 20
program = "m"
""", base=BASE.replace("brightness = 0.4", 'brightness = "min"'))
        a, b, night = r.lamps["a"], r.lamps["b"], r.phases[2]
        self.assertEqual(level(r.min_brightness), 30)
        self.assertEqual((a.program.brightness, a.program.after[0].to), (11.8, 11.8))
        self.assertEqual((b.program.brightness, b.program.after[0].to), (20, 20))
        self.assertEqual(a.look(night).brightness, 11.8)
        self.assertEqual(r.lamps["bedroom"].look(night).brightness, 30)

    def test_min_needs_a_floor(self):
        prog = "[program.m]\nbrightness = 'min'\n[lamp.x]\nprogram = 'm'"
        with self.assertRaisesRegex(RulesError, "needs min_brightness"):
            rules(prog)
        with self.assertRaisesRegex(RulesError, "would switch"):
            rules(base=BASE.replace("brightness = 0.4", 'brightness = "min"'))

    def test_kelvin_range_clamps_the_phase(self):
        r = rules("[lamp.narrow]\nmax_kelvin = 5000\nmin_kelvin = 2700")
        self.assertEqual(r.lamps["narrow"].look(r.phases[0]).kelvin, 5000)
        self.assertEqual(r.lamps["narrow"].look(r.phases[2]).kelvin, 2700)

    def test_typos_are_errors(self):
        for bad, needle in [
            ("[lamp.x]\nmin_brightnes = 3", "unknown key"),
            ("[lamp.x]\nnigth.fade_out = '1m'", "unknown key"),
            ("[lamp.x]\nnight.fade_ot = '1m'", "unknown key"),
            ("[program.p]\nafter = [{ fade = '5 minutes', to = 0 }]", "duration"),
            ("[program.p]\nafter = [{ fade = '2h', to = 0 }]", "1h49m"),
            ("[lamp.x]\nmin_brightness = 130", "percentage"),
            ("[lamp.x]\nsensors = 'pir'", "list"),
            ("[lamp.x]\nmin_brightness = 50\nmax_brightness = 40", "above"),
            ("[lamp.x]\nmin_kelvin = 5000\nmax_kelvin = 4000", "above"),
            ("[lamp.x]\nsensors = ['pir']", "need a `program`"),
            ("[lamp.x]\nprogram = 'nope'", "no \\[program.nope\\]"),
            ("[program.p]\nbrightness = 'phse'", "or \"phase\""),
            ("[program.p]\nafter = [{ fade = '1m', to = 'mn' }]", "or \"min\""),
            ("[program.p]\nafter = [{ hold = '1m', to = 5 }]", "needs a fade"),
            ("[program.p]\nafter = [{ fade = '1m' }]", "needs `to`"),
            ("[program.p]\nafter = [{ hold = '1m', fade = '1m', to = 3 }]", "either"),
            ("[program.p]\nafter = [{ fade = '1m', to = 0 }, { hold = '1m' }]", "last step"),
            ("[program.p]\nafter = [{ wait = '1m' }]", "unknown key"),
        ]:
            with self.subTest(bad), self.assertRaisesRegex(RulesError, needle):
                rules(bad, base=BASE.split("[lamp.bedroom]")[0])


class FakeZ2M:
    def __init__(self, names, sensors=("pir",)):
        self.devices = {n: Device(n, "0x" + n, "Router", "m", "v", "", True,
                                  (160, 450), True, False) for n in names}
        for s in sensors:
            self.devices[s] = Device(s, "0x" + s, "EndDevice", "m", "v", "", True,
                                     None, False, True)
        self.state, self.online, self.sent, self.gets = {}, {}, [], []
        self.lost = set()      # lamps whose commands never arrive

    def set(self, name, payload):
        """z2m updates its cache when the lamp got the command, and only then."""
        self.sent.append((name, payload))
        if name not in self.lost:
            echo = {k: v for k, v in payload.items() if k != "transition"}
            if "brightness" in echo:
                echo["state"] = "ON"
            self.state[name] = {**self.state.get(name, {}), **echo}

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
        self.e.next_reconcile = t + RECONCILE_EVERY

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

    def test_motion_lamp_cycle_and_its_echo(self):
        self.ev("state", "porch", {"state": "OFF"})
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

    def test_lost_command_resends_what_is_missing_with_the_fade_left(self):
        self.ev("state", "bedroom", {"state": "ON"})
        self.z.lost.add("bedroom")
        self.jump(at(15, 59, 59))
        self.advance(seconds=1)                  # 16:00 colour fade, lost
        self.z.take()
        self.z.lost.clear()
        self.advance(seconds=15)
        self.assertEqual(self.z.take(), [("bedroom", {"color_temp": 450, "transition": 1785})])
        self.advance(seconds=15)                 # got through this time
        self.assertEqual(self.z.take(), [])

    def test_switched_off_while_unconfirmed_is_not_relit(self):
        self.ev("state", "stairs", {"state": "ON"})
        self.z.lost.add("stairs")
        self.ev("announce", "stairs")            # brightness and colour, lost
        self.ev("state", "stairs", {"state": "OFF"})
        self.z.take()
        self.advance(seconds=15)                 # colour can't light it: resent
        self.assertEqual(self.z.take(), [("stairs", {"color_temp": 160, "transition": 0})])

    def test_periodic_reconcile_continues_a_phase_fade(self):
        self.jump(at(16, 5))
        self.advance(minutes=10)
        self.assertEqual(self.z.gets, ["bedroom", "stairs", "porch"])
        self.ev("state", "bedroom", {"state": "ON", "brightness": 254, "color_temp": 160})
        self.assertEqual(self.z.take(), [("bedroom", {"brightness": 254, "color_temp": 450, "transition": 900})])
        self.advance(minutes=10)
        self.ev("state", "bedroom", {"state": "ON"})   # live read matches: nothing
        self.assertEqual(self.z.take(), [])



class TestPrograms(unittest.TestCase):
    """A multi-step program, shared sensors, and how runs meet the rest."""

    def setUp(self):
        self.t = at(12)
        self.z = FakeZ2M(["bedroom", "stairs", "porch", "hall"], sensors=("pir", "pir2"))
        self.e = Engine(rules(HALL), self.z, now=lambda: self.t)

    ev, advance, jump = TestEngine.ev, TestEngine.advance, TestEngine.jump

    def sent(self, name):
        return [p for n, p in self.z.take() if n == name]

    def test_hallway_timeline(self):
        self.ev("state", "pir", {"occupancy": True})
        self.assertEqual(self.sent("hall"), [{"brightness": 254, "color_temp": 160, "transition": 1}])
        self.ev("state", "pir", {"occupancy": False})
        self.advance(minutes=3)
        self.assertEqual(self.sent("hall"), [{"brightness": 25, "transition": 120}])
        self.advance(minutes=2)
        self.advance(minutes=14, seconds=59)
        self.assertEqual(self.sent("hall"), [])            # prolonged at 10%
        self.advance(seconds=1)
        self.assertEqual(self.sent("hall"), [{"state": "OFF", "transition": 5}])
        self.advance(seconds=5)
        self.assertNotIn("hall", self.e.runs)

    def test_motion_during_after_starts_over(self):
        self.ev("state", "pir", {"occupancy": True})
        self.ev("state", "pir", {"occupancy": False})
        self.advance(minutes=6)                            # in the 10% hold
        self.z.take()
        self.ev("state", "pir", {"occupancy": True})
        self.assertEqual(self.sent("hall"), [{"brightness": 254, "color_temp": 160, "transition": 1}])
        self.ev("state", "pir", {"occupancy": False})
        self.advance(minutes=2, seconds=59)
        self.assertEqual(self.sent("hall"), [])            # a fresh 3m hold

    def test_lamp_held_while_any_sensor_is(self):
        self.ev("state", "pir", {"occupancy": True})
        self.ev("state", "pir2", {"occupancy": True})
        self.ev("state", "pir", {"occupancy": False})
        self.advance(minutes=10)
        self.assertEqual(len(self.sent("hall")), 1)        # still held by pir2
        self.ev("state", "pir2", {"occupancy": False})
        self.advance(minutes=3)
        self.assertEqual(self.sent("hall"), [{"brightness": 25, "transition": 120}])

    def test_one_sensor_drives_lamps_with_different_programs(self):
        self.ev("state", "pir", {"occupancy": True})
        self.ev("state", "pir", {"occupancy": False})
        self.advance(seconds=10)
        self.assertEqual(self.z.take(), [
            ("porch", {"brightness": 254, "color_temp": 160, "transition": 1}),
            ("hall", {"brightness": 254, "color_temp": 160, "transition": 1}),
            ("porch", {"state": "OFF", "transition": 120})])

    def test_program_brightness_ignores_the_phase_but_not_its_colour(self):
        self.jump(at(23))
        self.ev("state", "pir2", {"occupancy": True})
        self.assertEqual(self.sent("hall"), [{"brightness": 254, "color_temp": 450, "transition": 1}])

    def test_power_on_shows_the_phase_then_runs_after(self):
        self.jump(at(21))
        self.ev("announce", "hall")
        self.assertEqual(self.sent("hall"), [{"brightness": 1, "color_temp": 450, "transition": 1}])
        self.advance(minutes=3)
        self.assertEqual(self.sent("hall"), [{"brightness": 25, "transition": 120}])

    def test_phase_fade_reaches_a_lamp_at_the_phase_look(self):
        self.jump(at(19, 58))
        self.ev("announce", "hall")                        # phase look, holding 3m
        self.ev("state", "hall", {"state": "ON"})
        self.z.take()
        self.jump(at(19, 59, 59))
        self.advance(seconds=1)
        self.assertEqual(self.sent("hall"), [{"brightness": 1, "transition": 1800}])

    def test_phase_fade_leaves_a_program_brightness_alone(self):
        self.ev("state", "pir2", {"occupancy": True})      # held at 100%
        self.ev("state", "hall", {"state": "ON"})
        self.z.take()
        self.jump(at(19, 59, 59))
        self.advance(seconds=1)
        self.assertEqual(self.sent("hall"), [])

    def test_steps_catch_up_after_a_suspend(self):
        self.ev("state", "pir2", {"occupancy": True})
        self.ev("state", "pir2", {"occupancy": False})
        self.z.take()
        self.advance(hours=1)
        self.assertEqual(self.sent("hall"), [{"brightness": 25, "transition": 120},
                                             {"state": "OFF", "transition": 5}])

    def test_motion_relights_a_lamp_switched_off_while_occupied(self):
        self.ev("state", "pir2", {"occupancy": True})
        self.ev("state", "hall", {"state": "ON"})
        self.ev("state", "pir2", {"occupancy": True})      # repeat while lit: nothing
        self.assertEqual(len(self.sent("hall")), 1)
        self.ev("state", "hall", {"state": "OFF"})         # lampctl set --off
        self.ev("state", "pir2", {"occupancy": True})      # next report, ~10s later
        self.assertEqual(self.sent("hall"), [{"brightness": 254, "color_temp": 160, "transition": 1}])

    def test_mains_back_while_held_restores_the_program_level(self):
        self.ev("state", "pir", {"occupancy": True})
        self.z.take()
        self.ev("announce", "hall")
        self.assertEqual(self.sent("hall"), [{"brightness": 254, "color_temp": 160, "transition": 1}])

    def test_switched_off_ends_the_run_and_on_starts_one(self):
        self.ev("state", "pir", {"occupancy": True})
        self.ev("state", "hall", {"state": "ON"})
        self.ev("state", "pir", {"occupancy": False})
        self.ev("state", "hall", {"state": "OFF"})         # from the frontend
        self.assertNotIn("hall", self.e.runs)
        self.z.take()
        self.advance(seconds=20)
        self.ev("state", "hall", {"state": "ON"})          # and on again
        self.assertEqual(self.sent("hall"), [{"brightness": 254, "color_temp": 160, "transition": 1}])
        self.assertEqual(self.e.runs["hall"].level, "phase")

    def test_reconcile_keeps_a_run_where_it_is(self):
        self.ev("state", "pir", {"occupancy": True})
        self.ev("state", "pir", {"occupancy": False})
        self.advance(minutes=6)                            # resting in the 10% hold
        self.z.take()
        self.ev("bridge", data={"online": True})
        self.ev("state", "hall", {"state": "ON"})          # reads as it should be
        self.assertEqual(self.sent("hall"), [])
        self.ev("bridge", data={"online": True})
        self.ev("state", "hall", {"state": "ON", "brightness": 254})
        self.assertEqual(self.sent("hall"), [{"brightness": 25, "color_temp": 160, "transition": 3}])
        self.advance(minutes=14)
        self.assertEqual(self.sent("hall"), [{"state": "OFF", "transition": 5}])

    def test_rules_edit_applies_to_a_running_program_at_once(self):
        self.ev("state", "pir2", {"occupancy": True})
        self.ev("state", "pir2", {"occupancy": False})
        self.advance(minutes=2)                            # 1m into the old 3m hold
        self.z.take()
        self.e.set_rules(rules(HALL.replace('{ hold = "3m" }', '{ hold = "1m" }')))
        self.assertEqual(self.sent("hall"), [{"brightness": 25, "transition": 120}])
        self.advance(minutes=15, seconds=59)               # off at 1m + 2m + 15m after clear
        self.assertEqual(self.sent("hall"), [])
        self.advance(seconds=1)
        self.assertEqual(self.sent("hall"), [{"state": "OFF", "transition": 5}])

    def test_lost_off_is_resent_then_caught_by_the_periodic_check(self):
        self.ev("state", "pir", {"occupancy": True})
        self.ev("state", "pir", {"occupancy": False})
        self.advance(minutes=19, seconds=59)
        self.z.take()
        self.z.lost.add("hall")
        self.advance(seconds=1)
        self.assertEqual(self.sent("hall"), [{"state": "OFF", "transition": 5}])
        for _ in range(2):
            self.advance(seconds=15)
            self.assertEqual(self.sent("hall"), [{"state": "OFF", "transition": 0}])
        self.advance(seconds=15)                           # gives up
        self.assertEqual(self.sent("hall"), [])
        self.assertNotIn("hall", self.e.unconfirmed)
        self.z.lost.clear()
        self.z.gets.clear()
        self.advance(seconds=(self.e.next_reconcile - self.t).total_seconds())
        self.assertIn("hall", self.z.gets)
        self.ev("state", "hall", {"state": "ON"})          # still on: run it again
        self.assertEqual(self.sent("hall"), [{"brightness": 254, "color_temp": 160, "transition": 3}])
        self.advance(minutes=20)
        self.assertEqual(self.sent("hall")[-1], {"state": "OFF", "transition": 5})

    def test_seconds_to_next_wakes_for_steps(self):
        self.ev("state", "pir2", {"occupancy": True})
        self.ev("state", "pir2", {"occupancy": False})
        self.assertEqual(self.e.seconds_to_next(cap=600), 15)      # check it arrived
        self.ev("state", "hall", {"brightness": 254, "color_temp": 160})
        self.assertEqual(self.e.seconds_to_next(cap=600), 180)


if __name__ == "__main__":
    unittest.main()
