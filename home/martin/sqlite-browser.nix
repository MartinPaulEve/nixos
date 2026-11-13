# SQLite file browsing: DB Browser for SQLite (sqlitebrowser, installed in
# modules/nixos/packages.nix) is the default opener for SQLite database files,
# so a double-click on a .sqlite/.db/.sqlite3 file in Files lands straight in
# its table/data view.
#
# A default has to be pinned explicitly: nothing in a stock GNOME install
# claims the SQLite MIME types, so Files either shows the "Open With" picker
# every time or, once a choice is made in the GUI, keeps it only as live
# per-user state. As in markdown-preview.nix, ~/.config/mimeapps.list is
# deliberately NOT declared via xdg.mimeApps (that would make the whole file a
# read-only store symlink and break the apps that write to it); activation
# asserts just the SQLite entries with xdg-mime and leaves the rest alone.
#
# The MIME list is the SQLite subset of sqlitebrowser.desktop's MimeType line.
# text/csv is listed there too but is left out on purpose: spreadsheets should
# keep opening CSV files.
{ lib, pkgs, ... }:

{
  home.activation.sqlitebrowserDefaultHandler =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # XDG_CURRENT_DESKTOP=X-Generic forces xdg-mime's plain
      # write-to-mimeapps.list path; see markdown-preview.nix for why.
      $DRY_RUN_CMD env XDG_CURRENT_DESKTOP=X-Generic \
        ${pkgs.xdg-utils}/bin/xdg-mime default sqlitebrowser.desktop \
        application/vnd.sqlite3 application/x-sqlite3 application/x-sqlite2 \
        application/geopackage+sqlite3 application/vnd.db4s-project+xml \
        || echo "Setting sqlitebrowser as the SQLite handler failed" >&2
    '';
}
