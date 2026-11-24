# System-wide key remapping via keyd. keyd works at the evdev/uinput level,
# below the display server, so it applies identically under X11 and Wayland
# (unlike AutoKey, which is X11-only).
#
# The chords are the same on every machine — Ctrl+Shift+3 for £ and Ctrl+4
# for # — but what keyd has to emit for them depends on the keyboard layout
# (desktop.nix), because keyd deals in keys, not characters. Rather than have
# keyd synthesise Unicode — which depends on a compose file and the input
# method honouring it — each chord is remapped onto the key combination the
# layout already has for that character. Pure keycode remapping, no compose
# needed.
#
#   gb(mac): the "3" key carries £ at Shift (level 2) and # at AltGr
#            (level 3), so the chords become Shift+3 and AltGr+3.
#   us:      # is Shift+3. There is no £ anywhere on this layout, so that
#            chord is left unmapped rather than sent somewhere wrong; with
#            the gb(mac) mapping it would type # and Ctrl+4 would arrive as
#            Alt+3.
#
# On a Mac keyboard "Ctrl" is the ⌃ Control key (keyd: control); ⌘ is meta and
# ⌥ is alt. keyd's G- prefix is AltGr (level-3 shift on gb(mac)).
{ config, lib, ... }:

let
  xkb = config.services.xserver.xkb;

  chords =
    if xkb.layout == "gb" && xkb.variant == "mac" then {
      # Ctrl+Shift+3 -> £  (emit Shift+3 = sterling on gb(mac)).
      "control+shift" = {
        "3" = "S-3";
      };

      # Ctrl+4 -> #  (emit AltGr+3 = numbersign on gb(mac)).
      "control" = {
        "4" = "G-3";
      };
    }
    else if xkb.layout == "us" then {
      # Ctrl+4 -> #  (emit Shift+3 = numbersign on us).
      "control" = {
        "4" = "S-3";
      };
    }
    # Any other layout: no chords, until someone works out its keys.
    else { };
in
{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ]; # apply to every attached keyboard
      settings = { main = { }; } // chords;
    };
  };
}
