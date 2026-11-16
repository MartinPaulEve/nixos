# YubiKey, per-user side: GnuPG smartcard access and touch notifications.
#
# The system half (pcscd, udev, pam_u2f, gpg-agent as SSH agent, tooling) is
# in modules/nixos/security.nix; see docs/yubikey.md for the whole picture.
{ pkgs, ... }:

{
  programs.gpg = {
    enable = true;
    # gpg's scdaemon normally drives the card through its own CCID driver
    # and holds the USB interface exclusively, which locks out pcscd — and
    # with it ykman, Yubico Authenticator, age-plugin-yubikey and anything
    # else that talks PIV/OATH/OpenPGP through PC/SC. disable-ccid makes
    # scdaemon go through pcscd (security.nix runs it) so everyone shares.
    scdaemonSettings.disable-ccid = true;
  };

  # A touch request is invisible on a YubiKey that is plugged into the Mac
  # and passed through to the VM: the LED is on the desk, not on screen.
  # yubikey-touch-detector watches gpg, FIDO (hidraw) and pcscd activity and
  # raises a desktop notification whenever the key is waiting for a tap.
  home.packages = [ pkgs.yubikey-touch-detector ];
  systemd.user.services.yubikey-touch-detector = {
    Unit = {
      Description = "Desktop notification when the YubiKey is waiting for a touch";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.yubikey-touch-detector}/bin/yubikey-touch-detector -libnotify";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
