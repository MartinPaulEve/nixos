# Bootloader, kernel, and disk decryption.
{ pkgs, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use the latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Graphical boot splash (also themes the LUKS unlock prompt).
  boot.plymouth = {
    enable = true;
    theme = "rings";
    # Pull just the "rings" theme out of the adi1090x collection.
    themePackages = [
      (pkgs.adi1090x-plymouth-themes.override {
        selected_themes = [ "rings" ];
      })
    ];
  };

  # Quiet the console so Plymouth shows a clean splash instead of kernel logs.
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [ "quiet" "splash" "rd.udev.log_level=3" "udev.log_level=3" ];
}
