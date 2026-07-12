# Unison file-synchroniser profile.
{ ... }:

{
  # Unison reads its profiles from ~/.unison/ (not an XDG path). The unison
  # package itself is installed at the system level. Only the profile is
  # managed declaratively — Unison's archive/state files (ar*, fp*, locks)
  # are created at runtime and must stay writable, so we place a single file
  # rather than symlinking the whole directory.
  home.file.".unison/default.prf".source = ./unison/default.prf;
}
