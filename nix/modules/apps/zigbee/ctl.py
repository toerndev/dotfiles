#!/usr/bin/env python3
"""lampctl -- pair, name and inspect Zigbee devices through zigbee2mqtt.

  lampctl devices                    what is paired, online, and used by the rules
  lampctl pair                       open joining, report what joins, close joining
  lampctl rename 0x70ac... stairs-bottom
  lampctl startup stairs-bottom      show power-on defaults
  lampctl startup stairs-bottom --safe-floor   ON / min_brightness / 2222K (README "Lamp facts")
  lampctl state stairs-bottom        live read
  lampctl set stairs-bottom --brightness 40 --kelvin 3000 --transition 2
  lampctl check                      validate rules.toml, print each lamp's day
  lampctl doctor                     broker, z2m, coordinator, devices, rules, service

Talks to the same broker as the service; safe to run while it is running.
"""
import argparse, json, os, socket, subprocess, sys, time, uuid
from urllib.parse import urlparse

from rules import MIN, PHASE, RulesError, level, load, mireds
from z2m import Z2M

HERE = os.path.dirname(os.path.abspath(__file__))

# Power-on defaults for wall-switched lamps: always come on, warm, and at the
# level of rules.toml's [defaults] min_brightness -- the night trigger level
# and the last step before off (README "Lamp facts").
SAFE_FLOOR = {"onoff": 1, "kelvin": 2222}
# (label, cluster, ZCL attribute, where z2m publishes the decoded value)
STARTUP = [
    ("on/off", "genOnOff", "startUpOnOff", ("power_on_behavior",)),
    ("level", "genLevelCtrl", "startUpCurrentLevel", ("level_config", "current_level_startup")),
    ("colour temp", "lightingColorCtrl", "startUpColorTemperature", ("color_temp_startup",)),
]


def _dig(d, path):
    for k in path:
        d = d.get(k) if isinstance(d, dict) else None
    return d


def connect(a):
    z = Z2M(a.host, a.port, a.base)
    z.connect()
    # Retained bridge/devices and availability arrive in several bursts after
    # subscribing: read until the broker has been quiet for a moment.
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        seen = z.received
        z.poll(0.3)
        if z.received == seen and z.devices:
            break
    if not z.devices:
        sys.exit("no bridge/devices from zigbee2mqtt -- is it running?")
    return z


def wait_state(z, name, want, timeout=10):
    deadline = time.monotonic() + timeout
    while (left := deadline - time.monotonic()) > 0:
        for ev in z.poll(left):
            if ev.kind == "state" and ev.name == name and want(ev.data):
                return ev.data
    return None


def rules_roles(path):
    try:
        r = load(path)
    except (RulesError, OSError):
        return {}
    roles = {n: "lamp" + (" (program)" if l.program else "") for n, l in r.lamps.items()}
    for s, lamps in r.sensor_lamps.items():
        roles[s] = "sensor -> " + ", ".join(lamps)
    return roles


def cmd_devices(a):
    z = connect(a)
    roles = rules_roles(a.rules)
    rows = [("NAME", "IEEE", "TYPE", "MODEL", "ONLINE", "RULES")]
    for d in sorted(z.devices.values(), key=lambda d: d.name):
        online = {True: "yes", False: "NO"}.get(z.online.get(d.name), "?")
        rows.append((d.name, d.ieee, d.type, f"{d.vendor} {d.model}".strip(),
                     online, roles.get(d.name, "-")))
    widths = [max(len(r[i]) for r in rows) for i in range(len(rows[0]))]
    for r in rows:
        print("  ".join(c.ljust(w) for c, w in zip(r, widths)).rstrip())
    unnamed = [d.name for d in z.devices.values() if d.name == d.ieee]
    if unnamed:
        print(f"\nunnamed: {', '.join(unnamed)} -- lampctl rename <ieee> <name>")


