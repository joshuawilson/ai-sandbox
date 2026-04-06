#!/usr/bin/env bash
# Optional: INTERFACE=eth0 THRESHOLD_MB=200 ./ai-kill-switch.sh
# Disables all networking when receive rate spikes (blunt; review before production use).

THRESHOLD_MB="${THRESHOLD_MB:-500}"
if [ -z "${INTERFACE:-}" ]; then
  INTERFACE=$(ip route show default 0.0.0.0/0 2>/dev/null | awk '{print $5; exit}')
  [ -n "$INTERFACE" ] || INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
fi
if [ -z "$INTERFACE" ] || [ ! -d "/sys/class/net/$INTERFACE" ]; then
  echo "Could not detect default interface; set INTERFACE= manually." >&2
  exit 1
fi

echo "Monitoring network usage..."

while true; do
    RX=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
    sleep 5
    RX2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)

    DIFF=$(( (RX2 - RX) / 1024 / 1024 ))

    if [ "$DIFF" -gt "$THRESHOLD_MB" ]; then
        echo "⚠️ High network usage detected: ${DIFF}MB"
        echo "KILLING NETWORK"

        sudo nmcli networking off
        break
    fi
done
