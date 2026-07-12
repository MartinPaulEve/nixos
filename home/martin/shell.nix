# Interactive shell tooling, managed per-user by Home Manager.
{ ... }:

{
  # Starship prompt, with fish integration wired up automatically.
  programs.starship.enable = true;

  # Atuin shell history, with fish integration wired up automatically.
  programs.atuin.enable = true;
}
