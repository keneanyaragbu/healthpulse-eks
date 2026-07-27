#!/bin/bash
# Prints current SLI / burn-rate values straight from Prometheus.
set -uo pipefail

pkill -f "port-forward.*prometheus" 2>/dev/null || true
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT
sleep 4

q() {
  curl -s "http://localhost:9090/api/v1/query" --data-urlencode "query=$1" \
    | python3 -c "
import sys,json
d=json.load(sys.stdin)['data']['result']
print(f\"  {'$2':<28} {'(no data)' if not d else round(float(d[0]['value'][1]),4)}\")"
}

echo "--- SLI ---"
q 'healthpulse:error_ratio:rate5m'   'error ratio 5m'
q 'healthpulse:error_ratio:rate1h'   'error ratio 1h'
q 'healthpulse:latency_good_ratio:rate5m' 'under 300ms 5m'

echo "--- BURN RATE (budget 0.001) ---"
q 'healthpulse:burn_rate:5m'  'burn 5m'
q 'healthpulse:burn_rate:1h'  'burn 1h'

echo "--- FIRING ALERTS ---"
curl -s "http://localhost:9090/api/v1/alerts" | python3 -c "
import sys,json
a=[x for x in json.load(sys.stdin)['data']['alerts'] if 'HealthPulse' in x['labels'].get('alertname','')]
print('  none') if not a else [print(f\"  {x['labels']['alertname']:<38} {x['state']}\") for x in a]"
