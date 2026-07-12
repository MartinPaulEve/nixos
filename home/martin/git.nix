# Git, managed per-user by Home Manager.
{ ... }:

{
  programs.git = {
    enable = true;
    settings.user = {
      name = "Martin Paul Eve";
      email = "martin@eve.gd";
    };
  };
}
