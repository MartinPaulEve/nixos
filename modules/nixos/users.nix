# User accounts and the login shell.
{ lib, pkgs, ... }:

{
  # Fish, enabled system-wide so it is a registered login shell.
  programs.fish.enable = true;

  # NixOS defaults `ls` to an alias (`ls --color=tty`), which is applied at
  # interactive startup and shadows martin's autoloaded eza `ls` function.
  # Drop it so the function wins; `l`/`ll` are kept and route through it.
  environment.shellAliases.ls = lib.mkForce null;

  users.users."martin" = {
    isNormalUser = true;
    description = "Martin Paul Eve";
    extraGroups = [ "networkmanager" "wheel" "cdrom" "docker" ];
    shell = pkgs.fish;
    packages = with pkgs; [
      thunderbird
      python3
      gnomeExtensions.dash-to-dock
    ];
  };
}
