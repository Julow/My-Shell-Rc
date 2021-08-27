#!/usr/bin/env bash

INFOS=()

# Date
DATE=`date +"<b>%H:%M</b> %A %d %B (week %V)"`
INFOS+=("$DATE")

# Battery
while read line; do
	if [[ $line =~ ^Battery\ [0-9]*:\ (.*),\ ([0-9]+)%.*$ ]]; then
    STATUS=${BASH_REMATCH[1]}
    VAL=${BASH_REMATCH[2]}
    BAR_COLOR=
    if [[ $VAL -le 20 ]] && [[ $STATUS = Discharging ]]; then BAR_COLOR=red; fi
		PROGRESS=`BAR_COLOR=$BAR_COLOR progress-bar.sh "$VAL"`
    INFOS+=("<b>Battery</b> $PROGRESS $STATUS")
	fi
done < <(acpi -b)

# Network
if which nmcli &>/dev/null; then
  CONN=0
  while IFS=: read _ type state _ _ _ ssid _; do
    if [[ $state = connected ]]; then
      INFOS+=("<b>Connected to $type</b> <span foreground=\"green\">$ssid</span>")
      CONN=1
    elif [[ $state = connecting* ]]; then
      INFOS+=("<b>Connecting to $type</b> <span foreground=\"darkorange\">$ssid</span>...")
      CONN=1
    fi
  done < <(nmcli -g all d)
  if [[ $CONN -eq 0 ]]; then
    INFOS+=("<b>Not connected</b>")
  fi
fi

# Media
if which playerctl &>/dev/null; then
  IFS="|" read player status title < \
    <(playerctl metadata -f "{{playerName}}|{{status}}|{{artist}} - {{title}}")
  if [[ $status = "Playing" ]]; then
    INFOS+=("<b>${player^}</b> $title")

    # Volume muted status
    if which pamixer &>/dev/null; then
      # TODO: Print sink name when [pamixer --get-default-sink] is available
      vol=`pamixer --get-volume-human`
      if [[ $vol = muted ]]; then
        INFOS+=("<b>Volume</b> Muted")
      fi
    fi
  fi
fi

# Rfkill status
for dev in /sys/class/rfkill/*; do
  read hard < "$dev/hard"
  read soft < "$dev/soft"
  if [[ $hard -ne 0 ]] || [[ $soft -ne 0 ]]; then
    read name < "$dev/name"
    read typ < "$dev/type"
    INFOS+=("<b>${typ^} blocked</b> $name")
  fi
done

dunstify -r "101010" -a "Status" -u low "" "`IFS=$'\n'; echo "${INFOS[*]}"`"
