#!/usr/bin/env bash
# Check that the Parallels guest (nixos) and every bare-metal machine under
# hosts/ still evaluate to the same packages and home directory, and
# that each keeps its own hardware-specific pieces. Evaluation only: nothing
# is built or switched, so it is safe to run on either machine.
#
# The checks themselves live in tests/hosts.nix. Exits non-zero if any fails.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

result="$(nix eval --impure --json --file "$ROOT/tests/hosts.nix")"

echo "$result" | jq -r 'to_entries[] | (if .value then "ok    " else "FAIL  " end) + .key'

failed="$(echo "$result" | jq '[.[] | select(. != true)] | length')"
total="$(echo "$result" | jq 'length')"
echo
if [ "$failed" -ne 0 ]; then
  echo "$failed of $total checks failed."
  exit 1
fi
echo "All $total checks passed."
