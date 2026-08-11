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
    # Launch byobu automatically for interactive shells. The guards keep this from
    # recursing: byobu starts tmux, which spawns a fresh interactive fish with
    # $TMUX set, so the nested shell skips the exec and just runs fastfetch. We
    # also bail out when already inside byobu ($BYOBU_BACKEND) or when there is no
    # controlling tty (e.g. scp/rsync, editor-embedded shells) to avoid hijacking
    # non-visual sessions.
    interactiveShellInit = ''
      if status is-interactive
          and not set -q TMUX
          and not set -q BYOBU_BACKEND
          and test -t 1
          exec byobu
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
