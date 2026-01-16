#!/usr/bin/env bash

com=("$@")

if [ "${#com[@]}" -eq 0 ] ; then
  echo "No command to execute."
  exit 1
fi

printf "\033[95;1m%s\033[0m\n" "$(echo ${com[@]})"

if command -v time >/dev/null 2>&1 ; then
  # TIMEFORMAT="Elapsed time: %lR seconds"
  TIMEFORMAT=$'\nElapsed time: %lR seconds'
  time (set -x; "${com[@]}")
else
  SECONDS=0
  (set -x; "${com[@]}")
  # Calculate the duration
  duration=$SECONDS
  # Format the duration into hours, minutes, and seconds
  # Hours: (duration / 3600)
  # Minutes: ((duration % 3600) / 60)
  # Seconds: (duration % 60)
  printf "\nElapsed time: %02d hours, %02d minutes, %02d seconds\n" $((duration/3600)) $((duration%3600/60)) $((duration%60))
fi
