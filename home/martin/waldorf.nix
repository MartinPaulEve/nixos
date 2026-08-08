# Mounts waldorf's home directory over sshfs at login.
#
# This is a systemd *user* service, so it starts asynchronously with the
# session and can never block boot or login: if waldorf is unreachable the
# unit simply retries in the background until it succeeds.
#
# Authentication comes from the 1Password SSH agent: ~/.ssh/config points
# `Host waldorf` at the /home/martin/.1password/agent.sock IdentityAgent, so
# the ssh that sshfs spawns talks to 1Password directly — no SSH_AUTH_SOCK
# plumbing is needed. That is why the unit is tied to graphical-session.target
# rather than default.target: 1Password authorises key use with a GUI popup,
# which needs a desktop to appear on. Until 1Password is running, unlocked,
# and approved, each attempt fails and the unit quietly retries.
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
      # Start only once the desktop is up, so 1Password can show its
      # authorisation popup. Losing the mount never tears down the session,
      # and the session never waits on the mount.
      After = [ "graphical-session.target" ];
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
      # Retry quietly until waldorf is reachable and 1Password has authorised
      # the key. Spaced out enough that a locked 1Password is not nagged with
      # rapid-fire agent requests.
      Restart = "on-failure";
      RestartSec = "15s";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
