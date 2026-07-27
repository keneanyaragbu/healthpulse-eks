#!/bin/bash
# Traffic generator for SLO / burn-rate testing.
# Usage: ./scripts/generate-load.sh [requests] [error_percent] [slow_percent]
set -uo pipefail

TOTAL="${1:-300}"
ERROR_PCT="${2:-0}"
SLOW_PCT="${3:-0}"
NS="healthpulse-dev"
SVC="healthpulse-backend-dev"

pkill -f "port-forward.*${SVC}" 2>/dev/null || true
kubectl port-forward -n "${NS}" "svc/${SVC}" 3000:3000 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT
sleep 3

echo "==> ${TOTAL} requests | ${ERROR_PCT}% errors | ${SLOW_PCT}% slow"
for i in $(seq 1 "${TOTAL}"); do
  ROLL=$(( RANDOM % 100 ))
  if (( ROLL < ERROR_PCT )); then
    curl -s -o /dev/null "http://localhost:3000/api/error"
  elif (( ROLL < ERROR_PCT + SLOW_PCT )); then
    curl -s -o /dev/null "http://localhost:3000/api/slow?ms=600"
  else
    curl -s -o /dev/null "http://localhost:3000/api/appointments"
  fi
  (( i % 50 == 0 )) && echo "    ${i}/${TOTAL}"
done
echo "==> done"
