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

    # Public keys accepted for SSH login. security.nix disables password and
    # keyboard-interactive auth, so a key listed here is the only way in.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKjbi7dBrGRlTGDhWb5cPshqCdNkIos+Z5wwM6ijIXN martin@eve.gd"
    ];

    packages = with pkgs; [
      thunderbird
      python3
      gnomeExtensions.dash-to-dock
    ];
  };

  # Profile picture. AccountsService — which GNOME and GDM read — serves the user
  # icon from /var/lib/AccountsService/icons/<user>, so link that at the image
  # tracked in this repo. Home Manager installs the same file as ~/.face, which is
  # AccountsService's per-user fallback; see home/martin/avatar.nix. Because this
  # is a store symlink, changing the avatar in GNOME Settings will not stick —
  # replace home/martin/avatar.jpg and rebuild instead.
  systemd.tmpfiles.rules = [
    "L+ /var/lib/AccountsService/icons/martin - - - - ${../../home/martin/avatar.jpg}"
  ];
}
