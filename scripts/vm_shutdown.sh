#!/usr/bin/env bash
# Gracefully shut down the running test VM: sends an ACPI power-button press
# through the QEMU monitor socket, waits for the guest to power off, and
# falls back to killing QEMU if it has not exited after 90 seconds.
set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nixos-vm"
MON="$STATE/monitor.sock"
PIDFILE="$STATE/vm.pid"

if [ ! -S "$MON" ]; then
  echo "No monitor socket at $MON — VM does not appear to be running." >&2
  exit 1
fi

python3 - "$MON" <<'EOF'
import socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
time.sleep(0.5)
s.recv(65536)
s.sendall(b"system_powerdown\n")
time.sleep(1)
s.close()
EOF
echo "Power-off requested; waiting for the guest to shut down..."

PID="$(cat "$PIDFILE" 2>/dev/null || true)"
for _ in $(seq 1 90); do
  if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
    echo "VM has shut down."
    rm -f "$PIDFILE"
    exit 0
  fi
  sleep 1
done

echo "Guest did not power off in 90s; killing QEMU (pid $PID)." >&2
kill "$PID" 2>/dev/null || true
rm -f "$PIDFILE"
