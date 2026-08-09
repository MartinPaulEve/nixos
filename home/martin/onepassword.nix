# Autostart 1Password at login.
#
# The system module (modules/nixos/security.nix) installs the app; this makes
# it start with the desktop session. 1Password's own "start at login"
# checkbox is supposed to write this autostart entry but does not persist on
# NixOS, so we manage it declaratively. Started with --silent so only the
# tray icon appears, keeping the SSH agent socket at ~/.1password/agent.sock
# available for anything that needs it (e.g. the waldorf sshfs mount).
{ ... }:

{
  xdg.configFile."autostart/1password.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=1Password
    Comment=Password manager and SSH agent
    Exec=1password --silent
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';
}
