# User accounts and the login shell.
{ lib, pkgs, ... }:

{
  # Fish, enabled system-wide so it is a registered login shell.
  programs.fish.enable = true;

  # NixOS defaults `ls` to an alias (`ls --color=tty`), which is applied at
  # interactive startup and shadows martin's autoloaded eza `ls` function.
  # Drop it so the function wins; `l`/`ll` are kept and route through it.
  environment.shellAliases.ls = lib.mkForce null;

  # Repo helper scripts (see scripts/README.md) on PATH for every shell:
  # /etc/profile picks this up for bash, and the NixOS fish module translates
  # it into /etc/fish/config.fish via babelfish.
  environment.shellInit = ''
    export PATH="$PATH:/home/martin/nixos/scripts"
  '';

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
      gnomeExtensions.appindicator # tray icons (Bitwarden etc.); see gnome.nix
    ];
  };

  # Profile picture. AccountsService — which GNOME and GDM read — serves the user
  # icon from /var/lib/AccountsService/icons/<user>, so link that at the image
  # tracked in this repo. Home Manager installs the same file as ~/.face; see
  # home/martin/avatar.nix.
  #
  # The icon file alone is not enough for the GDM login screen. GDM reads avatars
  # over D-Bus from AccountsService, which only reports an icon it has recorded in
  # the per-user state file /var/lib/AccountsService/users/<user> as an `Icon=`
  # entry. Without that record the greeter falls back to ~/.face, which it cannot
  # read: it runs as the `gdm` user and the home directory is mode 0700. So write
  # the state file too, pointing at the icon above. `f+` recreates it on every
  # activation, which means this record is fully declarative — as with the icon,
  # changing the avatar in GNOME Settings will not stick; replace
  # home/martin/avatar.jpg and rebuild instead.
  systemd.tmpfiles.rules = [
    "L+ /var/lib/AccountsService/icons/martin - - - - ${../../home/martin/avatar.jpg}"
    "f+ /var/lib/AccountsService/users/martin 0600 root root - [User]\\nIcon=/var/lib/AccountsService/icons/martin\\n"
  ];
}
