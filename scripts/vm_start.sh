#!/usr/bin/env bash
# Start the x86_64 test VM headless, display served over SPICE on
# localhost:5930 (the port set in modules/nixos/vm.nix). Builds the VM first
# if it has not been built yet. View it with spice_vm_connect.sh; stop it
# with vm_shutdown.sh.
#
# VM state (disk image, logs, sockets) lives in ~/.local/state/nixos-vm.
# Delete nixos.qcow2 there for a factory-fresh VM.
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nixos-vm"
SPICE_PORT=5930

if ss -tln 2>/dev/null | grep -q ":$SPICE_PORT "; then
  echo "error: something is already listening on port $SPICE_PORT — is the VM already running?" >&2
  exit 1
fi

if [ ! -e "$STATE/result-vm/bin/run-nixos-vm" ]; then
  echo "VM not built yet; building first..."
  "$SCRIPTS/build_x86_vm_spice.sh"
fi

mkdir -p "$STATE"
NIX_DISK_IMAGE="$STATE/nixos.qcow2" \
QEMU_OPTS="-monitor unix:$STATE/monitor.sock,server,nowait -serial file:$STATE/console.log" \
  nohup "$STATE/result-vm/bin/run-nixos-vm" > "$STATE/vm.log" 2>&1 &
echo $! > "$STATE/vm.pid"

echo "VM starting (pid $(cat "$STATE/vm.pid")). Logs: $STATE/vm.log"
echo "Connect with: spice_vm_connect.sh   (spice://127.0.0.1:$SPICE_PORT)"
