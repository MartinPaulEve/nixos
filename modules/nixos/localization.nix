# Time zone, locale, and console keymap.
{ config, ... }:

{
  # Time zone.
  time.timeZone = "Europe/London";

  # Internationalisation.
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Console keymap, to match the desktop's layout (desktop.nix).
  console.keyMap = if config.services.xserver.xkb.layout == "gb" then "uk" else "us";
}
