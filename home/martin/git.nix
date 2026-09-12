# Git, managed per-user by Home Manager.
{ pkgs, ... }:

let
  # ssh-keygen pinned to the Bitwarden SSH agent. Because `key` below is a
  # *public* key file, ssh-keygen -Y sign looks the private half up in the
  # agent; the wrapper fixes SSH_AUTH_SOCK because the session's ambient
  # socket belongs to gpg-agent (security.nix), not Bitwarden. Needs the key
  # in the Bitwarden vault and its SSH agent enabled — see bitwarden.nix.
  bw-ssh-sign = pkgs.writeShellScript "bw-ssh-sign" ''
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
    exec ${pkgs.openssh}/bin/ssh-keygen "$@"
  '';
in
{
  programs.git = {
    enable = true;

    signing = {
      # SSH-format commit signing against the Bitwarden SSH agent (formerly
      # 1Password's op-ssh-sign).
      format = "ssh";
      key = "/home/martin/.ssh/id_ed25519_waldorf.pub";
      signByDefault = true;
      signer = "${bw-ssh-sign}";
    };

    settings = {
      user = {
        name = "Martin Paul Eve";
        email = "martin@eve.gd";
      };

      push.autoSetupRemote = true;

      # Use `gh auth git-credential` for GitHub and Gist. The leading empty
      # string resets any inherited helper before adding ours.
      credential."https://github.com".helper = [ "" "!gh auth git-credential" ];
      credential."https://gist.github.com".helper = [ "" "!gh auth git-credential" ];
    };
  };
}
