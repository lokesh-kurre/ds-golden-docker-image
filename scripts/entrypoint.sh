#!/usr/bin/env bash
set -e

mkdir -p "${SERVE_DIR}"

COREDUMP_DIR="${SERVE_DIR}/coredump"
mkdir -p "${COREDUMP_DIR}"

ulimit -c unlimited
CORE_PATTERN="/proc/sys/kernel/core_pattern"
DESIRED_PATTERN="${SERVE_DIR}/coredump/core.%e.%p.%t"

if [ -w "$CORE_PATTERN" ]; then
  echo "$DESIRED_PATTERN" > "$CORE_PATTERN" || \
    echo "Failed to set core_pattern despite being writable"
else
  echo "Skipping core_pattern setup (not writable)"
fi


if [ ! -f "$HOME/.bashrc" ]; then
  cp -r /opt/tmphome/. "$HOME/"
fi

cd "${SERVE_DIR}"
exec jupyter-lab

