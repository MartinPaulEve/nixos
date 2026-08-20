# Interactive shell tooling, managed per-user by Home Manager.
{ ... }:

{
  # Starship prompt, with fish integration wired up automatically.
  programs.starship.enable = true;

  # Minimal starship profile used on the sshfs mounts. The full prompt
  # detects git repos and languages by scanning the cwd and running
  # commands like `git status` — over sshfs that is heavy remote IO which
  # starship kills at command_timeout and reruns at every prompt,
  # producing the "command timed out" warnings and a stream of traffic
  # that competes with real use of the mount. This profile runs no
  # commands and scans nothing.
  xdg.configFile."starship-remote.toml".text = ''
    format = "$directory$character"
  '';

  # Swap the profile in whenever the working directory is on one of the
  # sshfs mounts (see mounts.nix); the full prompt returns on leaving.
  programs.fish.interactiveShellInit = ''
    function __starship_remote_profile --on-variable PWD
      if string match -q -- "$HOME/mounts*" $PWD
        set -gx STARSHIP_CONFIG $HOME/.config/starship-remote.toml
      else
        set -e STARSHIP_CONFIG
      end
    end
    __starship_remote_profile
  '';

  # Atuin shell history, with fish integration wired up automatically.
  programs.atuin.enable = true;
}
