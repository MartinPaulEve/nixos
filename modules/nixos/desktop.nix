# Graphical desktop: X11, GNOME, and the web browser.
{ config, lib, pkgs, ... }:

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

  # Keyboard layout: that of the keyboard in front of the machine. The
  # Parallels guest is typed on the Mac's own keyboard — British, in Apple's
  # arrangement, GNOME's "English (Macintosh)". The machines on real hardware
  # have a PC keyboard in the US arrangement, "English (US)".
  #
  # This is the one place the layout is chosen. The GNOME input source
  # (home/martin/gnome.nix), the console keymap (localization.nix) and the
  # keyd chords (keyd.nix) all read it from here, so a machine that differs —
  # an Apple keyboard on real hardware, say — sets services.xserver.xkb in
  # its own hosts/<name>/default.nix and the rest follows.
  services.xserver.xkb =
    if config.hardware.parallels.enable
    then { layout = lib.mkDefault "gb"; variant = lib.mkDefault "mac"; }
    else { layout = lib.mkDefault "us"; variant = lib.mkDefault ""; };

  # Firefox: the principal browser, and the default (home/martin/browser.nix).
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
