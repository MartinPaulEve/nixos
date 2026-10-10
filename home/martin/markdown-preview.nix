# Markdown preview: inlyne (installed in modules/nixos/packages.nix) is the
# default opener for Markdown files and gets a declarative config.
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
  # Only the keys that differ from inlyne's defaults. The full list:
  # https://github.com/Inlyne-Project/inlyne/blob/main/inlyne.default.toml
  xdg.configFile."inlyne/inlyne.toml".text = ''
    # Follow the GNOME light/dark preference.
    theme = "Auto"
  '';

  home.activation.inlyneDefaultMarkdownHandler =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # XDG_CURRENT_DESKTOP=X-Generic forces xdg-mime's plain
      # write-to-mimeapps.list path; its GNOME path shells out to `gio mime`,
      # which refuses desktop IDs it cannot resolve, and mid-switch the app
      # database may not yet list inlyne.desktop.
      $DRY_RUN_CMD env XDG_CURRENT_DESKTOP=X-Generic \
        ${pkgs.xdg-utils}/bin/xdg-mime default inlyne.desktop \
        text/markdown text/x-markdown \
        || echo "Setting inlyne as the markdown handler failed" >&2
    '';
}
