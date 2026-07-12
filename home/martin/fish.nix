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
  programs.fish.enable = true;

  xdg.configFile = lib.listToAttrs (map
    (file: {
      name = "fish/functions/${file}";
      value.source = functionsDir + "/${file}";
    })
    functionFiles);
}
