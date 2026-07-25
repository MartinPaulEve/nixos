#!/usr/bin/env bash
# Open a SPICE viewer on the running test VM (see vm_start.sh).
set -euo pipefail

SPICE_PORT=5930

if ! command -v remote-viewer >/dev/null; then
  echo "error: remote-viewer not found — install virt-viewer." >&2
  exit 1
fi

if ! ss -tln 2>/dev/null | grep -q ":$SPICE_PORT "; then
  echo "error: nothing listening on port $SPICE_PORT — start the VM first with vm_start.sh." >&2
  exit 1
fi

exec remote-viewer "spice://127.0.0.1:$SPICE_PORT"
