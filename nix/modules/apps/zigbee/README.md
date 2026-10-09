# Zigbee lights

zigbee2mqtt + mosquitto on htpc, and a small rules service (`zigbee-lamps`)
that decides what the lights do. This directory is self-contained: this file
is enough to rebuild the whole setup from nothing.

- [Layout](#layout) · [Everyday](#everyday) · [Add a light](#add-a-light) ·
  [Add a motion sensor](#add-a-motion-sensor) · [How the rules behave](#how-the-rules-behave)
- [Hardware](#hardware) · [Lamp facts](#lamp-facts) · [The network](#the-network)
- [Setting up from scratch and recovery](#setting-up-from-scratch-and-recovery) ·
  [Troubleshooting](#troubleshooting) · [Tests](#tests)

## Layout

| file | role |
|---|---|
| `default.nix` | mosquitto, zigbee2mqtt, the `zigbee-lamps` service, `lampctl`, backups, frontend proxy |
| `rules.toml` | **what the lights do**: phases of the day, per-lamp settings, sensors |
| `engine.py` | behaviour: power-on, phase fades, motion, reconcile |
| `rules.py` | parses and strictly validates `rules.toml` |
| `z2m.py` | zigbee2mqtt over MQTT: devices, state cache, commands; no policy |
| `main.py` | the service: event loop, reloads `rules.toml` when it changes |
| `ctl.py` | `lampctl`: pair, name, inspect, diagnose |
| `test_lamps.py` | tests; no broker needed |

### What needs what

| change | takes effect |
|---|---|
| `rules.toml` | on save, within ~2s. An invalid edit is logged and the previous rules keep running. |
| `*.py` | `sudo systemctl restart zigbee-lamps` (the service runs this checkout, as `losipai`) |
| device names, per-device z2m options | immediately: `lampctl rename`, the frontend. Stored in z2m's `devices.yaml`. |
| `default.nix` | `sudo nixos-rebuild switch --flake ~/github/dotfiles/nix#htpc` |

## Everyday

```bash
$EDITOR rules.toml                # save = live
lampctl check                     # validate; show what each lamp does per phase
lampctl doctor                    # broker, z2m, coordinator, devices, rules, service
lampctl devices                   # paired devices, online?, used by the rules?
lampctl state stairs-bottom       # live read
lampctl set stairs-bottom --brightness 40 --kelvin 3000   # one-off; rules take over later
journalctl -u zigbee-lamps -f     # every decision and command, with the reason
```

Frontend (logs, device pages, maps, settings): <http://10.100.0.1:8083> over
WireGuard.

## Add a light

1. **Pair:** `lampctl pair`, then power the light on. It opens joining for
   3 minutes, prints what joins and the interview result, and closes joining
   once the new device is in. New lights join by themselves. A light that was
   paired anywhere before needs a factory reset first (see the model's page,
   `https://www.zigbee2mqtt.io/devices/<model>.html`; usually 5–6 quick
   off/on cycles until it blinks).
2. **Name it:** `lampctl rename 0x70ac08fffe43ac14 stairs-bottom`. Use
   lowercase and dashes, no `/`. The name is used in MQTT topics and in
   `rules.toml`.
3. **Power-on defaults** (lights behind a wall switch): check what it has,
   then set the safe floor. It reads the values back. Why this matters:
   [Lamp facts](#lamp-facts).
   ```bash
   lampctl startup stairs-bottom
   lampctl startup stairs-bottom --safe-floor     # on / the floor / 2222K
   ```
4. **Rules:** add `[lamp.stairs-bottom]` to `rules.toml` and save. An empty
   section follows the shared phases. The service picks the light up right
   away. If the names don't match, the journal says
   `lamp '…' is not a z2m device`.

To replace a dead light, pair the new one and give it **the old name**; the
rules need no change. Remove the old entry in the frontend.

## Add a motion sensor

1. Pair and name it as above (e.g. `stairs-pir`); skip the power-on step.
   Battery sensors sleep: if the interview stalls, press the button to wake
   it.
2. **Its own timeout:** a sensor reports `occupancy: true` on movement and
   `false` after its own timeout. The program's `after` steps start then.
   - SNZB-03PR2 (firmware 1.0.5): z2m 2.6.3 has no converter for it and pairs
     it with an *Automatically generated definition*. That exposes only
     `occupancy`, `illuminance` and `battery`, with no timeout setting, so
     the sensor's built-in timeout applies. `occupancy: false` came 45–55s
     after the last movement when first measured, but on 2026-10-09
     `stairs-bottom-pir` cleared 12–20s after it triggered (5–10s after its
     last `true`). Don't rely on it: start `after` with a `hold`.
     It only reports changes: about every 10s while it keeps seeing motion,
     then nothing until the `false`. Silence in between is normal.
   - Hue outdoor sensor (SML004, `driveway-pir`): z2m has a real converter.
     `occupancy_timeout` (factory 0) and `motion_sensitivity` are written to
     the device; `driveway-pir` has 30s and `medium`:
     `mosquitto_pub -t zigbee2mqtt/driveway-pir/set -m '{"occupancy_timeout": 30, "motion_sensitivity": "medium"}'`.
     It also reports `illuminance` (lux), which `max_lux` (step 4) uses.

   Check the model's z2m page for the exact names. If the frontend says
   *Automatically generated definition*, the model-specific settings are
   missing: see what it actually exposes before relying on the page.
3. **Before mounting:** hold it where it will go and check
   `lampctl state <sensor>`. `linkquality` should be well above 0 and
   `occupancy` should flip when you walk past.
4. **Bind it** in `rules.toml`: give the light a program and the sensor.
   ```toml
   [program.stairs]
   after = [{ hold = "30s" }, { fade = "2m", to = 0 }]   # lit to the phase look
   [program.stairs-night]
   after = [{ fade = "45s", to = 3 }]                    # glow instead of off

   [lamp.stairs-bottom]
   sensors = ["stairs-pir"]
   program = "stairs"
   night.program = "stairs-night"     # this phase only
   ```
   A light can have several sensors: it stays held while any is occupied. A
   sensor can drive several lights, each with its own program.
   **Only after dark:** a sensor that reports `illuminance` can gate its
   lamps with `[sensor.<name>] max_lux = 40`. Motion then only lights a lamp
   that is off when the lux is at or below that; see
   [How the rules behave](#how-the-rules-behave).
5. Watch it: `journalctl -u zigbee-lamps -f` shows `motion on stairs-pir`,
   `clear on stairs-pir [stairs: hold 30s, fade 2m to 0%]`,
   `fading to 0% over 2m`, `program done, off`.

## How the rules behave

`rules.toml` documents every key. The model behind it:

- **Phases** are shared by all lamps: a start time, a brightness and a
  colour temperature.
  - A phase with `fade` also acts at its start: lamps that are on fade to
    whatever changed. That's colour only at 16:00 and brightness only at
    20:00 and 21:30.
  - A phase without `fade` only applies when a lamp turns on. That is why
    nothing happens at 06:00.
- **Plain lamps** (no `program`) follow the phase. They move to it when they
  turn on, whether at the wall (the lamp re-announces itself ~5s after power
  returns) or over Zigbee.
- **Programs** (`[program.<name>]`) are what a lamp does when an input
  lights it. A lamp with `program = "<name>"` (or `<phase>.program`):
  1. An input holds it at the program's `brightness`: a percent, or the
     phase look. The phase look is the ceiling: a level above it shows the
     phase look and follows phase fades, at every step and at phase starts. Inputs today are the lamp's `sensors`; it is held while any
     of them reports occupancy.
  2. When every input has let go, the `after` steps run in order:
     `{ hold = … }` stays, `{ fade = …, to = … }` fades (0 = off). The last
     level stays until the next input.

  An input during `after` starts again from step 1. Switching the lamp on
  (wall, Zigbee, power back) counts as an input that has just let go: lit to
  the phase look, then `after`. A lamp switched off ends its program;
  the sensor's next report of motion (~10s while it lasts) lights it again.
  Inputs and lamps are n:m: one sensor can drive several lamps with
  different programs. A rules edit applies at once: a running `after` is
  redone as if the new steps had been in force since the input let go.
- **Dark only** (`[sensor.<name>] max_lux`): motion on that sensor only
  lights a lamp that is off while the sensor's last `illuminance` is at or
  below `max_lux`. A lamp already on (its program running, or switched on)
  ignores the lux, because the lamp lights up its own sensor and would
  otherwise go out on someone standing under it. No reading yet: it lights.
  The journal says `motion on … ignored, 600 lx > max_lux 40`.
- **The floor:** `[defaults] min_brightness` (a lamp can set its own) is
  the dimmest a lamp shows while on. Phases and programs write it as
  `"min"`, so programs shared by several lamps use each lamp's own floor.
  `--safe-floor` writes it to the drivers as the power-on level.
- **Per-lamp settings:** `min_brightness`/`max_brightness` clamp every
  phase look (not a program's own levels); `<phase>.<key>` overrides one
  phase for one lamp.
- **Safety:** colour changes may go to any lamp, since they never switch one
  on. Scheduled brightness changes only go to lamps already on, and to a
  programmed lamp only while it shows the phase look.
- **Lost commands:** z2m publishes a lamp's state only when a command got
  through. One not confirmed within 15s is resent (only what is missing,
  with what is left of its fade), up to twice; then it is given up, since a
  lamp switched off at the wall can't answer either. A lamp switched off in
  the meantime is not relit.
- **Every 10 minutes**, and after a restart of this service or z2m, a rules
  edit, or a lamp appearing in z2m, lamps are read live. The ones that answer
  ON and differ from what they should show get it, finishing a phase fade
  over the time it has left. A programmed lamp that is on with nothing running
  (its OFF never arrived) runs its program again. A lamp with its mains cut
  can't answer, so it is left alone.
- **Suspend or clock jump:** a late scheduled fade goes to the phase that is
  actually current.

## Hardware

**Coordinator: SMLIGHT SLZB-06U**
- **Radio:** TI CC2652P running Z-Stack 3.x (`ZStack3x0` 2.7.1, rev
  20221226). The z2m adapter is `zstack`, not `ezsp`/`ember`.
- **Link to htpc:** network mode. The radio is reached over **TCP 6638**
  (`SLZB-06U.lan`, DHCP 192.168.1.219: keep a reservation for it). Web UI on
  port 80.
- **USB does two things only: power, and the ESP32's debug console**
  (`/dev/ttyACM0`, `303a:1001`). It is never the Zigbee radio. Opening it
  with DTR/RTS reboots the ESP32. A loose USB cable takes the coordinator
  down completely.
- **Without ethernet** it opens a fallback WiFi AP (`SLZB-06U_xxxxxx`). Don't
  join it from htpc: that drops htpc's own WiFi, and with it SSH.
- **Only z2m may talk to port 6638.** The SLZB accepts several TCP clients but
  has a single frame stream, so a second client silently corrupts z2m's. A
  plain connect-and-close (as `lampctl doctor` does) is harmless.

**Lamps: Sunricher HK-CCT drivers** (z2m calls them *Envilar
ZG50CC-CCT-DRIVER*), firmware `2.9.2_r66`. Brightness 1–254. Mains comes
through a wall switch. Every driver is set with Sunricher's NFC app to:

- **CCT range 200–450** (the app calls it CCT, but it is mireds): 5000–2222K,
  the LEDs' real range, so mireds sent are physically true. z2m still
  advertises the model's 160–450 and the engine clamps to that, so phases
  stay at or below 5000K.
- **Power-on state on, power-on level 30** (~12%): the same as
  `--safe-floor` below, which takes the level from `rules.toml`.
- **Corridor fade time 0s.**

Those settings live in the driver; a replacement driver needs them too.

| name | IEEE |
|---|---|
| bedroom-ceiling | `0x187a3efffe35e73a` |
| stairs-bottom | `0x70ac08fffe43ac14` |

## Lamp facts

These were measured on the lamps above, and the design depends on them.

- **Colour never switches a lamp on; brightness does.** Colour temperature is
  the Color Control cluster, which has no on/off. Brightness goes through
  `moveToLevelWithOnOff`, which turns an off lamp on. So unattended code may
  send colour anywhere, but brightness only to lamps already on.
- **The wall switch is the real on/off.** When it cuts mains, z2m keeps
  reporting the last state (usually ON) until availability notices, which
  takes up to 10 min for mains devices. When mains returns, the lamp lights
  from its own power-on defaults, then announces itself ~5s later. That
  announce is when the rules can act.
- **Power-on defaults are the night-safety floor.** They live in the lamp,
  so they work with htpc down. Set by `lampctl startup --safe-floor`:

  | attribute | value | why |
  |---|---|---|
  | `StartUpOnOff` | **1** (on) | 0 would need the server to light the lamp, and a dark lamp couldn't be fixed from the wall. 255 ("previous") means one Zigbee *off* leaves the wall switch unable to turn it on. |
  | `StartUpCurrentLevel` | **30** (~12%) | `rules.toml`'s `[defaults] min_brightness` (11.8% = level 30), the floor. A power-on at night looks the same as a motion trigger and as the last step before off. Costs a slower ramp, below. |
  | `StartUpColorTemperature` | **450** (2222K) | Fail warm: too warm at noon is corrected in seconds, 6250K at 03:00 is not. |

  These are fixed on purpose, not tracked from the schedule. They can only
  be written while the lamp has power, so a server that dies at 14:00 would
  leave the lamp powering up at 14:00 values at 03:00.
- **The power-up ramp is fixed-duration.** After mains-on the driver fades
  from 0 to `StartUpCurrentLevel` over ~3s whatever the target, so a higher
  target is brighter at every instant. Light becomes visible after about
  `0.7s + 3s × 60 / level`: 5.2s at 40, 2.1s at 127, 1.4s at 254. 127 is the
  knee, but it showed ~50% for a few seconds after 20:00 before the rules
  dimmed it; the drivers now use 30, which the formula puts at ~6.7s
  (measured with the old 160–450 setup, not yet re-checked at 30).
  `OnOffTransitionTime` does not affect this ramp (tested).
- **Anything z2m doesn't expose can still be read or written.**
  `{"read"|"write": {"cluster": …}}` on `<name>/set` works on every device;
  `lampctl startup` uses it.
- **Leave the vendor attributes alone.** Sunricher's undocumented attributes
  (Basic `0x78xx`/`0x88xx`/`0x90xx`) look like factory calibration, and
  `0x8806` = 35 may well be drive current. A bad write could damage the LED
  module and can't be undone from the wall.
- **No firmware updates:** z2m's definition for this model has no OTA
  support.

## The network

| | |
|---|---|
| channel | 11 |
| PAN id | `0x1a62` (6754) |
| extended PAN id | `0x00124b00257bf4ae` (the coordinator's IEEE) |
| network key | **z2m's public default** `01030507090b0d0f00020406080a0c0d` |

These come from z2m's defaults. `default.nix` sets none of them, and z2m
treats a config that matches the coordinator as "resume".

**Known weaknesses.** Both are cheapest to fix now, while few devices are
paired, because fixing either means pairing every device again.
- **The key is public**, the same on every install that never changed it.
  Anyone nearby could join or decode the traffic.
- **Channel 11 overlaps WiFi channel 1.** Channels 15, 20 and 25 overlap WiFi
  the least.

To change them, pin all four settings in `default.nix`, keeping the key in
sops. Don't use `GENERATE`: the NixOS module rewrites `configuration.yaml` on
every start, so a generated key would change on every restart. Then pair
everything again.

**State that makes up the network:**
- The coordinator's own non-volatile memory.
- `/var/lib/zigbee2mqtt/`:
  - `coordinator_backup.json`: key, PAN and channel. z2m can restore it onto
    a blank coordinator.
  - `database.db`: the device registry.
  - `devices.yaml`: names and per-device options.

These three files are in the nightly borg `files` job (04:00, keeps 7
dailies), declared in `default.nix`.

## Setting up from scratch and recovery

Check every step with `lampctl doctor`; it names the failing layer.

### Coordinator setup (new or factory-reset SLZB-06U)

1. Connect ethernet and USB power. Find it in the router's DHCP list, or as
   `SLZB-06U.lan`.
2. Reserve its address (192.168.1.219) in the router.
3. In its web UI (`http://<ip>/`), check:
   - The connection is **LAN/ethernet**, and it is in **coordinator /
     network (TCP) mode**, port **6638**. Not USB mode.
   - Zigbee firmware is **Z-Stack coordinator firmware for the CC2652P**.
     The UI can flash it if it's missing.
4. The address in `default.nix` (`tcp://SLZB-06U.lan:6638`) must resolve. If
   the router's DNS doesn't provide the name, put the reserved IP there
   instead.

### htpc reinstalled; coordinator and lamps untouched

The coordinator still holds the network, so only z2m's files are needed:
```bash
sudo nixos-rebuild switch --flake ~/github/dotfiles/nix#htpc
sudo systemctl stop zigbee2mqtt
sudo borg-job-files list                                  # pick the newest htpc-files-*
cd / && sudo borg-job-files extract ::htpc-files-<date> \
  var/lib/zigbee2mqtt/coordinator_backup.json var/lib/zigbee2mqtt/database.db \
  var/lib/zigbee2mqtt/devices.yaml
sudo chown zigbee2mqtt: /var/lib/zigbee2mqtt/* && sudo systemctl start zigbee2mqtt
lampctl doctor                    # z2m log should say "zigbee-herdsman started (resumed)"
```
Restore the files **before** z2m first reaches the coordinator. Otherwise z2m
may form a fresh network, and every device has to be paired again.

### Coordinator reset or replaced; lamps untouched

Do the coordinator setup above, and make sure `/var/lib/zigbee2mqtt` has
`coordinator_backup.json` (restore it from borg if not). Then start z2m. When
it finds a blank coordinator plus a backup, it writes the network back into
the coordinator (log: `restored`), and the lamps rejoin without pairing.
This is zigbee-herdsman's documented behaviour; it hasn't been tested on this
install. If it forms a new network instead, pair every device again as below.

### A lamp reset or replaced

[Add a light](#add-a-light), reusing the old name. Then `--safe-floor`.

### Everything reset

1. Coordinator setup.
2. Before pairing anything, decide the network parameters (see
   [The network](#the-network)). This is the one moment when changing them is
   free.
3. Deploy: `sudo nixos-rebuild switch …`. z2m forms the network.
4. For each light: [Add a light](#add-a-light). For each sensor:
   [Add a motion sensor](#add-a-motion-sensor).
5. `lampctl doctor`. The next nightly borg run backs up the new network.

## Troubleshooting

| symptom | cause, fix |
|---|---|
| `doctor`: *broker delivers messages* FAIL | mosquitto ACL is default-deny (an empty `/etc/mosquitto/acl-0.conf`). `default.nix` sets it; `sudo systemctl reload mosquitto`. |
| z2m log: `cannot open /dev/ttyACM0`, or `ezsp` errors | wrong `serial` settings. It must be `tcp://…:6638` with adapter `zstack`. |
| `doctor`: coordinator TCP FAIL | SLZB unpowered (check the USB cable: it is the power), no ethernet, or the address moved. |
| a lamp ignores the rules | name mismatch: the journal warns `lamp '…' is not a z2m device`. Run `lampctl devices`. |
| a rules edit has no effect | invalid file: the journal says `rules NOT reloaded`, with the reason. Run `lampctl check`. |
| the wall switch doesn't light a lamp | power-on defaults: `lampctl startup <name>`. Is on/off `previous`? Set `--safe-floor`. |
| ~2s before light after the switch, then a change ~5s later | normal: the power-up ramp, then the announce lets the rules act. |
| a sensor never triggers | `lampctl state <sensor>`: does it report `occupancy`? Battery devices can take a while after pairing. |

## Tests

```bash
cd ~/github/dotfiles/nix/modules/apps/zigbee
nix shell --impure --expr '(import (builtins.getFlake "nixpkgs") {}).python3.withPackages (p: [p.paho-mqtt])' \
  -c python3 -m unittest -v
python3 main.py --dry-run         # against the live broker: logs what it would send, sends nothing
```
The tests run the engine against a fake z2m and a fake clock.
