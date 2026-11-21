# Bootloader, kernel, and disk decryption.
{ lib, pkgs, ... }:

let
  # Vendored "nixos-mac-style" Plymouth theme (macOS-style boot animation with
  # a NixOS logo). Sourced from https://www.gnome-look.org/p/2106821 and kept in
  # the repo since the upstream download link is a short-lived signed URL.
  # The theme uses Plymouth's built-in two-step module; we only need to rewrite
  # its hardcoded /usr/share ImageDir to the actual store path.
  nixos-mac-style = pkgs.runCommandLocal "plymouth-nixos-mac-style" { } ''
    dir=$out/share/plymouth/themes/nixos-mac-style
    mkdir -p "$dir"
    cp -r ${./plymouth-themes/nixos-mac-style}/. "$dir/"
    chmod -R u+w "$dir"
    substituteInPlace "$dir/nixos-mac-style.plymouth" \
      --replace-fail /usr/share/plymouth/themes/nixos-mac-style "$dir"
  '';
in
{
  # Bootloader: systemd-boot, unless the host opts into GRUB by importing
  # modules/hardware/grub.nix (a machine that shares its disks with other
  # operating systems). Whichever it is must be the one the firmware actually
  # starts: a rebuild only writes new generations into the menu of the
  # bootloader configured here, so a mismatch boots the old system forever.
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  # Keep the boot menu short; older generations stay in the store (and are
  # rolled back to with nixos-rebuild) until nix.gc removes them (nix.nix).
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use the latest kernel.
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  # Graphical boot splash (also themes the LUKS unlock prompt).
  boot.plymouth = {
    enable = true;
    theme = "nixos-mac-style";
    themePackages = [ nixos-mac-style ];
  };

  # For the splash to show, the real KMS driver has to come up in the initrd,
  # before Plymouth starts drawing. Otherwise Plymouth renders on the EFI
  # simple-framebuffer (simpledrm), the GPU driver only loads ~5s into stage-2
  # boot, and the mid-boot framebuffer handoff hides the splash. Which driver
  # that is depends on the machine, so it is set per host: virtio_gpu for the
  # Parallels guest (hosts/nixos) and the QEMU test VM (vm.nix), amdgpu for
  # the bare-metal AMD machine (hosts/nixos-amd64).

  # Quiet the console so Plymouth shows a clean splash instead of kernel logs.
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [ "quiet" "splash" "rd.udev.log_level=3" "udev.log_level=3" ];
}
