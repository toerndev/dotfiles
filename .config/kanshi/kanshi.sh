#!/usr/bin/env sh

# Terminate already running bar instances
killall -q kanshi

# Wait until the processes have been shut down
while pgrep -kanshi waybar >/dev/null; do sleep 1; done

# Launch main
kanshi
