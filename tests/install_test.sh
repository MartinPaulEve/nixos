#!/usr/bin/env bash
# Tests for scripts/install.sh.
#
# Each case runs the installer non-interactively against a throwaway copy of
# the repository and a fake machine (fake /etc/nixos, /proc/cpuinfo and PCI
# tree), then checks what the resulting host *evaluates to* — not the text
# of the generated files — so the installer can change how it writes a host
# as long as the machine it describes is right. Nothing is built or switched.
#
#   tests/install_test.sh
set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export NIX_CONFIG="experimental-features = nix-command flakes"

fails=0
ok() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }
check() { # check NAME ACTUAL EXPECTED
  if [ "$2" = "$3" ]; then ok "$1"; else fail "$1 (got '$2', wanted '$3')"; fi
}

# A fresh copy of the repo (no .git, no build results) for one case.
new_repo() {
  local dir="$WORK/repo-$1"
  mkdir -p "$dir"
  (cd "$REPO" && tar cf - --exclude=.git --exclude='result*' .) | tar xf - -C "$dir"
  echo "$dir"
}

# A fake machine: $1 = dir, $2 = CPU vendor string, $3.. = PCI display vendors.
# It was started by systemd-boot; booted_by_grub makes it a GRUB machine.
new_machine() {
  local dir="$1" cpu="$2" i=0
  shift 2
  mkdir -p "$dir/etc" "$dir/sys/firmware/efi" "$dir/sys/bus/pci/devices"
  printf 'processor\t: 0\nvendor_id\t: %s\n' "$cpu" > "$dir/cpuinfo"
  echo 'initrd=\EFI\nixos\abc-initrd.efi init=/nix/store/abc-nixos-system/init loglevel=4' > "$dir/cmdline"
  for vendor in "$@"; do
    mkdir -p "$dir/sys/bus/pci/devices/0000:0$i:00.0"
    echo 0x030000 > "$dir/sys/bus/pci/devices/0000:0$i:00.0/class"
    echo "$vendor" > "$dir/sys/bus/pci/devices/0000:0$i:00.0/vendor"
    i=$((i + 1))
  done
  # Something that is not a display adapter, to be ignored.
  mkdir -p "$dir/sys/bus/pci/devices/0000:09:00.0"
  echo 0x020000 > "$dir/sys/bus/pci/devices/0000:09:00.0/class"
  echo 0x10de > "$dir/sys/bus/pci/devices/0000:09:00.0/vendor"
}

# The kernel command line GRUB leaves behind: it adds BOOT_IMAGE=.
booted_by_grub() {
  echo 'BOOT_IMAGE=(hd0,gpt2)//kernels/abc-linux-bzImage init=/nix/store/abc-nixos-system/init loglevel=4' > "$1/cmdline"
}

# The hardware scan a base install leaves in /etc/nixos. $2 = ESP mount point.
hardware_config() {
  cat > "$1" <<NIX
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" ];
  fileSystems."/" = { device = "/dev/disk/by-uuid/11111111-aaaa-bbbb-cccc-222222222222"; fsType = "ext4"; };
  fileSystems."$2" = { device = "/dev/disk/by-uuid/ABCD-1234"; fsType = "vfat"; };
  swapDevices = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
NIX
}

run_install() { # run_install MACHINE REPO ARGS...
  local m="$1" r="$2"
  shift 2
  INSTALL_ETC_NIXOS="$m/etc" INSTALL_SYSFS="$m/sys" INSTALL_CPUINFO="$m/cpuinfo" \
    INSTALL_CMDLINE="$m/cmdline" \
    INSTALL_ARCH="${ARCH:-x86_64}" INSTALL_ESP_MB="${ESP_MB:-2048}" \
    "$r/scripts/install.sh" --no-build --no-verify "$@" < /dev/null > "$WORK/out.log" 2>&1
}