def cmd_pair(a):
    z = connect(a)
    r = z.request("permit_join", {"time": a.time})
    if r.get("status") != "ok":
        sys.exit(f"permit_join failed: {r.get('error')}")
    print(f"joining open for {a.time}s. Power the new device on now (a device "
          f"paired elsewhere needs a factory reset first). Ctrl-C to stop.")
    joined = []
    try:
        deadline = time.monotonic() + a.time
        while (left := deadline - time.monotonic()) > 0:
            for ev in z.poll(left):
                if ev.kind == "joined":
                    print(f"  joined      {ev.data['ieee_address']}")
                elif ev.kind == "interview":
                    st = ev.data.get("status")
                    d = ev.data.get("definition") or {}
                    print(f"  interview   {ev.data['ieee_address']} {st}"
                          + (f": {d.get('vendor')} {d.get('model')} -- {d.get('description')}"
                             if st == "successful" else ""))
                    if st == "successful":
                        joined.append(ev.data["ieee_address"])
                        if not a.many:
                            raise KeyboardInterrupt
    except KeyboardInterrupt:
        pass
    finally:
        z.request("permit_join", {"time": 0})
        print("joining closed")
    for ieee in joined:
        print(f"\nnext:  lampctl rename {ieee} <name>"
              f"\n       lampctl startup <name> --safe-floor      # wall-switched lamps"
              f"\n       then add [lamp.<name>] to rules.toml   # see README.md")


def cmd_rename(a):
    z = connect(a)
    r = z.request("device/rename", {"from": a.old, "to": a.new,
                                    "homeassistant_rename": False})
    if r.get("status") != "ok":
        sys.exit(f"rename failed: {r.get('error')}")
    print(f"{a.old} -> {a.new}")
    if a.old in rules_roles(a.rules):
        print(f"note: rules.toml still says {a.old!r}; update it too")


def cmd_state(a):
    z = connect(a)
    z.get(a.name, ["state", "brightness", "color_temp"])
    data = wait_state(z, a.name, lambda d: True)
    print(json.dumps(z.state.get(a.name), indent=2) if data
          else f"{a.name}: no answer (unpowered, or not a light?)")


def cmd_set(a):
    z = connect(a)
    p = {}
    if a.off:
        p["state"] = "OFF"
    elif a.on:
        p["state"] = "ON"
    if a.brightness is not None:
        p["brightness"] = level(a.brightness)
    if a.kelvin is not None:
        p["color_temp"] = mireds(a.kelvin)
    if not p:
        sys.exit("nothing to set: --on/--off, --brightness, --kelvin")
    p["transition"] = a.transition
    z.set(a.name, p)
    time.sleep(0.5)            # let the publish leave before disconnecting
    print(f"{a.name} <- {json.dumps(p)}")
    print("note: the rules take over again at the next phase fade, power-on or rules edit")


