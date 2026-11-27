# immurok, the wireless fingerprint key: touch it to approve sudo and polkit
# prompts, unlock the screen, and release the keys it holds.
#
# The Linux side is upstream's companion app (https://immurok.com/download/),
# built from source in ./package.nix. It needs no kernel driver and has
# nothing to do with fprintd. The pieces:
#
#   - immurok-daemon, a system service under an account of its own. It holds
#     the pairing key and talks to the fingerprint key over Bluetooth LE,
#     through BlueZ.
#   - pam_immurok.so, which asks the daemon for a fingerprint when sudo or
#     polkit wants authentication.
#   - immurok-session-agent, a user service in each login session, which
#     shows the daemon's "touch the key" dialogs and notifications for it.
#   - immurok-cli (also `immurok-cli tui`), imk and the "immurok" settings
#     app, for pairing, enrolling fingerprints and everything else.
#
# Upstream's packages and `make install` do the rest imperatively: create the
# account, enable the units, and edit /etc/pam.d from the app's PAM page.
# Here that is declared below instead, so the app's PAM page can only report
# what it finds; its Install and Remove buttons answer that the configuration
# is managed by NixOS (./pam-helper.sh).
#
# One-time setup, per machine, after the first rebuild with this in it: open
# "immurok" from the app menu (or run `immurok-cli pair`), connect the key,
# link this computer and enrol a fingerprint. Then `sudo -k && sudo true`
# should ask for a touch. Pairing lives in /var/lib/immurok, which belongs to
# the daemon's account and stays out of this repository.
#
# One switch in the app to leave alone: "SSH", which makes the daemon the SSH
# agent by rewriting ~/.ssh/config. Home Manager owns that file here
# (home/martin/ssh.nix) and would put its own back at the next rebuild. To
# use the key for SSH, add the IdentityAgent line to home/martin/ssh/config.
{ config, pkgs, ... }:

let
  immurok = pkgs.callPackage ./package.nix { };

  # Where the fingerprint goes among the optional factors: just ahead of the
  # YubiKey (security.nix), which is itself ahead of the password.
  pamRule = service: settings: {
    order = config.security.pam.services.${service}.rules.auth.u2f.order - 50;
    control = "sufficient";
    modulePath = "${immurok}/lib/security/pam_immurok.so";
    inherit settings;
  };
in
{
  # The CLI and settings app, and with them the polkit pieces, which polkit
  # reads from the system profile: the rule that lets the daemon lock and
  # unlock the session, and the action behind the app's PAM page.
  environment.systemPackages = [ immurok ];

  # The key is a Bluetooth LE device. GNOME turns Bluetooth on by default;
  # said here because without it there is nothing for the daemon to talk to.
  hardware.bluetooth.enable = true;

  # The D-Bus policy that lets the daemon's account use BlueZ, and the
  # session-bus entry that starts the settings app on demand.
  services.dbus.packages = [ immurok ];

  # The daemon's account. It owns the pairing key and the socket directory,
  # so that nothing running as martin can read the one or replace the other.
  users.users.immurok = {
    isSystemUser = true;
    group = "immurok";
    description = "immurok fingerprint daemon";
  };
  users.groups.immurok = { };

  # Upstream's units, as shipped (they carry the daemon's sandboxing), turned
  # on here: the daemon at boot, the agent in every login session.
  systemd.packages = [ immurok ];
  systemd.services.immurok-daemon.wantedBy = [ "multi-user.target" ];
  systemd.user.services.immurok-session-agent = {
    wantedBy = [ "default.target" ];
    # People's sessions only. A unit enabled for all users also belongs to
    # the login screen's own session, where there is nobody to show a dialog
    # to (the espanso unit has the same wrinkle; see espanso.nix).
    unitConfig.ConditionUser = "!@system";
  };

  # The socket directory exists from boot, before the daemon first starts,
  # so the PAM module never finds it missing. (Upstream's tmpfiles.d entry.)
  systemd.tmpfiles.rules = [ "d /run/immurok 0755 immurok immurok -" ];

  # A fingerprint as an OPTIONAL first factor for sudo and polkit, ahead of
  # the YubiKey tap and the password (security.nix). "sufficient" again: a
  # recognised finger authenticates on its own, and anything else falls
  # through to the next factor: no key in range, an unpaired machine, the
  # daemon stopped, a finger that does not match, or the wait running out.
  # The daemon answers at once when the key is not connected, so a machine
  # without it loses no time. In a terminal any keypress skips the wait;
  # polkit's dialogs have no terminal to press a key in, hence the shorter
  # wait there (upstream's own value).
  #
  # Deliberately not the login or lock screen: there the module stands aside
  # and the daemon unlocks the session itself on a matching touch.
  security.pam.services = {
    sudo.rules.auth.immurok = pamRule "sudo" { };
    polkit-1.rules.auth.immurok = pamRule "polkit-1" { timeout = 10; };
  };
}
