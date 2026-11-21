# Machine profile: boot with GRUB instead of systemd-boot.
#
# Opt-in — imported by the hosts that need it (hosts/<name>/default.nix). It
# is for a machine that shares its disks with other operating systems: GRUB's
# menu lists those too, where systemd-boot only offers NixOS (and a Windows
# that lives on the same EFI partition).
#
# A host must use the bootloader its firmware actually starts. A rebuild
# writes new generations only into the menu of the bootloader configured
# here; if the firmware starts the other one, every reboot lands in the last
# generation that one was told about. scripts/install.sh picks this profile
# for a machine that already boots with GRUB, and its first switch runs with
# --install-bootloader so the firmware's first boot entry matches.
{ lib, ... }:

{
  # Replaces the shared default (modules/nixos/boot.nix).
  boot.loader.systemd-boot.enable = false;

  boot.loader.grub = {
    enable = true;

    # UEFI: install GRUB as an EFI program on the EFI system partition
    # (boot.loader.efi.efiSysMountPoint) rather than into a disk's boot
    # sector, which is what "nodev" says. With canTouchEfiVariables (boot.nix)
    # it registers itself with the firmware as "NixOS-boot".
    efiSupport = true;
    device = "nodev";

    # Scan the other disks on every rebuild and add what is found (Windows,
    # other Linux installs) to the menu, below the NixOS entries.
    useOSProber = true;

    # Keep the boot menu short, as boot.nix does for systemd-boot (GRUB's own
    # default is 100). Each entry also keeps a kernel and an initrd on the
    # EFI partition, and the NVIDIA driver makes the initrd large.
    configurationLimit = lib.mkDefault 10;
  };
}
