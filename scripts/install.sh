#!/usr/bin/env bash
# Set this configuration up on a machine that already runs a base NixOS
# install: asks for everything that is particular to the machine, writes its
# host directory (hosts/<hostname>/), and offers to build and switch to it.
#
#   ./scripts/install.sh
#
# What it works out, asking you to confirm each:
#   - the hostname                   (becomes the hosts/ directory name)
#   - the hardware scan              (found in /etc/nixos, or generated fresh)
#   - the processor                  (AMD or Intel: microcode, KVM, firmware)
#   - the graphics card              (NVIDIA driver, Radeon, Intel)
#   - the release first installed    (system.stateVersion, from /etc/nixos)
#   - where the EFI partition lives  (and how many boot entries fit on it)
#   - disk-encryption settings that the base install kept outside the scan
#
# Nothing is written until every answer is in, and nothing outside this
# repository is touched unless you agree to the final build step. Every
# question also has a flag, for scripted use (and for tests/install_test.sh):
#
#   --hostname NAME          hostname / host directory
#   --hardware-config PATH   hardware scan to use; "generate" for a fresh one
#   --cpu amd|intel|none
#   --gpu nvidia|nvidia-open|amd|intel|none
#   --state-version XX.YY
#   --yes                    accept the detected answer to anything not given
#   --force                  replace an existing hosts/NAME
#   --no-verify              do not check that the new host evaluates
#   --no-build               stop after writing the files
#   -h, --help
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

# Where the machine is read from. Overridable so the tests can describe a
# fake machine; on a real one these are always the defaults.
ETC_NIXOS="${INSTALL_ETC_NIXOS:-/etc/nixos}"
SYSFS="${INSTALL_SYSFS:-/sys}"
CPUINFO="${INSTALL_CPUINFO:-/proc/cpuinfo}"
ARCH="${INSTALL_ARCH:-$(uname -m)}"

# The base install usually has not enabled flakes yet.
export NIX_CONFIG="experimental-features = nix-command flakes${NIX_CONFIG:+
$NIX_CONFIG}"

HOST="" HWCONFIG="" CPU="" GPU="" STATE_VERSION=""
YES=0 FORCE=0 VERIFY=1 BUILD=1
HOST_GIVEN=0

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hostname) HOST="${2-}"; HOST_GIVEN=1; shift 2 ;;
    --hardware-config) HWCONFIG="${2-}"; shift 2 ;;
    --cpu) CPU="${2-}"; shift 2 ;;
    --gpu) GPU="${2-}"; shift 2 ;;
    --state-version) STATE_VERSION="${2-}"; shift 2 ;;
    --yes) YES=1; shift ;;
    --force) FORCE=1; shift ;;
    --no-verify) VERIFY=0; shift ;;
    --no-build) BUILD=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument '$1'" >&2; echo >&2; usage >&2; exit 2 ;;
  esac
done

# --- Small helpers -----------------------------------------------------------

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
section() { echo; bold "== $* =="; }
note() { echo "  $*"; }
warn() { echo "  warning: $*" >&2; }
die() { echo "error: $*" >&2; exit 1; }

# ask VAR "Question" DEFAULT — keeps a value already given by flag; with
# --yes takes the default; otherwise prompts (Enter accepts the default).
ask() {
  local var="$1" question="$2" default="${3-}" answer
  if [ -n "${!var}" ]; then return 0; fi
  if [ "$YES" = 1 ]; then printf -v "$var" '%s' "$default"; return 0; fi
  if [ ! -t 0 ]; then
    die "no answer for: $question (not a terminal; pass the flag or --yes)"
  fi
  read -r -p "  $question${default:+ [$default]}: " answer
  printf -v "$var" '%s' "${answer:-$default}"
}

# confirm "Question" — yes/no, default yes; --yes answers yes.
confirm() {
  local answer
  if [ "$YES" = 1 ]; then return 0; fi
  [ -t 0 ] || return 1
  read -r -p "  $1 [Y/n]: " answer
  case "$answer" in ""|y|Y|yes|Yes) return 0 ;; *) return 1 ;; esac
}

# --- Preconditions -----------------------------------------------------------

[ "$ARCH" = "x86_64" ] || die "this sets up an x86_64 machine; this one is $ARCH.
       (The aarch64 Parallels guest is hosts/nixos and needs no installer.)"

