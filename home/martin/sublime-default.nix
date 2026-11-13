# Sublime Text as the default text-file opener, in place of GNOME Text Editor.
#
# GNOME Text Editor registers only two MIME types (see MimeType= in
# org.gnome.TextEditor.desktop): text/plain and application/x-zerosize (empty
# files). It still ends up as the default for every source and config file
# because the shared MIME database derives all text/* types — and text-like
# application types such as application/json, application/yaml and
# application/toml — from text/plain, and GIO resolves a default through that
# parent chain. So pinning just these two types to Sublime moves every file
# that would have opened in Text Editor over to Sublime, while types with
# their own default (Markdown → inlyne in ./markdown-preview.nix, CSV →
# LibreOffice Calc, HTML → Firefox, vCard → Thunderbird) are untouched, exactly
# as they would be for Text Editor. Keep the list equal to Text Editor's own.
#
# Same mechanism as ./markdown-preview.nix, for the same reason: the file is
# live app-owned state, so it is edited in place with xdg-mime rather than
# declared via xdg.mimeApps. Re-runs on every switch, so a GUI-made change to
# the text default lasts only until the next rebuild.
{ lib, pkgs, ... }:

{
  home.activation.sublimeDefaultTextHandler =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # XDG_CURRENT_DESKTOP=X-Generic forces xdg-mime's plain
      # write-to-mimeapps.list path (see ./markdown-preview.nix).
      $DRY_RUN_CMD env XDG_CURRENT_DESKTOP=X-Generic \
        ${pkgs.xdg-utils}/bin/xdg-mime default sublime_text.desktop \
        text/plain application/x-zerosize \
        || echo "Setting Sublime Text as the text handler failed" >&2
    '';
}
