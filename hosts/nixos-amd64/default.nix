# A bare-metal machine: AMD processor, NVIDIA graphics card.
#
# A host directory holds only what is particular to one machine. The shared
# system modules, the Home Manager configuration and the hostname — which is
# this directory's name — are all supplied by flake.nix, so every host gets
# the same packages and home directory.
#
# To add another machine, copy this directory under a new name; see AMD64.md.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/amd.nix
    ../../modules/hardware/nvidia.nix
  ];

  # The NixOS release this system was first installed with.
  # See `man configuration.nix` before changing.
  system.stateVersion = "26.05";
}
