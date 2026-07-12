# Aggregate all system-level modules.
{ ... }:

{
  imports = [
    ./audio.nix
    ./boot.nix
    ./desktop.nix
    ./localization.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./printing.nix
    ./security.nix
    ./users.nix
  ];
}
