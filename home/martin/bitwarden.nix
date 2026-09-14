# Autostart Bitwarden at login.
#
# The system module (modules/nixos/packages.nix) installs the app; this makes
# it start with the desktop session so its SSH agent socket at
# ~/.bitwarden-ssh-agent.sock is up for git commit signing (git.nix) and the
# sshfs mounts (mounts.nix). Unlike 1Password there is no --silent flag (the
# app bundle handles none), so starting minimised relies on the in-app
# "Start to tray icon" setting.
#
# Some one-time steps are per-user state and cannot be declared here:
#   1. Settings → Enable SSH agent (off by default);
#   2. importing the SSH keys into the vault (the signing key
#      id_ed25519_waldorf plus the keys the sshfs mounts authenticate with);
#   3. Secure Notes named sshmount-<name> whose body is each bw:// mount's
#      host:path (see mounts.nix);
#   4. a one-time `bw login`, so the CLI that sshmount resolves those notes
#      with can unlock the vault (plus `bw sync` whenever a note changes).
{ ... }:

{
  xdg.configFile."autostart/bitwarden.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Bitwarden
    Comment=Password manager and SSH agent
    Exec=bitwarden
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';
}
