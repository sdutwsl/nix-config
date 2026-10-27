#!/bin/bash

player_status=$(playerctl --player=spotify status 2>/dev/null)
if [ "$player_status" = "Playing" ]; then
echo "$(playerctl --player=spotify metadata artist) - $(playerctl metadata title)"
elif [ "$player_status" = "Paused" ]; then
	echo " $(playerctl --player=spotify metadata artist) - $(playerctl metadata title)"
fi