# Evaluate facts about a generated host as JSON.
facts() { # facts REPO HOST
  nix eval --json --impure --expr "
    let c = (builtins.getFlake \"path:$1\").nixosConfigurations.\"$2\".config; in {
      hostName = c.networking.hostName;
      nvidia = builtins.elem \"nvidia\" c.services.xserver.videoDrivers;
      nvidiaOpen = if builtins.elem \"nvidia\" c.services.xserver.videoDrivers then c.hardware.nvidia.open else null;
      amd = c.hardware.cpu.amd.updateMicrocode;
      intel = c.hardware.cpu.intel.updateMicrocode;
      amdgpuInitrd = c.hardware.amdgpu.initrd.enable;
      firmware = c.hardware.enableRedistributableFirmware;
      stateVersion = c.system.stateVersion;
      root = c.fileSystems.\"/\".device;
      esp = c.boot.loader.efi.efiSysMountPoint;
      luks = builtins.attrNames c.boot.initrd.luks.devices;
      # Exactly one bootloader must be on; "both" or "none" would not boot.
      bootloader =
        if c.boot.loader.grub.enable && c.boot.loader.systemd-boot.enable then \"both\"
        else if c.boot.loader.grub.enable then \"grub\"
        else if c.boot.loader.systemd-boot.enable then \"systemd-boot\"
        else \"none\";
      grubEfi = c.boot.loader.grub.efiSupport && c.boot.loader.grub.device == \"nodev\";
      otherSystems = c.boot.loader.grub.useOSProber;
      # The limit of whichever bootloader is in use.
      bootEntries =
        if c.boot.loader.grub.enable then c.boot.loader.grub.configurationLimit
        else c.boot.loader.systemd-boot.configurationLimit;
      system = c.nixpkgs.hostPlatform.system;
      parallels = c.hardware.parallels.enable;
      buildable = builtins.isString c.system.build.toplevel.drvPath;
    }" 2> "$WORK/eval.log"
}
get() { echo "$1" | jq -r "$2"; }

# --- A: AMD + NVIDIA, everything given as flags ----------------------------
r="$(new_repo a)"; m="$WORK/machine-a"; new_machine "$m" AuthenticAMD 0x10de
hardware_config "$m/etc/hardware-configuration.nix" /boot
echo '{ system.stateVersion = "25.11"; }' > "$m/etc/configuration.nix"
run_install "$m" "$r" --hostname tower --cpu amd --gpu nvidia \
  --hardware-config "$m/etc/hardware-configuration.nix" --yes
check "A: installer succeeds" "$?" 0
f="$(facts "$r" tower)"
check "A: hostname" "$(get "$f" .hostName)" tower
check "A: nvidia driver" "$(get "$f" .nvidia)" true
check "A: proprietary kernel module" "$(get "$f" .nvidiaOpen)" false
check "A: amd microcode" "$(get "$f" .amd)" true
check "A: firmware" "$(get "$f" .firmware)" true
check "A: machine's own root disk" "$(get "$f" .root)" /dev/disk/by-uuid/11111111-aaaa-bbbb-cccc-222222222222
check "A: state version from the base install" "$(get "$f" .stateVersion)" 25.11
check "A: esp at /boot" "$(get "$f" .esp)" /boot
check "A: roomy esp keeps the usual boot entries" "$(get "$f" .bootEntries)" 10
check "A: a systemd-boot machine stays on systemd-boot" "$(get "$f" .bootloader)" systemd-boot
check "A: x86_64, no parallels" "$(get "$f" '.system + " " + (.parallels|tostring)')" "x86_64-linux false"
check "A: whole system evaluates" "$(get "$f" .buildable)" true

# --- B: Intel CPU + Intel graphics, ESP at /boot/efi, LUKS, small ESP ------
r="$(new_repo b)"; m="$WORK/machine-b"; new_machine "$m" GenuineIntel 0x8086
hardware_config "$m/etc/hardware-configuration.nix" /boot/efi
cat > "$m/etc/configuration.nix" <<'NIX'
{ config, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.initrd.luks.devices."luks-5f0c".device = "/dev/disk/by-uuid/5f0c5f0c-0000-1111-2222-333333333333";
  system.stateVersion = "26.05"; # Did you read the comment?
}
NIX
ESP_MB=511 run_install "$m" "$r" --hostname laptop --yes
check "B: installer succeeds" "$?" 0
f="$(facts "$r" laptop)"
check "B: hostname" "$(get "$f" .hostName)" laptop
check "B: detects intel cpu" "$(get "$f" '(.intel|tostring) + " " + (.amd|tostring)')" "true false"
check "B: no nvidia" "$(get "$f" .nvidia)" false
check "B: esp mount point follows the scan" "$(get "$f" .esp)" /boot/efi
check "B: luks device carried over" "$(get "$f" '.luks|join(",")')" luks-5f0c
check "B: state version" "$(get "$f" .stateVersion)" 26.05
check "B: small esp keeps fewer boot entries" "$(get "$f" '.bootEntries < 10')" true
check "B: systemd-boot" "$(get "$f" .bootloader)" systemd-boot
check "B: whole system evaluates" "$(get "$f" .buildable)" true

