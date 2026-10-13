#!/usr/bin/env sh

# Serialize concurrent invocations (e.g. quick `monitor` mode switches), which
# would otherwise each kill the old bar and then both launch a new one.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar.sh.lock"
flock 9

# Terminate already running bar instances
killall -q waybar

# Wait until the processes have been shut down
while pgrep -x waybar >/dev/null; do sleep 1; done

# Launch main in the background without the lock fd, so the lock is released
# when this script exits
waybar 9>&- &
