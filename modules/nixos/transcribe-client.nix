# Runtime dependencies for the mpe-transcribe voice-transcription client
# (hotkey + paste in this VM; recording/transcription happen on the Mac
# host over encrypted UDP — see ~/src/mpe-transcribe/docs/NETWORK.md).
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
