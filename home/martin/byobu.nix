# Byobu terminal multiplexer configuration.
#
# Byobu records its chosen backend in ~/.config/byobu/backend and re-sources
# that file *after* backend autodetection, so its contents win. A first run on
# a generation without tmux left an empty "BYOBU_BACKEND=" behind, which made
# every later launch fall through byobu's backend dispatch and exit silently
# with no output. Pinning the file declaratively fixes that and stops it
# regressing. (The byobu-select-backend tool can no longer rewrite the file;
# switch backend here instead.)
{ ... }:

{
  xdg.configFile."byobu/backend".text = "BYOBU_BACKEND=tmux\n";
}
