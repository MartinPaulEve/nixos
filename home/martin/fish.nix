# Fish shell, managed per-user by Home Manager.
{ lib, ... }:

let
  # Every *.fish file in ./functions is placed into fish's autoload
  # directory (~/.config/fish/functions), so each file defining a
  # function of the same name is loaded on demand, exactly as if it
  # lived in the fish config functions directory directly.
  functionsDir = ./functions;
  functionFiles = builtins.attrNames (builtins.readDir functionsDir);
in
{
  programs.fish = {
    enable = true;

    # Show system info on interactive shell start (from the previous config.fish).
    # The starship prompt and atuin history are wired in automatically by their
    # own Home Manager modules; see ./shell.nix.
    #
    # Launch byobu automatically for interactive shells, but context-aware:
    #
    #  - The first three guards keep this from recursing: byobu starts tmux,
    #    which spawns a fresh interactive fish with $TMUX set, so the nested
    #    shell skips the exec and just runs fastfetch. We also bail out when
    #    already inside byobu ($BYOBU_BACKEND) or when there is no controlling
    #    tty (e.g. scp/rsync, editor-embedded shells).
    #  - IDE-embedded terminals (JetBrains JediTerm sets $TERMINAL_EMULATOR)
    #    stay plain fish: the IDE opens the shell at the project root and
    #    manages its own tabs, and byobu's F-keys fight the IDE's.
    #  - A shell that starts at ~ is a normal terminal launch: run byobu as
    #    before.
    #  - A shell that starts anywhere else was opened *at* that directory
    #    (Files' "Open Terminal Here"). Attaching would discard the directory,
    #    and attaching after new-window would mirror the session across two
    #    terminals (shared focus, shrink-to-smallest), so instead hand off:
    #    create a window at $PWD in the running byobu session — new-window
    #    without -d also focuses it there — and close this popup terminal.
    #    The handoff must be exec'd, not run-then-`exit`: fish's `exit` during
    #    config sourcing only aborts the remaining startup files and still
    #    drops into the interactive prompt, leaving the popup open. exec'ing
    #    the (short-lived) tmux client makes it the terminal's child, so the
    #    window closes as soon as the new byobu window is created.
    #    With no byobu running yet, start one at that directory.
    interactiveShellInit = ''
      if status is-interactive
          and not set -q TMUX
          and not set -q BYOBU_BACKEND
          and not string match -q 'JetBrains*' -- "$TERMINAL_EMULATOR"
          and test -t 1
          if test "$PWD" = "$HOME"
              exec byobu
          else if byobu list-sessions >/dev/null 2>&1
              exec byobu new-window -c "$PWD"
          else
              exec byobu new-session -c "$PWD"
          end
      end

      fastfetch
    '';
  };

  # These paths were previously GNU Stow symlinks into ~/dotfiles. Home Manager's
  # backupFileExtension only rescues regular files, not foreign symlinks, so we
  # force-overwrite the stale stow links. The originals remain in ~/dotfiles.
  xdg.configFile = (lib.listToAttrs (map
    (file: {
      name = "fish/functions/${file}";
      value = {
        source = functionsDir + "/${file}";
        force = true;
      };
    })
    functionFiles)) // {
    "fish/config.fish".force = true;
  };
}
