# GNOME / dconf settings, migrated from the previous `dconf dump /` backup.
#
# Generated with dconf2nix from ~/dotfiles/gnome/gnome_settings_backup.ini, then
# pruned of noise that shouldn't be pinned declaratively:
#   - leftover Budgie desktop config (com/solus-project, org/buddiesofbudgie)
#   - the app-grid layout (org/gnome/shell app-picker-layout) and xsettings
#     overrides (rebuilt by GNOME from installed apps)
#   - transient state: run-dialog command-history, welcome-dialog / donation
#     reminder timestamps, and the VM-specific dash-to-dock monitor pin
#
# Requires the dash-to-dock extension package (installed via users.martin.packages).
# Re-dump and regenerate if you want to capture new GNOME tweaks.
{ lib, ... }:

with lib.hm.gvariant;

{
  dconf.settings = {
    "de/wagnermartin/Plattenalbum" = {
      height = 650;
      host = "raspberrypi";
      manual-connection = true;
      maximize = false;
      mpris = false;
      width = 870;
    };

    "io/github/htkhiem/Euphonica" = {
      background-portal-available = true;
    };

    "io/github/htkhiem/Euphonica/client" = {
      mpd-fifo-format = "44100:16:2";
      mpd-host = "raspberrypi";
      mpd-port = mkUint32 6600;
      pipewire-last-device = "";
    };

    "io/github/htkhiem/Euphonica/metaprovider/lrclib" = {
      enabled = true;
    };

    "io/github/htkhiem/Euphonica/metaprovider/musicbrainz" = {
      enabled = true;
    };

    "io/github/htkhiem/Euphonica/player" = {
      visualizer-fft-samples = mkUint32 512;
      visualizer-fps = mkUint32 30;
      visualizer-spectrum-bins = mkUint32 10;
    };

    "io/github/htkhiem/Euphonica/state" = {
      autostart = false;
      last-window-height = 640;
      last-window-width = 600;
      run-in-background = false;
    };

    "io/github/htkhiem/Euphonica/ui" = {
      bg-opacity = 0.36;
      use-album-art-as-bg = true;
      use-visualizer = false;
      visualizer-bottom-opacity = 0.0;
      visualizer-scale = 1.0;
      visualizer-top-opacity = 0.75;
    };

    "org/gnome/Console" = {
      last-window-maximised = false;
      last-window-size = mkTuple [ 732 528 ];
      theme = "day";
    };

    "org/gnome/Music" = {
      window-maximized = true;
    };

    "org/gnome/baobab/ui" = {
      is-maximized = false;
      window-size = mkTuple [ 960 600 ];
    };

    "org/gnome/calculator" = {
      base = 10;
      button-mode = "basic";
      source-units = [ "degree" ];
      target-units = [ "radian" ];
      unit-category = "angle";
      window-maximized = false;
      window-size = mkTuple [ 360 616 ];
    };

    "org/gnome/control-center" = {
      last-panel = "keyboard";
      window-state = mkTuple [ 980 640 true ];
    };

    "org/gnome/desktop/app-folders" = {
      folder-children = [ "System" "Utilities" "YaST" "Pardus" ];
    };

    "org/gnome/desktop/app-folders/folders/Pardus" = {
      categories = [ "X-Pardus-Apps" ];
      name = "X-Pardus-Apps.directory";
      translate = true;
    };

    "org/gnome/desktop/app-folders/folders/System" = {
      apps = [ "org.gnome.baobab.desktop" "org.gnome.DiskUtility.desktop" "org.gnome.Logs.desktop" "org.gnome.SystemMonitor.desktop" ];
      name = "X-GNOME-Shell-System.directory";
      translate = true;
    };

    "org/gnome/desktop/app-folders/folders/Utilities" = {
      apps = [ "org.gnome.Decibels.desktop" "org.gnome.Connections.desktop" "org.gnome.Papers.desktop" "org.gnome.font-viewer.desktop" "org.gnome.Loupe.desktop" "org.gnome.seahorse.Application.desktop" ];
      name = "X-GNOME-Shell-Utilities.directory";
      translate = true;
    };

    "org/gnome/desktop/app-folders/folders/YaST" = {
      categories = [ "X-SuSE-YaST" ];
      name = "suse-yast.directory";
      translate = true;
    };

    "org/gnome/desktop/background" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/sheet-l.jxl";
      picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/sheet-d.jxl";
      primary-color = "#1a5fb4";
      secondary-color = "#000000";
    };

    "org/gnome/desktop/break-reminders/eyesight" = {
      play-sound = true;
    };

    "org/gnome/desktop/break-reminders/movement" = {
      duration-seconds = mkUint32 300;
      interval-seconds = mkUint32 1800;
      play-sound = true;
    };

    "org/gnome/desktop/input-sources" = {
      sources = [ (mkTuple [ "xkb" "gb+mac" ]) ];
      xkb-options = [];
    };

    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-light";
      # The "Mono" Nerd Font variant forces single-width glyphs; the non-Mono
      # variant's double-width icons make VTE inflate every cell, spacing all
      # text far apart. Mono keeps normal terminal metrics and still has icons.
      monospace-font-name = "CaskaydiaCove Nerd Font Mono 11";
    };

    "org/gnome/desktop/notifications" = {
      application-children = [ "org-gnome-console" "firefox" "gnome-about-panel" "org-gnome-baobab" "sublime-text" "io-github-htkhiem-euphonica" "de-wagnermartin-plattenalbum" ];
    };

    "org/gnome/desktop/notifications/application/de-wagnermartin-plattenalbum" = {
      application-id = "de.wagnermartin.Plattenalbum.desktop";
    };

    "org/gnome/desktop/notifications/application/firefox" = {
      application-id = "firefox.desktop";
    };

    "org/gnome/desktop/notifications/application/gnome-about-panel" = {
      application-id = "gnome-about-panel.desktop";
    };

    "org/gnome/desktop/notifications/application/io-github-htkhiem-euphonica" = {
      application-id = "io.github.htkhiem.Euphonica.desktop";
    };

    "org/gnome/desktop/notifications/application/org-gnome-baobab" = {
      application-id = "org.gnome.baobab.desktop";
    };

    "org/gnome/desktop/notifications/application/org-gnome-console" = {
      application-id = "org.gnome.Console.desktop";
    };

    "org/gnome/desktop/notifications/application/sublime-text" = {
      application-id = "sublime_text.desktop";
    };

    "org/gnome/desktop/peripherals/keyboard" = {
      numlock-state = false;
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      two-finger-scrolling-enabled = true;
    };

    "org/gnome/desktop/screensaver" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/sheet-l.jxl";
      primary-color = "#1a5fb4";
      secondary-color = "#000000";
    };

    "org/gnome/desktop/wm/keybindings" = {
      switch-applications = [];
      switch-applications-backward = [];
      switch-windows = [ "<Alt>Tab" ];
      switch-windows-backward = [ "<Shift><Alt>Tab" ];
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
    };

    "org/gnome/epiphany/state" = {
      is-maximized = true;
      window-size = mkTuple [ 1024 736 ];
    };

    "org/gnome/nautilus/preferences" = {
      migrated-gtk-settings = true;
    };

    "org/gnome/nautilus/window-state" = {
      initial-size = mkTuple [ 890 550 ];
    };

    "org/gnome/settings-daemon/plugins/color" = {
      night-light-schedule-automatic = false;
    };

    "org/gnome/shell" = {
      enabled-extensions = [ "dash-to-dock@micxgx.gmail.com" ];
      favorite-apps = [ "org.gnome.Calendar.desktop" "org.gnome.Music.desktop" "org.gnome.Nautilus.desktop" "org.gnome.Console.desktop" "pycharm.desktop" "1password.desktop" "sublime_text.desktop" "writer.desktop" "zotero.desktop" ];
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      autohide = true;
      autohide-in-fullscreen = false;
      background-opacity = 0.8;
      dash-max-icon-size = 32;
      dock-position = "BOTTOM";
      height-fraction = 1.0;
      icon-size-fixed = true;
      intellihide-mode = "FOCUS_APPLICATION_WINDOWS";
      preview-size-scale = 1.0;
      require-pressure-to-show = false;
    };

    "org/gnome/shell/world-clocks" = {
      locations = [];
    };

    "org/gtk/settings/file-chooser" = {
      date-format = "regular";
      location-mode = "path-bar";
      show-hidden = false;
      show-size-column = true;
      show-type-column = true;
      sidebar-width = 167;
      sort-column = "name";
      sort-directories-first = false;
      sort-order = "ascending";
      type-format = "category";
      window-position = mkTuple [ 26 23 ];
      window-size = mkTuple [ 1024 641 ];
    };

  };
}
