# espanso, the text expander: the app, its user service, and the device
# access its Wayland backend needs.
#
# Under Wayland espanso cannot ask the compositor for keystrokes, so it works
# at the kernel input layer instead (the EVDEV backend): it reads the
# keyboards from /dev/input and types expansions back through /dev/uinput.
# That takes three things, all set up here:
#
#   - the Wayland build (pkgs.espanso-wayland; the default build is X11-only
#     and sees nothing in a Wayland session);
#   - a capability wrapper: services.espanso installs the binary with
#     CAP_DAC_OVERRIDE in /run/wrappers/bin and runs the service from there,
#     which is what lets it open the input devices;
#   - /dev/uinput itself, plus the input group (from transcribe.nix) and the
#     uinput group. Without the uinput half espanso crash-loops, flashing
#     its layout-detection window at every restart.
#
# The service is a systemd user unit tied to the graphical session, so it
# starts at login on every host. It used to be a hand-registered unit
# pointing at a bare store path, which existed only on the machine it was
# typed into (and would not have survived a garbage collection there). A
# leftover ~/.config/systemd/user/espanso.service from those days still
# takes precedence over this one; delete it to switch that machine over.
#
# What stays out of the repo is the configuration: ~/.config/espanso
# (match/*.yml for the snippets, config/default.yml for options). espanso
# writes its stock templates there on first start and reloads on save.
{ pkgs, ... }:

{
  services.espanso = {
    enable = true;
    package = pkgs.espanso-wayland;
  };

  # Loads the uinput module and makes /dev/uinput 0660 root:uinput.
  hardware.uinput.enable = true;

  # Merges with the extraGroups lists in users.nix and transcribe.nix.
  users.users."martin".extraGroups = [ "uinput" ];
}
