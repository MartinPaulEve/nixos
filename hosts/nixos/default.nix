# Host "nixos": ties the hardware scan together with the shared modules.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos
    ../../home
  ];

  # Host identity.
  networking.hostName = "nixos";

  # The NixOS release this system was first installed with.
  # See `man configuration.nix` before changing.
  system.stateVersion = "26.05";
}