def cmd_doctor(a):
    bad = 0

    def report(ok, what, hint=""):
        nonlocal bad
        bad += ok is False
        mark = {True: "ok  ", False: "FAIL", None: "warn"}[ok]
        print(f"  {mark}  {what}" + (f"\n        -> {hint}" if hint and ok is not True else ""))

    try:
        z = Z2M(a.host, a.port, a.base)
        z.connect()
    except OSError as e:
        report(False, f"MQTT broker at {a.host}:{a.port}: {e}", "systemctl status mosquitto")
        sys.exit(1)
    report(True, f"MQTT broker at {a.host}:{a.port}")

    tag = uuid.uuid4().hex[:8]
    time.sleep(0.3)
    z.client.publish(f"{a.base}/lampctl-doctor", json.dumps({"ping": tag}), qos=1)
    got = wait_state(z, "lampctl-doctor", lambda d: d.get("ping") == tag, timeout=3)
    report(bool(got), "broker delivers messages (round trip)",
           "connected but nothing delivered: the ACL is default-deny. Check "
           "/etc/mosquitto/acl-0.conf, then `sudo systemctl reload mosquitto`")

    deadline = time.monotonic() + 3                    # retained bridge topics
    while time.monotonic() < deadline and (z.bridge_online is None or z.info is None):
        z.poll(0.3)
    bridge, info = z.bridge_online, z.info
    report(bool(bridge), "zigbee2mqtt is online",
           "journalctl -u zigbee2mqtt -e   (adapter errors = coordinator side, see below)")

    port = (info or {}).get("config", {}).get("serial", {}).get("port", "")
    url = urlparse(port)
    if url.scheme == "tcp":
        try:
            socket.create_connection((url.hostname, url.port), timeout=3).close()
            report(True, f"coordinator TCP {url.hostname}:{url.port} reachable")
        except OSError as e:
            report(False, f"coordinator TCP {url.hostname}:{url.port}: {e}",
                   "SLZB-06U powered (USB is power only) and on ethernet? README: Coordinator")
    elif port:
        report(None, f"serial port is {port!r}, expected tcp://...", "README: Coordinator")
    if info:
        c, n = info.get("coordinator", {}), info.get("network", {})
        m = c.get("meta", {})
        report(True, f"coordinator {c.get('type')} fw {m.get('majorrel')}.{m.get('minorrel')}."
                     f"{m.get('maintrel')} ({m.get('revision')}), channel {n.get('channel')}, "
                     f"PAN {n.get('pan_id')}, ext PAN {n.get('extended_pan_id')}")
        report(not info.get("permit_join") or None, "joining is closed",
               "joining is OPEN: lampctl pair closes it, or it times out")

    if z.devices:
        pending = [d.name for d in z.devices.values() if not d.interviewed]
        offline = [n for n in z.devices if z.online.get(n) is False]
        report(True, f"{len(z.devices)} devices")
        if pending:
            report(None, f"interview not finished: {', '.join(pending)}",
                   "wake battery devices with their button; or remove and pair again")
        if offline:
            report(None, f"offline: {', '.join(offline)}", "unpowered? (wall switch off is normal)")

    try:
        r = load(a.rules)
        report(True, f"rules.toml valid ({len(r.lamps)} lamps)")
        for name, lamp in r.lamps.items():
            for n in (name, *lamp.sensors):
                if z.devices and n not in z.devices:
                    report(None, f"rules mention {n!r}, which is not a z2m device",
                           "lampctl devices; lampctl rename <ieee> <name>")
    except (RulesError, OSError) as e:
        report(False, f"rules.toml: {e}")

    svc = subprocess.run(["systemctl", "is-active", "zigbee-lamps"],
                         capture_output=True, text=True).stdout.strip()
    report(svc == "active", f"zigbee-lamps service is {svc}", "journalctl -u zigbee-lamps -e")
    sys.exit(1 if bad else 0)


def cmd_startup(a):
    z = connect(a)
    if a.name not in z.devices:
        sys.exit(f"{a.name!r} is not a z2m device")
    if a.safe_floor or a.level is not None or a.kelvin is not None:
        if a.level is None:
            try:
                floor = load(a.rules).min_brightness
            except (RulesError, OSError) as e:
                sys.exit(f"cannot read the floor from rules.toml: {e}")
            if not floor:
                sys.exit("rules.toml has no [defaults] min_brightness; pass --level")
        want = {"onoff": 1,
                "level": level(floor if a.level is None else a.level),
                "kelvin": a.kelvin or SAFE_FLOOR["kelvin"]}
        values = [want["onoff"], want["level"], mireds(want["kelvin"])]
        for (_, cluster, attr, _), v in zip(STARTUP, values):
            z.set(a.name, {"write": {"cluster": cluster, "payload": {attr: v}}})
            time.sleep(1.5)
    # z2m decodes these reads into ordinary state properties (power_on_behavior,
    # level_config.current_level_startup, color_temp_startup).
    for label, cluster, attr, path in STARTUP:
        z.poll(0.3)                    # drop queued traffic so the next reply is ours
        z.set(a.name, {"read": {"cluster": cluster, "attributes": [attr]}})
        data = wait_state(z, a.name, lambda d: _dig(d, path) is not None)
        v = _dig(data or {}, path)
        note = ""
        if v is None:
            v, note = "-", "no answer / unsupported"
        elif label == "colour temp" and isinstance(v, int):
            note = f"~{round(1e6 / v)}K"
        elif label == "level" and isinstance(v, int):
            note = f"{v / 254:.0%}"
        if v in ("previous", 255, 65535):
            note = "restore previous  <- the wall-switch trap"
        print(f"  {label:12} {v!s:>8}  {note}")


