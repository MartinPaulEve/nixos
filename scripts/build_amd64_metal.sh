#!/usr/bin/env bash
# Rebuild and switch the bare-metal AMD machine (flake output nixos-amd64).
# Must be run on that machine; requires sudo.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

if [ "$(uname -m)" != "x86_64" ]; then
  echo "error: this rebuilds the x86_64 bare-metal system; this machine is $(uname -m)." >&2
  echo "       On the Mac/Parallels guest use build_aarch64_mac.sh instead." >&2
  exit 1
fi

exec sudo nixos-rebuild switch --flake "$ROOT#nixos-amd64"
