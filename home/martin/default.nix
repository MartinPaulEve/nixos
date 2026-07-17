# Home Manager configuration for the "martin" user.
{ ... }:

{
  imports = [
    ./fish.nix
    ./git.nix
    ./gnome.nix
    ./shell.nix
    ./text-automation.nix
    ./unison.nix
    ./whipper.nix
  ];

  home.username = "martin";
  home.homeDirectory = "/home/martin";

  # The Home Manager release this configuration is written against.
  # See the Home Manager release notes before changing.
  home.stateVersion = "26.05";

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;
}
