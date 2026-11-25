# Unison file-synchroniser profile.
{ config, lib, ... }:

let
  cfg = config.unisonProfile;
in
{
  # The folders to synchronise are the one part of the profile a machine may
  # choose for itself: a host sets
  # home-manager.users.martin.unisonProfile.paths in its own file (see
  # hosts/animal/default.nix) and everything else below stays shared.
  options.unisonProfile.paths = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "Documents/Work/Uni"
      "Documents/Work/Programming"
      "Documents/Work/Consulting"
      "Documents/Personal"
      "Documents/Programming"
    ];
    example = [ "Documents/Personal" ".config/fish" ];
    description = ''
      The folders Unison synchronises, relative to the home directory, in the
      order Unison takes them. Setting this replaces the whole list.
    '';
  };

  # Unison reads its profiles from ~/.unison/ (not an XDG path). The unison
  # package itself is installed at the system level. Only the profile is
  # managed declaratively — Unison's archive/state files (ar*, fp*, locks)
  # are created at runtime and must stay writable, so we place a single file
  # rather than symlinking the whole directory.
  config.home.file.".unison/default.prf".text = ''

    root = /home/martin/
    root = ssh://statler//home/martin/backup/

    ${lib.concatMapStringsSep "\n" (p: "path = ${p}") cfg.paths}

    perms = 0

    ignore = Name {lib*.sqlite}
    ignore = Name {*new.sqlite}
    ignore = Name {quarterlies}
    ignore = Name {member_data}
    ignore = Name {billing_metadata}
    ignore = Name {_billing_reports_cache}
    ignore = Name {GoogleNews-vectors-negative300.bin}
    ignore = Name {glove.6B.300d.txt}
    ignore = Name {glove.6B.300d.w2vformat.txt}
    ignore = Name {MESH}
    ignore = Name {reclaim-saved}
    ignore = Name {transcribe}

  '';
}
