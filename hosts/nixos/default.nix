# The aarch64 Parallels guest on the Mac.
#
# A host directory holds only what is particular to one machine. The shared
# system modules, the Home Manager configuration and the hostname — which is
# this directory's name — are all supplied by flake.nix.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Early KMS on the guest's paravirtualised GPU, so the Plymouth splash is
  # drawn on the real framebuffer from the start (see modules/nixos/boot.nix).
  boot.initrd.kernelModules = [ "virtio_gpu" ];

  # The NixOS release this system was first installed with.
  # See `man configuration.nix` before changing.
  system.stateVersion = "26.05";
}
