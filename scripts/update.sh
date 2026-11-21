#!/usr/bin/env bash
# Pull the latest security and package updates and rebuild the real system.
#
# On NixOS every fix arrives the same way: the `nixpkgs` flake input moves to a
# newer commit of the stable release branch (where upstream backports security
# patches) and the system is rebuilt from it. This script does that in one go:
#
#   1. refuses to run if flake.lock has uncommitted changes (the update commits
#      the lock, and must not sweep unrelated edits into that commit);
#   2. updates the chosen inputs and commits the new flake.lock;
#   3. if the lock actually changed, rebuilds via this machine's build script
#      (build_aarch64_mac.sh on the Parallels guest, build_amd64_metal.sh on
#      the bare-metal AMD machine);
#   4. prints what changed between the running and the new system, and says
#      so if the kernel moved, since a switch alone keeps the old kernel running.
#
# Usage:
#   update.sh                 update nixpkgs + home-manager (the security path)
#   update.sh --all           update every flake input
#   update.sh INPUT...        update only the named inputs
#   update.sh --rebuild       rebuild even if the lock did not change
#
# Other uncommitted work in the repository is left alone and will be included
# in the rebuild, exactly as the build script would include it.
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ROOT="$(cd "$SCRIPTS/.." && pwd)"
# Overridable so the reboot check can be exercised outside a live system.
BOOTED_SYSTEM="${BOOTED_SYSTEM:-/run/booted-system}"
CURRENT_SYSTEM="${CURRENT_SYSTEM:-/run/current-system}"

usage() {
  sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \{0,1\}//'
}

inputs=(nixpkgs home-manager)
named=()
all=0
force_rebuild=0
for arg in "$@"; do
  case "$arg" in
    --all) all=1 ;;
    --rebuild) force_rebuild=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option '$arg'" >&2; echo >&2; usage >&2; exit 2 ;;
    *) named+=("$arg") ;;
  esac
done
if [ "$all" = 1 ]; then
  inputs=()
elif [ "${#named[@]}" -gt 0 ]; then
  inputs=("${named[@]}")
fi

cd "$ROOT"

if ! git diff --quiet -- flake.lock || ! git diff --cached --quiet -- flake.lock; then
  echo "error: flake.lock has uncommitted changes; commit or discard them first" >&2
  echo "       (the update commits the lock file and must start from a clean one)." >&2
  exit 1
fi

before="$(git rev-parse HEAD:flake.lock)"
if [ "${#inputs[@]}" -gt 0 ]; then
  echo "Updating inputs: ${inputs[*]}"
else
  echo "Updating all flake inputs"
fi
nix flake update "${inputs[@]+"${inputs[@]}"}" --commit-lock-file
after="$(git rev-parse HEAD:flake.lock)"

if [ "$before" = "$after" ] && [ "$force_rebuild" != 1 ]; then
  echo "Already up to date: flake.lock unchanged, nothing to rebuild."
  echo "(Use --rebuild to rebuild anyway.)"
  exit 0
fi
if [ "$before" = "$after" ]; then
  echo "flake.lock unchanged; rebuilding anyway (--rebuild)."
fi

# Each machine rebuilds its own flake output.
case "$(uname -m)" in
  aarch64) "$SCRIPTS/build_aarch64_mac.sh" ;;
  x86_64) "$SCRIPTS/build_amd64_metal.sh" ;;
  *) echo "error: no rebuild script for $(uname -m)." >&2; exit 1 ;;
esac

echo
echo "Changes between the booted system and the new one:"
nix store diff-closures "$BOOTED_SYSTEM" "$CURRENT_SYSTEM" || true

if [ -e "$BOOTED_SYSTEM/kernel" ] && [ -e "$CURRENT_SYSTEM/kernel" ] \
   && ! cmp -s "$BOOTED_SYSTEM/kernel" "$CURRENT_SYSTEM/kernel"; then
  echo
  echo "The kernel changed: reboot to start running the new one."
fi
