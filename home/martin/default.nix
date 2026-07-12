# Home Manager configuration for the "martin" user.
{ ... }:

{
  imports = [
    ./fish.nix
    ./git.nix
    ./shell.nix
  ];

  home.username = "martin";
  home.homeDirectory = "/home/martin";

  # The Home Manager release this configuration is written against.
  # See the Home Manager release notes before changing.
  home.stateVersion = "26.05";

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;
}
