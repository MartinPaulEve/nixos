# User profile picture.
#
# ./avatar.jpg is a 512x512 square crop of the original photo, framed so that
# both the face and the owl's head sit inside the circular mask GNOME applies to
# user icons.
#
# `~/.face` is the per-user avatar AccountsService falls back to when no icon has
# been set over D-Bus. The system side additionally links
# /var/lib/AccountsService/icons/martin at the same image, which is where
# GNOME/GDM normally read it from — see modules/nixos/users.nix.
{ ... }:

{
  home.file.".face".source = ./avatar.jpg;
}
