# Host "nixos": the aarch64 Parallels guest on the Mac. Ties the hardware scan
# together with the shared modules. Its bare-metal sibling is ../nixos-amd64.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos
    ../../home
  ];

  # Host identity.
  networking.hostName = "nixos";

  # Early KMS on the guest's paravirtualised GPU, so the Plymouth splash is
  # drawn on the real framebuffer from the start (see modules/nixos/boot.nix).
  boot.initrd.kernelModules = [ "virtio_gpu" ];

  # The NixOS release this system was first installed with.
  # See `man configuration.nix` before changing.
  system.stateVersion = "26.05";
}
