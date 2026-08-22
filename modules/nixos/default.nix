# Aggregate all system-level modules.
{ ... }:

{
  imports = [
    ./audio.nix
    ./boot.nix
    ./desktop.nix
    ./email.nix
    ./fonts.nix
    ./keyd.nix
    ./localization.nix
    ./mounts.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./power.nix
    ./printing.nix
    ./security.nix
    ./shutdown.nix
    ./transcribe-client.nix
    ./users.nix
    ./virtualisation.nix
    ./vm.nix
  ];
}
