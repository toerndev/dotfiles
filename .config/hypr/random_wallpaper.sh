#!/bin/env bash
wallpaper=$(find ~/wallpapers -type f | shuf -n 1)
hyprctl hyprpaper unload all
hyprctl hyprpaper preload $wallpaper
hyprctl hyprpaper wallpaper $wallpaper
