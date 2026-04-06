#!/usr/bin/env bash

LOG_DIR=~/ai-sandbox/logs
mkdir -p $LOG_DIR

echo "Starting AI activity recorder..."

# Log commands
script -f $LOG_DIR/terminal.log &

# Log processes
while true; do
    ps aux >> $LOG_DIR/process.log
    sleep 5
done &
