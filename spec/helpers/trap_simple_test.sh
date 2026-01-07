#!/usr/bin/env bash
# Simple E2E test that focuses on signal delivery

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


echo "PID: $$"
echo "Setting trap..."

HANDLER_EXECUTED=""

simple_handler() {
  HANDLER_EXECUTED="yes"
  echo "HANDLER_A_EXECUTED"
}

# Simple direct trap setup
trap simple_handler INT
echo "Trap set: $(trap -p INT)"

echo "READY:simple"

# Keep process alive
while true; do
  sleep 0.1
done