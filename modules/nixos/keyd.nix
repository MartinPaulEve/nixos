# System-wide key remapping via keyd. keyd works at the evdev/uinput level,
# below the display server, so it applies identically under X11 and Wayland
# (unlike AutoKey, which is X11-only).
#
# The machine uses the gb(mac) XKB layout (see desktop.nix), on which the "3"
# key already carries £ at Shift (level 2) and # at AltGr (level 3). Rather than
# have keyd synthesise Unicode — which depends on a compose file and the input
# method honouring it — we remap the familiar chords onto the key combinations
# the layout already understands. Pure keycode remapping, no compose needed.
#
# On a Mac keyboard "Ctrl" is the ⌃ Control key (keyd: control); ⌘ is meta and
# ⌥ is alt. keyd's G- prefix is AltGr (level-3 shift on this layout).
{ ... }:

{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ]; # apply to every attached keyboard
      settings = {
        main = { };

        # Ctrl+Shift+3 -> £  (emit Shift+3 = sterling on gb(mac)).
        "control+shift" = {
          "3" = "S-3";
        };

        # Ctrl+4 -> #  (emit AltGr+3 = numbersign on gb(mac)).
        "control" = {
          "4" = "G-3";
        };
      };
    };
  };
}