# modules/nixos/boot.nix boots with systemd-boot, which is UEFI-only. On a
# machine booted in legacy BIOS mode the switch would leave it unbootable.
[ -d "$SYSFS/firmware/efi" ] || die "this machine was not booted in UEFI mode.
       The configuration boots with systemd-boot, which needs UEFI. Reinstall
       the base system in UEFI mode (and disable CSM/legacy boot) first."

if [ -e "$ROOT/.git" ] && ! command -v git >/dev/null; then
  die "git is needed (Nix reads this repository through it). Re-run as:
         nix-shell -p git --run '$0'"
fi

bold "Setting up this machine from $ROOT"
echo "Answer each question, or press Enter to accept the detected value."

# --- Hostname ----------------------------------------------------------------

section "Hostname"
note "This names the machine everywhere: on the network, on the tailnet,"
note "in NextDNS, and as its directory under hosts/. Lowercase letters,"
note "digits and hyphens; it must not be a name another machine uses."

current="$(hostname 2>/dev/null || true)"
# "nixos" is what every base install calls itself, and it is taken: it is
# the Parallels guest's host directory.
case "$current" in ""|nixos|nixos-vm-x86) suggested="" ;; *) suggested="$current" ;; esac

valid_hostname() {
  [[ "$1" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || {
    echo "lowercase letters, digits and hyphens only, not starting or ending with a hyphen"
    return 1
  }
  case "$1" in
    nixos) echo "'nixos' is the Parallels guest's name (hosts/nixos); pick another"; return 1 ;;
    nixos-vm-x86) echo "'nixos-vm-x86' is the test VM's flake output; pick another"; return 1 ;;
  esac
  if [ -e "$ROOT/hosts/$1" ] && [ "$FORCE" != 1 ]; then
    echo "hosts/$1 already exists; pick another name, or pass --force to replace it"
    return 1
  fi
}

while :; do
  if [ "$HOST_GIVEN" != 1 ]; then ask HOST "Hostname" "$suggested"; fi
  if reason="$(valid_hostname "$HOST")"; then break; fi
  if [ "$HOST_GIVEN" = 1 ] || [ "$YES" = 1 ] || [ ! -t 0 ]; then
    die "hostname '$HOST': $reason"
  fi
  echo "  '$HOST': $reason"
  HOST=""
done
note "Hostname: $HOST"

# --- Hardware scan -----------------------------------------------------------

section "Hardware scan"
note "The scan records this machine's disks, filesystems and storage drivers."

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
existing="$ETC_NIXOS/hardware-configuration.nix"

if [ -z "$HWCONFIG" ]; then
  if [ -r "$existing" ]; then
    note "Found the base install's scan: $existing"
    if [ "$YES" = 1 ] || [ ! -t 0 ]; then
      HWCONFIG="$existing"
    else
      echo "    1) use that file (what this machine boots from today)"
      echo "    2) generate a fresh scan now (if disks changed since the install)"
      echo "    3) use a different file"
      choice=""; ask choice "Choice" 1
      case "$choice" in
        2) HWCONFIG=generate ;;
        3) ask HWCONFIG "Path to the hardware scan" "" ;;
        *) HWCONFIG="$existing" ;;
      esac
    fi
  else
    note "No scan at $existing; generating a fresh one."
    HWCONFIG=generate
  fi
fi

if [ "$HWCONFIG" = generate ]; then
  command -v nixos-generate-config >/dev/null \
    || die "nixos-generate-config not found; pass --hardware-config PATH instead."
  note "Running nixos-generate-config (needs sudo to see every device)..."
  sudo nixos-generate-config --show-hardware-config > "$STAGE/hardware-configuration.nix"
else
  [ -r "$HWCONFIG" ] || die "hardware scan '$HWCONFIG' does not exist or is not readable."
  cp "$HWCONFIG" "$STAGE/hardware-configuration.nix"
  note "Using $HWCONFIG"
fi
chmod u+w "$STAGE/hardware-configuration.nix"
SCAN="$STAGE/hardware-configuration.nix"

grep -q 'fileSystems\."/"' "$SCAN" \
  || die "the hardware scan declares no root filesystem; it does not look like a NixOS hardware-configuration.nix."

# --- Processor ---------------------------------------------------------------

section "Processor"
case "$(grep -m1 '^vendor_id' "$CPUINFO" 2>/dev/null | awk '{print $3}')" in
  AuthenticAMD) detected_cpu=amd ;;
  GenuineIntel) detected_cpu=intel ;;
  *) detected_cpu=none ;;
