# Remmina: keep its tray applet from launching itself at login.
#
# The remmina package ships no autostart entry. The app itself creates
# ~/.config/autostart/remmina-applet.desktop with Hidden=false (autostart ON)
# on any launch where the file is missing and the tray icon is enabled, and
# its Preferences → Applet toggle rewrites the file in place
# (remmina_icon_create_autostart_file / remmina_icon_save_autostart_file in
# src/remmina_icon.c). Declaring the entry with Hidden=true pins autostart
# off.
#
# Unlike Bitwarden (see bitwarden.nix), a store symlink here is harmless:
# Remmina skips creation when the file exists, and the pref-toggle write goes
# through g_file_set_contents, which atomically replaces the symlink with a
# plain file rather than crashing the app — the next Home Manager switch just
# re-pins it. force = true because the path currently holds the file Remmina
# wrote itself.
{ ... }:

{
  xdg.configFile."autostart/remmina-applet.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Version=1.0
      Name=Remmina Applet
      Comment=Connect to remote desktops through the applet menu
      Icon=org.remmina.Remmina
      Exec=remmina -i
      Terminal=false
      Type=Application
      Hidden=true
    '';
  };
}
