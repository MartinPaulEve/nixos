# Whipper CD ripper: native package and configuration.
{ pkgs, ... }:

{
  # Install whipper so it runs natively (replacing the old Docker wrapper).
  home.packages = [ pkgs.whipper ];

  # Whipper reads its config from ~/.config/whipper/. This seeds the calibrated
  # drive definition (read offset etc.). Note: the file is a read-only store
  # symlink, so re-running whipper's drive calibration won't be able to write
  # back here — update the repo copy and rebuild if the drive is recalibrated.
  xdg.configFile."whipper/whipper.conf".source = ./whipper/whipper.conf;
}