esac
note "Detected: $detected_cpu"
ask CPU "Processor profile (amd / intel / none)" "$detected_cpu"
case "$CPU" in amd|intel|none) ;; *) die "--cpu must be amd, intel or none (got '$CPU')." ;; esac

# --- Graphics ----------------------------------------------------------------

section "Graphics card"
# Display adapters are PCI class 0x03xxxx; the vendor id says whose.
gpu_vendors=""
for dev in "$SYSFS"/bus/pci/devices/*; do
  [ -r "$dev/class" ] || continue
  case "$(cat "$dev/class")" in 0x03*) gpu_vendors="$gpu_vendors $(cat "$dev/vendor")" ;; esac
done
# A discrete NVIDIA card wins over the integrated graphics beside it.
case " $gpu_vendors " in
  *" 0x10de "*) detected_gpu=nvidia ;;
  *" 0x1002 "*) detected_gpu=amd ;;
  *" 0x8086 "*) detected_gpu=intel ;;
  *) detected_gpu=none ;;
esac
note "Detected: $detected_gpu${gpu_vendors:+ (PCI vendors:$gpu_vendors)}"
if [ "$detected_gpu" = nvidia ] && [ -z "$GPU" ] && [ "$YES" != 1 ]; then
  note "NVIDIA's driver comes with one of two kernel modules:"
  note "  nvidia       proprietary module — every card up to the RTX 40 series"
  note "  nvidia-open  NVIDIA's open module — REQUIRED for the RTX 50 series,"
  note "               also fine for RTX 20/30/40 and GTX 16; not older cards"
fi
ask GPU "Graphics (nvidia / nvidia-open / amd / intel / none)" "$detected_gpu"
case "$GPU" in
  nvidia|nvidia-open|amd|intel|none) ;;
  *) die "--gpu must be nvidia, nvidia-open, amd, intel or none (got '$GPU')." ;;
esac

# --- Release first installed ---------------------------------------------------

section "Install release"
note "system.stateVersion must stay at the release this machine was FIRST"
note "installed with, whatever it runs now; it is not the version to upgrade to."
detected_sv="$(sed -n 's/^[^#]*system\.stateVersion *= *"\([0-9][0-9]\.[0-9][0-9]\)".*/\1/p' \
  "$ETC_NIXOS/configuration.nix" 2>/dev/null | head -1)"
if [ -z "$detected_sv" ]; then
  detected_sv="$(nixos-version 2>/dev/null | sed -n 's/^\([0-9][0-9]\.[0-9][0-9]\).*/\1/p')"
  [ -n "$detected_sv" ] && note "Not found in $ETC_NIXOS/configuration.nix; the running release is $detected_sv."
else
  note "Found in $ETC_NIXOS/configuration.nix: $detected_sv"
fi
ask STATE_VERSION "Release first installed (e.g. 26.05)" "$detected_sv"
[[ "$STATE_VERSION" =~ ^[0-9]{2}\.[0-9]{2}$ ]] \
  || die "state version must look like 26.05 (got '$STATE_VERSION')."

# --- Boot partition ------------------------------------------------------------

section "Boot partition"
# The EFI system partition is the vfat filesystem in the scan. Most installs
# mount it at /boot (which is what the shared config assumes); some use
# /boot/efi or /efi.
ESP="$(awk -F'"' '/fileSystems\."/ { mp = $2 } /fsType *= *"vfat"/ { print mp; exit }' "$SCAN")"
if [ -z "$ESP" ]; then
  warn "no vfat (EFI) filesystem in the scan; assuming it is mounted at /boot."
  ESP=/boot
fi
note "EFI system partition mounted at: $ESP"

# Each boot entry stores a kernel and an initrd on that partition, and the
# NVIDIA driver makes the initrd large. Keep fewer entries on a small one so
# a rebuild can never fill it (the config's usual limit is 10).
esp_mb="${INSTALL_ESP_MB:-$(df -m --output=size "$ESP" 2>/dev/null | tail -1 | tr -d ' ')}"
BOOT_ENTRIES=""
if [[ "$esp_mb" =~ ^[0-9]+$ ]]; then
  if [ "$esp_mb" -lt 600 ]; then BOOT_ENTRIES=3
  elif [ "$esp_mb" -lt 1000 ]; then BOOT_ENTRIES=5
  fi
  note "Size: ${esp_mb} MiB${BOOT_ENTRIES:+ — small, so only $BOOT_ENTRIES boot entries will be kept}"
fi

# --- Settings the base install kept outside the scan ---------------------------