# --- C: detection alone picks AMD + NVIDIA; open kernel module on request ---
r="$(new_repo c)"; m="$WORK/machine-c"; new_machine "$m" AuthenticAMD 0x1002 0x10de
hardware_config "$m/etc/hardware-configuration.nix" /boot
echo '{ system.stateVersion = "26.05"; }' > "$m/etc/configuration.nix"
run_install "$m" "$r" --hostname rig-2 --gpu nvidia-open --yes
check "C: installer succeeds" "$?" 0
f="$(facts "$r" rig-2)"
check "C: detects amd cpu" "$(get "$f" .amd)" true
check "C: nvidia with open kernel module" "$(get "$f" '(.nvidia|tostring) + " " + (.nvidiaOpen|tostring)')" "true true"

r2="$(new_repo c2)"
run_install "$m" "$r2" --hostname rig-3 --yes
f="$(facts "$r2" rig-3)"
check "C: nvidia preferred over integrated graphics when both present" "$(get "$f" .nvidia)" true

# --- D: Radeon-only machine --------------------------------------------------
r="$(new_repo d)"; m="$WORK/machine-d"; new_machine "$m" AuthenticAMD 0x1002
hardware_config "$m/etc/hardware-configuration.nix" /boot
echo '{ system.stateVersion = "26.05"; }' > "$m/etc/configuration.nix"
run_install "$m" "$r" --hostname radeon --yes
f="$(facts "$r" radeon)"
check "D: radeon gets early kms, not nvidia" "$(get "$f" '(.amdgpuInitrd|tostring) + " " + (.nvidia|tostring)')" "true false"

# --- F: a machine that boots with GRUB keeps GRUB ------------------------------
# The firmware goes on starting the bootloader it started before, so a host
# switched to the other one would never see a new generation in its menu.
r="$(new_repo f)"; m="$WORK/machine-f"; new_machine "$m" AuthenticAMD 0x10de
hardware_config "$m/etc/hardware-configuration.nix" /boot
echo '{ system.stateVersion = "26.05"; }' > "$m/etc/configuration.nix"
booted_by_grub "$m"
run_install "$m" "$r" --hostname dualboot --yes
check "F: installer succeeds" "$?" 0
f="$(facts "$r" dualboot)"
check "F: grub detected from how the machine booted" "$(get "$f" .bootloader)" grub
check "F: grub installed as an EFI program" "$(get "$f" .grubEfi)" true
check "F: other operating systems listed in the menu" "$(get "$f" .otherSystems)" true
check "F: boot menu kept short" "$(get "$f" .bootEntries)" 10
check "F: esp at /boot" "$(get "$f" .esp)" /boot
check "F: whole system evaluates" "$(get "$f" .buildable)" true
check "F: the first switch installs the bootloader" \
  "$(grep -c -- 'nixos-rebuild switch --install-bootloader' "$WORK/out.log")" 1

# GRUB enabled in the base configuration (written as an attribute set, with
# systemd-boot turned off beside it), on a machine whose command line does
# not say. Small ESP: the limit must land on GRUB's option, not systemd-boot's.
r="$(new_repo f2)"; m="$WORK/machine-f2"; new_machine "$m" AuthenticAMD 0x10de
hardware_config "$m/etc/hardware-configuration.nix" /boot
cat > "$m/etc/configuration.nix" <<'NIX'
{ config, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = true;
  };
  system.stateVersion = "26.05"; # Did you read the comment?
}
NIX
ESP_MB=511 run_install "$m" "$r" --hostname dualboot-2 --yes
f="$(facts "$r" dualboot-2)"
check "F: grub detected from the base configuration" "$(get "$f" .bootloader)" grub
check "F: small esp keeps fewer grub entries" "$(get "$f" .bootEntries)" 3
check "F: whole system evaluates with the lower limit" "$(get "$f" .buildable)" true

