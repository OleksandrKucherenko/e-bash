#!/bin/sh
# shellcheck disable=SC2016

set -eu

if [ "${SHELLSPEC_PATH:-}" ]; then
  PATH="$SHELLSPEC_PATH"
  export PATH
fi

# $1 timeout seconds
# $2 test pid
# $3 signal file path
# $4 result file path

timeout_seconds="$1"
test_pid="$2"
signal_file="$3"
result_file="$4"

sleep "$timeout_seconds" &
sleep_pid=$!

while kill -0 "$sleep_pid" 2>/dev/null; do
  if ! kill -0 "$test_pid" 2>/dev/null; then
    kill "$sleep_pid" 2>/dev/null || :
    exit 0
  fi

  if [ ! -e "$signal_file" ]; then
    kill "$sleep_pid" 2>/dev/null || :
    exit 0
  fi

  sleep 0.1 2>/dev/null || sleep 1
done

if kill -0 "$test_pid" 2>/dev/null; then
  echo "TIMEOUT" > "$result_file"
  kill -TERM "$test_pid" 2>/dev/null || :
  sleep 1
  kill -KILL "$test_pid" 2>/dev/null || :
fi

rm -f "$signal_file" 2>/dev/null || :