# The graphical installer writes some disk-encryption settings (extra LUKS
# devices, the key file in the initrd) into configuration.nix rather than
# the hardware scan. This configuration replaces configuration.nix, so
# without them the machine would not find its encrypted disks at boot.
CARRIED=""
BASECONF="$ETC_NIXOS/configuration.nix"
if [ -r "$BASECONF" ]; then
  luks="$(grep -E '^[[:space:]]*boot\.initrd\.luks\.devices\."[^"]+"[^;]*;[[:space:]]*$' "$BASECONF" || true)"
  secrets="$(sed -n '/^[[:space:]]*boot\.initrd\.secrets[[:space:]]*=[[:space:]]*{/,/};/p' "$BASECONF")"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    name="$(echo "$line" | sed 's/.*luks\.devices\."\([^"]*\)".*/\1/')"
    # Already in the scan? Then the scan is the single source for it — but
    # only skip the plain `.device` line; a keyFile line is still needed.
    if grep -q "luks\.devices\.\"$name\"\.device" "$SCAN" && echo "$line" | grep -q '\.device *='; then
      continue
    fi
    CARRIED="$CARRIED  $(echo "$line" | sed 's/^[[:space:]]*//')
"
  done <<< "$luks"
  if [ -n "$secrets" ]; then
    CARRIED="$CARRIED$(echo "$secrets" | sed 's/^[[:space:]]*/  /; 2,$ s/^  \([^}]\)/    \1/')
"
  fi
  if [ -n "$CARRIED" ]; then
    section "Disk encryption"
    note "Carrying these over from $BASECONF:"
    echo "$CARRIED" | sed '/^$/d; s/^/    /'
  fi
  if grep -qE '^[[:space:]]*boot\.loader\.grub\.(enable|device)' "$BASECONF"; then
    section "Bootloader"
    warn "the base install boots with GRUB. This configuration installs"
    warn "systemd-boot on the EFI partition instead; the old GRUB entry stays"
    warn "in the firmware boot menu but is no longer updated."
  fi
fi

# --- Write the host directory ----------------------------------------------------

section "Writing hosts/$HOST"

imports="    ./hardware-configuration.nix"
describe=""
case "$CPU" in
  amd) imports="$imports
    ../../modules/hardware/amd.nix"; describe="AMD processor" ;;
  intel) imports="$imports
    ../../modules/hardware/intel.nix"; describe="Intel processor" ;;
  none) describe="no processor profile" ;;
esac
body=""
case "$GPU" in
  nvidia|nvidia-open)
    imports="$imports
    ../../modules/hardware/nvidia.nix"
    describe="$describe, NVIDIA graphics card"
    if [ "$GPU" = nvidia-open ]; then
      body="$body
  # NVIDIA's open kernel module (required for the RTX 50 series) instead of
  # the proprietary one; see modules/hardware/nvidia.nix.
  hardware.nvidia.open = true;
"
    fi ;;
  amd)
    describe="$describe, Radeon graphics"
    body="$body
  # Early KMS for Radeon graphics, so the Plymouth splash draws on the real
  # driver from the start (see modules/nixos/boot.nix).
  hardware.amdgpu.initrd.enable = true;
" ;;
  intel) describe="$describe, Intel graphics" ;;
  none) describe="$describe, no graphics profile" ;;
esac
if [ "$CPU" = none ]; then
  body="$body
  # No processor profile was chosen, so state the one thing every real
  # machine needs from one: firmware for its Wi-Fi, Bluetooth and graphics.
  hardware.enableRedistributableFirmware = true;
"
fi
if [ "$ESP" != /boot ]; then
  body="$body
  # This machine mounts its EFI system partition here rather than at /boot.
  boot.loader.efi.efiSysMountPoint = \"$ESP\";
"
fi
if [ -n "$BOOT_ENTRIES" ]; then
  body="$body
  # The EFI system partition is small (${esp_mb} MiB): keep fewer boot
  # entries than the shared default so a rebuild can never fill it.
  boot.loader.systemd-boot.configurationLimit = lib.mkForce $BOOT_ENTRIES;
"
fi
if [ -n "$CARRIED" ]; then
  body="$body
  # Disk-encryption settings the base install kept in
  # /etc/nixos/configuration.nix rather than in the hardware scan.
$CARRIED"
fi

