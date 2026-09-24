#!/usr/bin/env python3
"""zigbee-lamps service: run the engine, and reload rules.toml when it changes.

A rules edit takes effect within ~2s. An invalid edit is logged and the
previous rules stay in force, so a half-saved file never takes the lights down.
Code changes need `sudo systemctl restart zigbee-lamps`; nothing needs a
nixos-rebuild unless the Python dependencies change. See README.md.
"""
import argparse, logging, os, sys

from engine import Engine
from rules import RulesError, load
from z2m import Z2M

HERE = os.path.dirname(os.path.abspath(__file__))
RULES_POLL_S = 2.0
log = logging.getLogger("main")


def _stamp(path):
    try:
        st = os.stat(path)
        return st.st_mtime_ns, st.st_size, st.st_ino   # editors replace by rename
    except FileNotFoundError:
        return None


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--rules", default=os.path.join(HERE, "rules.toml"))
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=1883)
    p.add_argument("--base", default="zigbee2mqtt")
    p.add_argument("--dry-run", action="store_true", help="log commands, never publish")
    p.add_argument("--verbose", action="store_true")
    a = p.parse_args()
    logging.basicConfig(level=logging.DEBUG if a.verbose else logging.INFO,
                        format="%(levelname)s %(name)s: %(message)s", stream=sys.stdout)

    try:
        rules = load(a.rules)
    except (RulesError, OSError) as e:
        sys.exit(f"cannot start: {e}")
    log.info("rules: %s (%d phases, lamps: %s)", a.rules, len(rules.phases),
             ", ".join(rules.lamps) or "none")

    z2m = Z2M(a.host, a.port, a.base, client_id="zigbee-lamps" + ("-dry-run" if a.dry_run else ""),
              dry_run=a.dry_run)
    engine = Engine(rules, z2m)
    z2m.connect()
    stamp = _stamp(a.rules)

    while True:
        for ev in z2m.poll(engine.seconds_to_next(cap=RULES_POLL_S)):
            engine.on_event(ev)
        engine.tick()

        now = _stamp(a.rules)
        if now and now != stamp:
            stamp = now
            try:
                engine.set_rules(load(a.rules))
                log.info("rules reloaded")
            except (RulesError, OSError) as e:
                log.error("rules NOT reloaded, keeping the previous ones: %s", e)


if __name__ == "__main__":
    main()
