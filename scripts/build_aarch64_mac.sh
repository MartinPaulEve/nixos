#!/usr/bin/env bash
# Rebuild and switch the real system (the aarch64 Parallels guest on the Mac).
# Must be run on that machine; requires sudo.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

if [ "$(uname -m)" != "aarch64" ]; then
  echo "error: this rebuilds the aarch64 Mac/Parallels system; this machine is $(uname -m)." >&2
  echo "       For the local x86_64 test VM use build_x86_vm_spice.sh instead." >&2
  exit 1
fi

exec sudo nixos-rebuild switch --flake "$ROOT#nixos"
