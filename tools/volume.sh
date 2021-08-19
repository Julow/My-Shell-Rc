#!/usr/bin/env bash

case "$1" in
  "toggle") pamixer --toggle-mute ;;
  "dec") pamixer --decrease 5 ;;
  "inc") pamixer --increase 5 ;;
esac

if which dunstify &>/dev/null; then

  vol=`pamixer --get-volume-human`
  if [[ $vol = muted ]]; then
    args=(Muted)
  else
    args=(-h "int:value:${vol%"%"}")
  fi

  dunstify -r 1234 -a "Indicator" -u low "Volume" "${args[@]}"

fi
