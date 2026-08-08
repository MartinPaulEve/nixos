# Mounts waldorf's home directory over sshfs at login.
#
# This is a systemd *user* service, so it starts asynchronously with the
# session and can never block boot or login: if waldorf is unreachable the
# unit simply retries in the background until it succeeds. SSH key
# authentication for martin@waldorf must already be set up, since a service
# cannot answer an interactive password prompt.
{ pkgs, ... }:

let
  mountPoint = "/home/martin/waldorf-home";
  remote = "martin@waldorf:/home/martin";

  # Clean up any stale mount left by a crashed/disconnected session (which
  # leaves "Transport endpoint is not connected"), then ensure the mount
  # point exists.
  preStart = pkgs.writeShellScript "waldorf-sshfs-pre" ''
    fusermount3 -uz ${mountPoint} 2>/dev/null || true
    mkdir -p ${mountPoint}
  '';
in
{
  systemd.user.services.waldorf-home-sshfs = {
    Unit = {
      Description = "sshfs mount of ${remote} at ${mountPoint}";
      # PartOf nothing on purpose: losing the mount should not tear down the
      # session, and the session does not wait on the mount.
    };

    Service = {
      Type = "simple";
      # /run/wrappers/bin must come first so sshfs finds the setuid
      # fusermount3 wrapper, which unprivileged mounts require on NixOS.
      Environment = "PATH=/run/wrappers/bin:/run/current-system/sw/bin";
      ExecStartPre = "${preStart}";
      # -f keeps sshfs in the foreground so systemd supervises it directly;
      # reconnect + ServerAlive* make it survive suspend and network drops.
      ExecStart = "${pkgs.sshfs}/bin/sshfs -f -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 ${remote} ${mountPoint}";
      ExecStop = "fusermount3 -uz ${mountPoint}";
      # Retry quietly until waldorf is reachable (e.g. logging in before the
      # network is up, or the host being offline).
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
