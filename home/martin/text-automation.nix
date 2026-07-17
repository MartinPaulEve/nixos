# User-level text expansion via espanso (the Wayland-friendly AutoKey
# replacement). Symbol hotkeys (£, #) are handled separately by keyd at the
# system level; see modules/nixos/keyd.nix.
{ ... }:

{
  # espanso — AutoKey-style text expansion. The Home Manager module defaults to
  # the espanso-wayland package under Wayland, and runs it as a user service.
  services.espanso = {
    enable = true;

    matches.base.matches = [
      # Respect the diacritic in Siân's name without hunting for it each time.
      {
        trigger = "Sian";
        replace = "Siân";
        word = true; # only fire on whole-word "Sian", not inside other words
      }
      # Add further expansions here, e.g.:
      # { trigger = "teh"; replace = "the"; word = true; }
    ];
  };
}
