# Fonts, including Nerd Fonts for terminal/prompt icons.
{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    # Symbols-only provides just the Nerd Font glyphs and acts as a fontconfig
    # fallback, so eza/starship icons render even in fonts without them.
    nerd-fonts.symbols-only
    # CaskaydiaCove (Cascadia Code) is the terminal monospace font — see
    # the monospace-font-name in home/martin/gnome.nix.
    nerd-fonts.caskaydia-cove
  ];
}
