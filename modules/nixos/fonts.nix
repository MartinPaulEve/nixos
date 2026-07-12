# Fonts, including Nerd Fonts for terminal/prompt icons.
{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    # Symbols-only provides just the Nerd Font glyphs and acts as a fontconfig
    # fallback, so eza/starship icons render even without changing the terminal
    # font. The full families below can be selected as the monospace font if
    # ligatures/complete glyph coverage are wanted.
    nerd-fonts.symbols-only
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];
}
