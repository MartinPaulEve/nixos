# Ghostty terminal emulator.
#
# Ghostty replaces GNOME Console as the day-to-day terminal: Console (VTE)
# drops a mouse selection as soon as the view scrolls, which makes copying
# anything longer than a screen a lottery. Ghostty keeps the selection while
# scrolling and has a large, configurable scrollback.
#
# Two desktop entries are installed:
#
#  - "Ghostty" (upstream entry): the default. The shell runs the byobu
#    handoff in fish.nix, so every window lands in byobu as before.
#  - "Ghostty (no byobu)": the escape hatch. It launches with NOBYOBU=1, which
#    fish.nix honours by starting a plain shell. That gives ghostty's own
#    scrollback and selection, with no tmux alternate screen in the way.
#    It runs under its own --class so it is a separate single-instance
#    process from the byobu one (otherwise the running instance would just
#    open a new window with *its* environment and NOBYOBU would be lost) and
#    so GNOME gives it its own dock icon. The entry's file name must equal the
#    class for that matching to work. The nobyobu fish function opens the
#    same thing from inside a byobu session.
#
# Graphics: ghostty 1.2+ needs OpenGL 4.3, but the Parallels guest's GPU is
# virtio-gpu through Mesa's virgl driver, which stops at OpenGL 4.0 (it lacks
# shader storage buffers and compute shaders, so faking the version with
# MESA_GL_VERSION_OVERRIDE would not help). Mesa's llvmpipe software renderer
# does OpenGL 4.6, so on that host the package below wraps ghostty to run
# under LIBGL_ALWAYS_SOFTWARE=1. The wrapper has to be reached by every launch
# path, not just the shell: the upstream desktop entry is DBusActivatable and
# the single-instance process is started from a D-Bus service file and a
# systemd user unit, all of which carry absolute store paths to the real
# binary, so those files are rewritten to point at the wrapper. The `env`
# setting then clears the variable again for the shells ghostty spawns, so
# GL programs started from a terminal still get the hardware driver.
#
# The wrapper is gated on hardware.parallels.enable (read from the NixOS
# config via osConfig), so it is inert in the x86 QEMU test VM and on any
# future bare-metal install: there ghostty is the stock package and renders
# on the real GPU driver.
{ lib, pkgs, osConfig, ... }:

let
  plainClass = "com.mitchellh.ghostty.plain";

  softwareGL = osConfig.hardware.parallels.enable;

  ghosttySoftwareGL = pkgs.symlinkJoin {
    name = "ghostty-softgl-${pkgs.ghostty.version}";
    paths = [ pkgs.ghostty ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/ghostty"
      makeWrapper "${lib.getExe pkgs.ghostty}" "$out/bin/ghostty" \
        --set LIBGL_ALWAYS_SOFTWARE 1

      for f in share/applications/com.mitchellh.ghostty.desktop \
               share/kio/servicemenus/com.mitchellh.ghostty.desktop \
               share/dbus-1/services/com.mitchellh.ghostty.service \
               share/systemd/user/app-com.mitchellh.ghostty.service; do
        rm "$out/$f"
        sed "s|${pkgs.ghostty}/bin/ghostty|$out/bin/ghostty|g" \
          "${pkgs.ghostty}/$f" > "$out/$f"
      done
    '';
    # Keep what the Home Manager module reads off the package.
    inherit (pkgs.ghostty) meta;
    passthru = { inherit (pkgs.ghostty) vim; };
  };
in
{
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    package = if softwareGL then ghosttySoftwareGL else pkgs.ghostty;

    settings = lib.optionalAttrs softwareGL {
      # Undo the wrapper's LIBGL_ALWAYS_SOFTWARE for child processes (see the
      # header comment). Mesa reads "0" as off; an unset variable is not
      # expressible here.
      env = "LIBGL_ALWAYS_SOFTWARE=0";
    } // {
      # Same face as the rest of the desktop (monospace-font-name in gnome.nix).
      font-family = "CaskaydiaCove Nerd Font Mono";
      font-size = 11;

      # Scrollback is per surface and allocated lazily, so a big ceiling costs
      # nothing until it is used. 100 MB is ten times the default and is
      # roughly a million lines of ordinary output.
      scrollback-limit = 100000000;

      # Selection goes to the primary selection (middle-click) *and* the
      # system clipboard, so a drag-select is enough to Ctrl+V elsewhere.
      copy-on-select = "clipboard";

      # When ssh-ing somewhere without ghostty's terminfo, present as
      # xterm-256color rather than leaving the remote with an unknown TERM.
      shell-integration-features = "ssh-env";

      # Closing a window with a live byobu client always asks; that is just
      # a detached session, so skip the prompt.
      confirm-close-surface = false;

      # The theme for the terminal
      theme = "Apple System Colors Light";
    };
  };

  xdg.desktopEntries.${plainClass} = {
    name = "Ghostty (no byobu)";
    genericName = "Terminal";
    comment = "A terminal emulator, started without byobu";
    exec = "env NOBYOBU=1 ghostty --class=${plainClass}";
    icon = "com.mitchellh.ghostty";
    terminal = false;
    categories = [ "System" "TerminalEmulator" ];
    settings = {
      Keywords = "terminal;tty;pty;plain;scrollback;";
      StartupWMClass = plainClass;
    };
  };
}