cat > "$STAGE/default.nix" <<NIX
# $HOST: a bare-metal machine — $describe.
#
# Written by scripts/install.sh from this machine's own answers; edit it
# freely afterwards. A host directory holds only what is particular to one
# machine. The shared system modules, the Home Manager configuration and the
# hostname — which is this directory's name — are all supplied by flake.nix,
# so every host gets the same packages and home directory.
{ lib, ... }:

{
  imports = [
$imports
  ];
$body
  # The NixOS release this system was first installed with.
  # See \`man configuration.nix\` before changing.
  system.stateVersion = "$STATE_VERSION";
}
NIX

# Everything is decided: only now touch the repository.
rm -rf "$ROOT/hosts/$HOST"
mkdir -p "$ROOT/hosts/$HOST"
cp "$STAGE/default.nix" "$STAGE/hardware-configuration.nix" "$ROOT/hosts/$HOST/"
note "hosts/$HOST/default.nix"
note "hosts/$HOST/hardware-configuration.nix"

# Flakes only see files git knows about.
if [ -e "$ROOT/.git" ]; then
  git -C "$ROOT" add "hosts/$HOST"
  note "(staged in git; commit when the machine is up)"
fi

# --- Check it evaluates ------------------------------------------------------------

if [ "$VERIFY" = 1 ]; then
  section "Checking the configuration"
  note "Evaluating the whole system for $HOST (a minute or so, builds nothing)..."
  if ! nix eval --raw "$ROOT#nixosConfigurations.$HOST.config.system.build.toplevel.drvPath" >/dev/null; then
    die "hosts/$HOST does not evaluate; see the error above. The files are in
       place — fix them and re-run with --hostname $HOST --force, or build with
       build_amd64_metal.sh $HOST once it is fixed."
  fi
  note "It evaluates."
fi

# --- Build and switch ----------------------------------------------------------------

REPO_HOME=/home/martin/nixos

next_steps() {
  section "Next"
  if [ "$1" = built ]; then
    note "Reboot now: the new kernel, graphics driver and login screen only"
    note "take over on a fresh boot. Log in as martin."
  else
    note "Build and switch when ready (as a user who can sudo):"
    note "  sudo NIX_CONFIG='experimental-features = nix-command flakes' \\"
    note "    nixos-rebuild switch --flake $ROOT#$HOST"
    note "then, if the martin account is new:  sudo passwd martin"
  fi
  note "After the first boot, rebuild with build_amd64_metal.sh and update"
  note "with update.sh. AMD64.md lists what to set up by hand (Bitwarden,"
  note "Tailscale, your files) under \"State the repository does not carry\"."
}

if [ "$BUILD" != 1 ]; then next_steps written; exit 0; fi

section "Build and switch"
note "This downloads the system (around 9 GiB the first time), compiles the"
note "graphics driver, and switches this machine to it. The current system"
note "stays in the boot menu as a fallback."
if ! id martin >/dev/null 2>&1; then
  note "The configuration's user is 'martin', which does not exist here yet."
  note "You will be asked to choose its password straight after the switch."
fi
if [ "$ROOT" != "$REPO_HOME" ]; then
  note "The repository will also be copied to $REPO_HOME, where the"
  note "configuration expects it (its scripts/ directory goes on PATH)."
fi
if ! confirm "Build and switch now?"; then next_steps written; exit 0; fi

# One root shell for the switch and everything after it. The switch removes
# accounts the new configuration does not declare — possibly the one running
# this script — after which a fresh `sudo` would no longer work.
sudo env NIX_CONFIG="$NIX_CONFIG" ROOT="$ROOT" HOST="$HOST" REPO_HOME="$REPO_HOME" \
  bash -euc '
    nixos-rebuild switch --flake "$ROOT#$HOST"

    # A new account has no password, and the login screen refuses those.
    if [ "$(passwd -S martin 2>/dev/null | cut -d" " -f2)" != P ]; then
      echo
      echo "Choose a login password for martin:"
      until passwd martin; do echo "Try again."; done
    fi

    if [ "$ROOT" != "$REPO_HOME" ] && [ ! -e "$REPO_HOME" ]; then
      cp -a "$ROOT" "$REPO_HOME"
      chown -R martin:users "$REPO_HOME"
      echo "Repository copied to $REPO_HOME (the copy in $ROOT can be deleted)."
    elif [ "$ROOT" != "$REPO_HOME" ]; then
      echo "warning: $REPO_HOME already exists, so the repository was not copied there." >&2
      echo "         Move this checkout there by hand: its scripts/ must be on PATH." >&2
    fi
  '

next_steps built