def cmd_check(a):
    try:
        r = load(a.rules)
    except (RulesError, OSError) as e:
        sys.exit(f"INVALID: {e}")
    print(f"{a.rules}: OK\n")
    for p in r.phases:
        fade = f"fade {p.fade:g}s at start" if p.fade else "applies on turn-on only"
        b = "min" if p.brightness == MIN else f"{p.brightness:g}%"
        print(f"  {p.at} {p.name:10} {b}  {p.kelvin}K  ({fade})")
    for name, lamp in r.lamps.items():
        sensors = [s + (f" (<= {r.sensors[s].max_lux:g} lx)"
                        if s in r.sensors and r.sensors[s].max_lux is not None else "")
                   for s in lamp.sensors]
        print(f"\n[{name}]" + (f"  sensors: {', '.join(sensors)}" if sensors else ""))
        for p in r.phases:
            look = lamp.look(p)
            line = f"  {p.name:10} {look.brightness:g}% (level {level(look.brightness)})  {look.kelvin}K"
            if prog := lamp.program_at(p):
                line += f"  [{prog.name}] {describe(prog)}"
            print(line)


def describe(prog):
    b = "phase" if prog.brightness == PHASE else f"{prog.brightness:g}%"
    steps = [f"fade {s.secs:g}s to {s.to:g}%" if s.to is not None else f"hold {s.secs:g}s"
             for s in prog.after]
    return " -> ".join([b, *steps])


def main():
    p = argparse.ArgumentParser(prog="lampctl", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--rules", default=os.path.join(HERE, "rules.toml"))
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=1883)
    p.add_argument("--base", default="zigbee2mqtt")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("devices").set_defaults(fn=cmd_devices)
    s = sub.add_parser("pair")
    s.add_argument("--time", type=int, default=180, help="seconds to allow joining")
    s.add_argument("--many", action="store_true", help="keep going after the first device")
    s.set_defaults(fn=cmd_pair)
    s = sub.add_parser("rename")
    s.add_argument("old")
    s.add_argument("new")
    s.set_defaults(fn=cmd_rename)
    s = sub.add_parser("state")
    s.add_argument("name")
    s.set_defaults(fn=cmd_state)
    s = sub.add_parser("startup")
    s.add_argument("name")
    s.add_argument("--safe-floor", action="store_true")
    s.add_argument("--level", type=float,
                   help="power-on brightness, percent (default: [defaults] min_brightness)")
    s.add_argument("--kelvin", type=int, help="power-on colour temperature")
    s.set_defaults(fn=cmd_startup)
    sub.add_parser("check").set_defaults(fn=cmd_check)
    sub.add_parser("doctor").set_defaults(fn=cmd_doctor)
    s = sub.add_parser("set", help="one-off command; the rules take over again later")
    s.add_argument("name")
    s.add_argument("--on", action="store_true")
    s.add_argument("--off", action="store_true")
    s.add_argument("--brightness", type=float, help="percent")
    s.add_argument("--kelvin", type=int)
    s.add_argument("--transition", type=float, default=1, help="seconds")
    s.set_defaults(fn=cmd_set)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
