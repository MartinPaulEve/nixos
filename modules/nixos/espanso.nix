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
# (match/*.yml for the snippets, config/default.yml for options), which
# espanso reloads on save.
#
# espanso 2.3.0 does not write that configuration itself, whatever its
# documentation says of a first start. On a machine that has never had one,
# the daemon makes ~/.config/espanso/match/packages, then fails with "missing
# config directory" and puts up a troubleshooting window that cannot be
# closed, since the unit restarts it as fast as it is dismissed. So the unit
# first seeds a starter configuration — only when there is no config/
# directory at all, and never over a file that is already there.
#
# The unit is also limited to users in the uinput group, which is to say
# martin. A unit under /etc/systemd/user belongs to every user's session,
# the login screen's included: there espanso ran as GDM's greeter user,
# reading the keyboard under the password prompt (the capability wrapper
# opens the input devices for anybody), and crashed for want of a
# configuration it must not be given.
{ pkgs, ... }:

let
  defaultYml = pkgs.writeText "espanso-default.yml" ''
    # espanso options. Every setting here is optional; see
    # https://espanso.org/docs/configuration/options/
    #
    # Snippets live in ../match/*.yml. espanso reloads on save.
  '';

  baseYml = pkgs.writeText "espanso-base.yml" ''
    # espanso snippets. See https://espanso.org/docs/matches/basics/
    matches:
      # Type :espanso to check that expansion works.
      - trigger: ":espanso"
        replace: "Hi there!"

      # Today's date, e.g. 2026-11-23.
      - trigger: ":date"
        replace: "{{mydate}}"
        vars:
          - name: mydate
            type: date
            params:
              format: "%Y-%m-%d"
  '';

  seedConfig = pkgs.writeShellScript "espanso-seed-config" ''
    cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/espanso"
    [ -d "$cfg/config" ] && exit 0
    ${pkgs.coreutils}/bin/install -Dm644 ${defaultYml} "$cfg/config/default.yml"
    [ -e "$cfg/match/base.yml" ] ||
      ${pkgs.coreutils}/bin/install -Dm644 ${baseYml} "$cfg/match/base.yml"
  '';
in
{
  services.espanso = {
    enable = true;
    package = pkgs.espanso-wayland;
  };

  # Added to the unit services.espanso declares; see the header.
  systemd.user.services.espanso = {
    unitConfig.ConditionGroup = "uinput";
    serviceConfig.ExecStartPre = "${seedConfig}";
  };

  # Loads the uinput module and makes /dev/uinput 0660 root:uinput.
  hardware.uinput.enable = true;

  # Merges with the extraGroups lists in users.nix and transcribe.nix.
  users.users."martin".extraGroups = [ "uinput" ];
}
