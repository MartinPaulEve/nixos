#!/usr/bin/env bash
# Rebuild and switch a bare-metal x86_64 machine. Must be run on that machine;
# requires sudo.
#
# The flake output is the machine's hostname, which is also the name of its
# directory under hosts/. Pass a name to override that — needed only when the
# running system's hostname does not match yet (e.g. just after renaming the
# host directory):
#
#   build_amd64_metal.sh              # this machine
#   build_amd64_metal.sh new-name     # switch to hosts/new-name
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
HOST="${1:-$(hostname)}"

if [ "$(uname -m)" != "x86_64" ]; then
  echo "error: this rebuilds an x86_64 bare-metal system; this machine is $(uname -m)." >&2
  echo "       On the Mac/Parallels guest use build_aarch64_mac.sh instead." >&2
  exit 1
fi

if [ ! -d "$ROOT/hosts/$HOST" ]; then
  echo "error: no host directory $ROOT/hosts/$HOST." >&2
  echo "       Known hosts: $(cd "$ROOT/hosts" && echo *)" >&2
  echo "       See AMD64.md for adding a machine." >&2
  exit 1
fi

exec sudo nixos-rebuild switch --flake "$ROOT#$HOST"
