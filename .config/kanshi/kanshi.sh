#!/usr/bin/env sh

# killall -q kanshi

# Wait until the processes have been shut down
# while pgrep -kanshi waybar >/dev/null; do sleep 1; done

internal="eDP-1"
external="HDMI-A-1"
num_monitors=$(hyprctl monitors all | grep Monitor | wc -l)
num_active=$(hyprctl monitors | grep Monitor | wc -l)

if [ $num_active -gt 1 ] && hyprctl monitors | grep --quiet $internal; then
  hyprctl keyword monitor "$internal, disable"
  echo "disabled $internal"
  exit
fi

if [ $num_monitors -eq 1 ]; then
  exit
fi

if hyprctl monitors | grep --quiet $external; then
  hyprctl keyword monitor "$external, disable"
  hyprctl keyword monitor "$internal, preferred, 0, auto"
else
  hyprctl keyword monitor "$internal, disable"
  hyprctl keyword monitor "$external, preferred, 0, auto"
fi

# Launch main
# kanshi
