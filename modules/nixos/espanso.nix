# System-side prerequisites for espanso's Wayland EVDEV backend. The
# espanso app/config itself is still imperative (stowed dotfiles + a
# hand-registered user unit); this only grants the device access it
# needs: reading keyboards (input group, set in transcribe-client.nix)
# and injecting expansions via /dev/uinput (uinput group, here).
# Without the uinput half, espanso crash-loops flashing its
# layout-detection window every RestartSec.
{ ... }:

{
  # Loads the uinput module and makes /dev/uinput 0660 root:uinput.
  hardware.uinput.enable = true;

  # Merges with the extraGroups lists in users.nix and transcribe-client.nix.
  users.users."martin".extraGroups = [ "uinput" ];
}
