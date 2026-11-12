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
{ ... }:

let
  plainClass = "com.mitchellh.ghostty.plain";
in
{
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;

    settings = {
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
