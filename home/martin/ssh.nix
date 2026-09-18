# OpenSSH client configuration.
#
# The config is shipped verbatim from ./ssh/config rather than rendered
# through programs.ssh.matchBlocks, so the deployed file reads exactly as
# written. Nothing here is secret: private keys live in the Bitwarden SSH
# agent, and the IdentityFile entries are public keys that (together with
# IdentitiesOnly) select which agent key to offer to each host.
{ ... }:

{
  home.file = {
    ".ssh/config".source = ./ssh/config;

    # This was previously a GNU Stow symlink into ~/dotfiles. Home Manager's
    # backupFileExtension only rescues regular files, not foreign symlinks,
    # so force-overwrite the stale stow link. The original remains in
    # ~/dotfiles.
    ".ssh/id_ed25519_waldorf.pub" = {
      source = ./ssh/id_ed25519_waldorf.pub;
      force = true;
    };

    ".ssh/id_ed25519_v2.pub".source = ./ssh/id_ed25519_v2.pub;
  };
}
