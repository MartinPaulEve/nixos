# Container virtualisation.
{ ... }:

{
  # Docker daemon. This also creates the `docker` group and installs the CLI;
  # users in that group can access the daemon socket (see users.nix).
  virtualisation.docker.enable = true;
}
