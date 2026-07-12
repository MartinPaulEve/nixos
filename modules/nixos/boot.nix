# Bootloader, kernel, and disk decryption.
{ pkgs, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use the latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Unlock the encrypted root volume at boot.
  boot.initrd.luks.devices."luks-a1100a54-2434-4df7-814f-1c07900a6644".device =
    "/dev/disk/by-uuid/a1100a54-2434-4df7-814f-1c07900a6644";
}
