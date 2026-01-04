#!/usr/bin/env bash
set -e

mkdir -p "${SERVE_DIR}"

COREDUMP_DIR="${SERVE_DIR}/coredump"
mkdir -p "${COREDUMP_DIR}"

ulimit -c unlimited
echo "${COREDUMP_DIR}/core.%e.%p.%t" | sudo tee /proc/sys/kernel/core_pattern > /dev/null

if [ ! -f "$HOME/.bashrc" ]; then
  cp -r /opt/tmphome/. "$HOME/"
fi

cd "${SERVE_DIR}"
exec jupyter-lab

