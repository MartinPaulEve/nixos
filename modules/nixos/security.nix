# Security: SSH hardening, 1Password, YubiKey, and GnuPG.
{ pkgs, ... }:

{
  # Harden SSH.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # 1Password. Kept installed (vault access and the `op` CLI) but nothing
  # autostarts or depends on it any more: the SSH agent, commit signing, and
  # the sshfs mounts have all moved to Bitwarden (home/martin/bitwarden.nix,
  # git.nix, mounts.nix).
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "martin" ];
  };

  # YubiKey.
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # YubiKey tap as an OPTIONAL first authentication factor, for login, sudo,
  # and polkit (which is what 1Password's "unlock with system authentication"
  # uses). "sufficient" is the load-bearing word: a touched key authenticates
  # on its own, but if the key is absent, unregistered, or fails, PAM falls
  # straight through to the ordinary password prompt — the key is never
  # required, so nothing becomes inaccessible without it.
  #
  # One-time enrolment (with the YubiKey attached to the VM):
  #   mkdir -p ~/.config/Yubico && pamu2fcfg > ~/.config/Yubico/u2f_keys
  # (touch the key when it flashes; append a backup key with pamu2fcfg -n >>).
  # Until that file exists, pam_u2f simply fails and passwords behave as today.
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    # Print "Please touch the device" when a registered key is waiting.
    settings.cue = true;
  };

  # pamu2fcfg, for enrolling keys into ~/.config/Yubico/u2f_keys.
  environment.systemPackages = [ pkgs.pam_u2f ];

  # GnuPG agent, also acting as the SSH agent.
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Disable the GNOME SSH agent, which otherwise fights GnuPG for the SSH auth socket.
  services.gnome.gcr-ssh-agent.enable = false;
}
