# Nix daemon settings and nixpkgs configuration.
{ ... }:

{
  # Enable flakes and the unified `nix` command.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages.
  nixpkgs.config.allowUnfree = true;

  # Housekeeping. Every rebuild keeps the previous generation (and its whole
  # closure) around as a rollback target; without pruning, the store only ever
  # grows. Weekly, drop generations older than two weeks and collect garbage,
  # then hard-link identical files across the store. Two weeks is still plenty
  # of rollback headroom at a weekly update cadence (scripts/update.sh).
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
}
