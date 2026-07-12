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

  # 1Password.
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "martin" ];
  };

  # YubiKey.
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # GnuPG agent, also acting as the SSH agent.
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Disable the GNOME SSH agent, which otherwise fights GnuPG for the SSH auth socket.
  services.gnome.gcr-ssh-agent.enable = false;
}
