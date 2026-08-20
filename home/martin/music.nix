# Music tagging: beets (library manager/tagger) and EasyTAG (GTK tag editor).
{ pkgs, ... }:

{
  home.packages = [ pkgs.easytag ];

  # Ensures ~/.local/share/beets exists for the library database.
  xdg.dataFile."beets/.keep".text = "";

  # Configuration migrated from the copy that lived on waldorf at
  # ~/.config/beets/config.yaml, translated to Home Manager settings (which
  # are rendered back to that same file), with one deliberate change: the
  # library database moves from waldorf's ad-hoc ~/data to the XDG data dir,
  # where state belongs — outside ~/Music so nothing syncing or reorganising
  # the music tree touches the SQLite file. Beets does not create the
  # database's parent directory, so the .keep file below guarantees it.
  programs.beets = {
    enable = true;
    settings = {
      directory = "~/Music";
      library = "~/.local/share/beets/musiclibrary.db";
      import.move = true;
      paths = {
        default = "$albumartist/$album%aunique{} ($year)/$track $title";
        singleton = "Non-Album/$artist/$title";
        comp = "Compilations/$album%aunique{} ($year)/$track $title";
      };
    };
  };
}
