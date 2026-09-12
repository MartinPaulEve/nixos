# Autostart Bitwarden at login.
#
# The system module (modules/nixos/packages.nix) installs the app; this makes
# it start with the desktop session so its SSH agent socket at
# ~/.bitwarden-ssh-agent.sock is up for git commit signing (git.nix). Unlike
# 1Password there is no --silent flag (the app bundle handles none), so
# starting minimised relies on the in-app "Start to tray icon" setting.
#
# Two one-time, in-app steps are per-user state and cannot be declared here:
#   1. Settings → Enable SSH agent (off by default);
#   2. importing the signing key (id_ed25519_waldorf) into the vault.
#
# 1Password (onepassword.nix) still autostarts alongside: the sshfs mounts
# (mounts.nix) resolve their remotes with `op read` and authenticate against
# the 1Password agent, until those secrets and keys migrate to Bitwarden.
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
