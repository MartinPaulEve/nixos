# animal: a bare-metal machine — AMD processor, NVIDIA graphics card, GRUB
# bootloader.
#
# Written by scripts/install.sh from this machine's own answers; edit it
# freely afterwards. A host directory holds only what is particular to one
# machine. The shared system modules, the Home Manager configuration and the
# hostname — which is this directory's name — are all supplied by flake.nix,
# so every host gets the same packages and home directory.
{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/amd.nix
    ../../modules/hardware/nvidia.nix
    # This machine also carries Windows and Ubuntu, and its firmware starts
    # GRUB, whose menu lists them; see modules/hardware/grub.nix.
    ../../modules/hardware/grub.nix
  ];

  # NVIDIA's open kernel module (required for the RTX 50 series) instead of
  # the proprietary one; see modules/hardware/nvidia.nix.
  hardware.nvidia.open = true;

  # The NixOS release this system was first installed with.
  # See `man configuration.nix` before changing.
  system.stateVersion = "26.05";
}
