#!/usr/bin/env bash
# Nagios plugin to check memory usage percentage on Linux
set -euo pipefail

WARN=80
CRIT=90

while getopts "w:c:" opt; do
  case "$opt" in
    w) WARN="$OPTARG" ;;
    c) CRIT="$OPTARG" ;;
    *)
      echo "UNKNOWN - Usage: $0 -w <warn_pct> -c <crit_pct>"
      exit 3
      ;;
  esac
done

TOTAL_MB=$(free -m | awk '/^Mem:/ {print $2}')
AVAIL_MB=$(free -m | awk '/^Mem:/ {print $7}')

if [[ -z "${TOTAL_MB}" || "${TOTAL_MB}" -eq 0 ]]; then
  echo "UNKNOWN - Could not read memory stats"
  exit 3
fi

USED_MB=$((TOTAL_MB - AVAIL_MB))
USED_PCT=$((USED_MB * 100 / TOTAL_MB))

PERF="mem_used_pct=${USED_PCT}%;${WARN};${CRIT};0;100 mem_used_mb=${USED_MB}MB;;;0;${TOTAL_MB}"

if [[ "${USED_PCT}" -ge "${CRIT}" ]]; then
  echo "CRITICAL - Memory usage is ${USED_PCT}% (${USED_MB}/${TOTAL_MB} MB) | ${PERF}"
  exit 2
elif [[ "${USED_PCT}" -ge "${WARN}" ]]; then
  echo "WARNING - Memory usage is ${USED_PCT}% (${USED_MB}/${TOTAL_MB} MB) | ${PERF}"
  exit 1
else
  echo "OK - Memory usage is ${USED_PCT}% (${USED_MB}/${TOTAL_MB} MB) | ${PERF}"
  exit 0
fi
