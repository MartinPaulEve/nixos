#!/usr/bin/env bash
# Build the x86_64 test VM (SPICE-viewable QEMU variant of the system).
# Safe to run anywhere with Nix; does not touch the running system.
# The runner symlink is kept in the VM state dir, where vm_start.sh expects it.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nixos-vm"

mkdir -p "$STATE"
nix build "$ROOT#nixosConfigurations.nixos-vm-x86.config.system.build.vm" \
  --out-link "$STATE/result-vm"

echo "VM built: $STATE/result-vm/bin/run-nixos-vm"
echo "Start it with: vm_start.sh"