# GRUB switched off in the base configuration is not a GRUB machine.
r="$(new_repo f3)"; m="$WORK/machine-f3"; new_machine "$m" AuthenticAMD 0x10de
hardware_config "$m/etc/hardware-configuration.nix" /boot
cat > "$m/etc/configuration.nix" <<'NIX'
{ config, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.grub.enable = false;
  # boot.loader.grub.enable = true;
  system.stateVersion = "26.05";
}
NIX
run_install "$m" "$r" --hostname plain --yes
f="$(facts "$r" plain)"
check "F: grub switched off in the base config is not detected" "$(get "$f" .bootloader)" systemd-boot

# The choice can be made by flag, in either direction.
r="$(new_repo f4)"; booted_by_grub "$m"
run_install "$m" "$r" --hostname moved --bootloader systemd-boot --yes
f="$(facts "$r" moved)"
check "F: --bootloader systemd-boot overrides a grub machine" "$(get "$f" .bootloader)" systemd-boot
check "F: changing bootloader is called out" \
  "$(grep -c 'boots with grub today' "$WORK/out.log")" 1
r="$(new_repo f5)"; m="$WORK/machine-a"
run_install "$m" "$r" --hostname moved-2 --bootloader grub --yes
f="$(facts "$r" moved-2)"
check "F: --bootloader grub overrides a systemd-boot machine" "$(get "$f" .bootloader)" grub

# --- E: refusals leave the repository untouched ------------------------------
r="$(new_repo e)"
before="$(cd "$r" && find hosts -type f | sort | xargs sha256sum)"
for bad in nixos nixos-vm-x86 Bad_Name -dash "has space" ""; do
  run_install "$m" "$r" --hostname "$bad" --yes
  check "E: rejects hostname '$bad'" "$([ $? -ne 0 ] && echo refused)" refused
done
run_install "$m" "$r" --hostname nixos-amd64 --yes
check "E: will not overwrite an existing host unasked" "$([ $? -ne 0 ] && echo refused)" refused
run_install "$m" "$r" --hostname lilo-box --bootloader lilo --yes
check "E: rejects an unknown bootloader" "$([ $? -ne 0 ] && echo refused)" refused
ARCH=aarch64 run_install "$m" "$r" --hostname arm --yes
check "E: refuses a non-x86_64 machine" "$([ $? -ne 0 ] && echo refused)" refused
m2="$WORK/machine-bios"; new_machine "$m2" AuthenticAMD 0x10de; rmdir "$m2/sys/firmware/efi"
hardware_config "$m2/etc/hardware-configuration.nix" /boot
run_install "$m2" "$r" --hostname legacy --yes
check "E: refuses a machine not booted in UEFI mode" "$([ $? -ne 0 ] && echo refused)" refused
run_install "$m" "$r" --hostname nowhere --hardware-config "$WORK/does-not-exist.nix" --yes
check "E: refuses a missing hardware scan" "$([ $? -ne 0 ] && echo refused)" refused
after="$(cd "$r" && find hosts -type f | sort | xargs sha256sum)"
check "E: refused runs change nothing" "$after" "$before"

run_install "$m" "$r" --hostname nixos-amd64 --yes --force
check "E: --force replaces an existing host" "$?" 0
f="$(facts "$r" nixos-amd64)"
check "E: replaced host has the machine's disk" "$(get "$f" .root)" /dev/disk/by-uuid/11111111-aaaa-bbbb-cccc-222222222222

echo
if [ "$fails" -ne 0 ]; then
  echo "$fails checks failed. Last installer output:"; cat "$WORK/out.log"
  echo "Last evaluation output:"; tail -5 "$WORK/eval.log" 2>/dev/null
  exit 1
fi
echo "All checks passed."
