# Music tagging: beets (library manager/tagger) and EasyTAG (GTK tag editor).
{ pkgs, ... }:

{
  home.packages = [ pkgs.easytag ];

  # Configuration migrated verbatim from the copy that lived on waldorf at
  # ~/.config/beets/config.yaml, translated to Home Manager settings (which
  # are rendered back to that same file). The library paths are relative to
  # $HOME on whichever machine this runs on: ~/Music must exist before an
  # import, and ~/data must exist for the database.
  programs.beets = {
    enable = true;
    settings = {
      directory = "~/Music";
      library = "~/data/musiclibrary.db";
      import.move = true;
      paths = {
        default = "$albumartist/$album%aunique{} ($year)/$track $title";
        singleton = "Non-Album/$artist/$title";
        comp = "Compilations/$album%aunique{} ($year)/$track $title";
      };
    };
  };
}
