# Firefox as the default web browser, on every host.
#
# Firefox (enabled in modules/nixos/desktop.nix) is the principal browser;
# Chromium (modules/nixos/packages.nix) is installed alongside it as the
# backup and is never the default. Until now that was only live per-user
# state — whichever browser last asked "make me the default?" and was told
# yes — so a freshly installed machine had no default at all and GNOME fell
# back to whichever browser it found first.
#
# Same mechanism as ./sublime-default.nix and ./markdown-preview.nix, for the
# same reason: ~/.config/mimeapps.list is live app-owned state, so it is
# edited in place with xdg-mime rather than declared via xdg.mimeApps. Re-runs
# on every switch, so accepting Chromium's "set as default" prompt lasts only
# until the next rebuild — that pinning is the point.
#
# The types are the ones a browser is the default *for*: links clicked in
# other apps (the http/https schemes) and HTML documents opened from Files.
{ lib, pkgs, ... }:

{
  home.activation.firefoxDefaultBrowser =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # XDG_CURRENT_DESKTOP=X-Generic forces xdg-mime's plain
      # write-to-mimeapps.list path (see ./markdown-preview.nix).
      $DRY_RUN_CMD env XDG_CURRENT_DESKTOP=X-Generic \
        ${pkgs.xdg-utils}/bin/xdg-mime default firefox.desktop \
        x-scheme-handler/http x-scheme-handler/https \
        text/html application/xhtml+xml \
        || echo "Setting Firefox as the default browser failed" >&2
    '';
}
