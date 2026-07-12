# Nix daemon settings and nixpkgs configuration.
{ ... }:

{
  # Enable flakes and the unified `nix` command.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages.
  nixpkgs.config.allowUnfree = true;
}
