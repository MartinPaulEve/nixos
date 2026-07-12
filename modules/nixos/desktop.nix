# Graphical desktop: X11, GNOME, and the web browser.
{ ... }:

{
  # X11 windowing system.
  services.xserver.enable = true;

  # GNOME desktop, launched by the GDM display manager.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Keyboard layout in X11.
  services.xserver.xkb = {
    layout = "gb";
    variant = "mac";
  };

  # Firefox.
  programs.firefox.enable = true;
}
