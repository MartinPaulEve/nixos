# Graphical desktop: X11, GNOME, and the web browser.
{ pkgs, ... }:

{
  # X11 windowing system.
  services.xserver.enable = true;

  # GNOME desktop, launched by the GDM display manager.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # GNOME Tweaks
  environment.systemPackages = [
    pkgs.gnome-tweaks
  ];

  # Keyboard layout in X11.
  services.xserver.xkb = {
    layout = "gb";
    variant = "mac";
  };

  # Firefox.
  programs.firefox.enable = true;

  # Default terminal for "Open in Terminal" and for Terminal=true desktop
  # entries (the xdg-terminal-exec spec, which GLib consults). GNOME ships
  # Console and would otherwise prefer it; ghostty itself is installed per
  # user in home/martin/ghostty.nix.
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "com.mitchellh.ghostty.desktop" ];
  };
}
