# System-side pieces for the mpe-transcribe voice-transcription app: what it
# needs to hear its hotkey and to paste under Wayland. The app itself is a
# user service, in home/martin/transcribe.nix, and these are the same
# whichever way round a machine runs it — as a client of the Mac (the
# Parallels guest) or doing its own recording and transcription (a machine
# with an NVIDIA card).
{ pkgs, ... }:

{
  # Clipboard get/set under Wayland (wl-copy / wl-paste).
  environment.systemPackages = with pkgs; [ wl-clipboard ];

  # ydotoold daemon + uinput setup; used to synthesise the Ctrl+V paste.
  programs.ydotool.enable = true;

  # Merges with the extraGroups list in users.nix.
  # input   → read /dev/input/event* (evdev hotkey listener)
  # ydotool → talk to the ydotoold socket
  users.users."martin".extraGroups = [ "input" "ydotool" ];
}
