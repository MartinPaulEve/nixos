# User accounts and the login shell.
{ pkgs, ... }:

{
  # Fish, enabled system-wide so it is a registered login shell.
  programs.fish.enable = true;

  users.users."martin" = {
    isNormalUser = true;
    description = "Martin Paul Eve";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [
      thunderbird
      git
      python3
      gnomeExtensions.dash-to-dock
    ];
  };
}
