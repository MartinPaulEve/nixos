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

  # GPaste clipboard manager. The NixOS module installs the daemon, its D-Bus
  # activation file and systemd user unit, and adds the package to the GNOME
  # session path so GNOME Shell can find the bundled GPaste shell extension
  # (and so Settings → Keyboard does not crash on its GSettings schemas). The
  # extension still has to be switched on per user: see enabled-extensions in
  # home/martin/gnome.nix.
  programs.gpaste.enable = true;

  # Keyboard layout in X11.
  services.xserver.xkb = {
    layout = "gb";
    variant = "mac";
  };

  # Firefox.
  programs.firefox.enable = true;
}
