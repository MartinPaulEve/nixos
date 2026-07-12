# Git, managed per-user by Home Manager.
{ ... }:

{
  programs.git = {
    enable = true;

    signing = {
      # SSH-format commit signing, using 1Password's op-ssh-sign as the signer
      # rather than the default ssh-keygen. Mirrors [gpg] format = ssh and
      # [gpg "ssh"] program = op-ssh-sign.
      format = "ssh";
      key = "/home/martin/.ssh/id_ed25519_waldorf.pub";
      signByDefault = true;
      signer = "op-ssh-sign";
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
