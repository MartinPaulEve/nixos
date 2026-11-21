# PLACEHOLDER — replace with the real hardware scan when installing.
#
# This file stands in for the output of `nixos-generate-config` until the
# flake is installed on the actual machine, so the host evaluates (and can be
# checked from the Parallels guest) before the hardware exists. During the
# install, overwrite it with the generated file:
#
#   nixos-generate-config --root /mnt --show-hardware-config \
#     > hosts/nixos-amd64/hardware-configuration.nix
#
# That brings in this machine's real disk UUIDs, any LUKS device, swap, and
# the exact initrd storage modules. Full procedure in AMD64.md.
#
# As written it is still bootable, provided the disk is partitioned with the
# filesystem labels below (the ones the NixOS manual uses):
#
#   mkfs.fat -F 32 -n boot /dev/<esp>      # EFI system partition
#   mkfs.ext4 -L nixos /dev/<root>         # root filesystem
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Storage and input drivers the initrd may need to find the root disk and
  # take a passphrase: NVMe and SATA disks, USB keyboards and USB storage.
  boot.initrd.availableKernelModules =
    [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # No swap is declared here: a swap device that does not exist stalls boot
  # for 90 seconds. The generated file adds the real one if you create it.
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
