# Makes Moji (the Markdown viewer/editor built in modules/nixos/packages.nix)
# the default opener for Markdown files.
#
# ~/.config/mimeapps.list is deliberately NOT declared via xdg.mimeApps: that
# would turn the whole file into a read-only store symlink, but the file is
# live app-owned state — Thunderbird registers its generated
# userapp-Thunderbird-*.desktop mailto handlers there, and GNOME's
# "Open With → Always use" writes to it (the same class of problem
# bitwarden.nix documents). Instead, activation asserts just the markdown
# entries with xdg-mime, which edits the file in place and leaves every other
# association alone. Re-runs on every switch, so a GUI-made change to the
# markdown default lasts only until the next rebuild — that pinning is the
# point.
{ lib, pkgs, ... }:

{
  home.activation.mojiDefaultMarkdownHandler =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # XDG_CURRENT_DESKTOP=X-Generic forces xdg-mime's plain
      # write-to-mimeapps.list path; its GNOME path shells out to `gio mime`,
      # which refuses desktop IDs it cannot resolve, and mid-switch the app
      # database may not yet list moji.desktop.
      $DRY_RUN_CMD env XDG_CURRENT_DESKTOP=X-Generic \
        ${pkgs.xdg-utils}/bin/xdg-mime default moji.desktop \
        text/markdown text/x-markdown \
        || echo "Setting Moji as the markdown handler failed" >&2
    '';
}
