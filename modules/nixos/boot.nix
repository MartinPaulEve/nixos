# Bootloader, kernel, and disk decryption.
{ pkgs, ... }:

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
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use the latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Graphical boot splash (also themes the LUKS unlock prompt).
  boot.plymouth = {
    enable = true;
    theme = "nixos-mac-style";
    themePackages = [ nixos-mac-style ];
  };

  # Load the real KMS driver in the initrd so early KMS brings up the virtio-gpu
  # framebuffer before Plymouth starts drawing. Without this, Plymouth renders on
  # the EFI simple-framebuffer (simpledrm) and virtio_gpu only loads ~5s into
  # stage-2 boot, and the mid-boot framebuffer handoff hides the splash.
  boot.initrd.kernelModules = [ "virtio_gpu" ];

  # Quiet the console so Plymouth shows a clean splash instead of kernel logs.
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [ "quiet" "splash" "rd.udev.log_level=3" "udev.log_level=3" ];
}
