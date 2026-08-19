# sshfs mounts of remote machines under /home/martin/mounts.
#
# Why these are not fstab entries (fileSystems + noauto,user): a user-invoked
# fstab mount runs the FUSE mount helper — and therefore sshfs and ssh — as
# root, so authentication would need a root process to talk to martin's
# 1Password SSH agent. That socket is 0600, owned by martin, and 1Password
# expects same-user clients inside the desktop session (the same reason
# `sudo ssh` breaks under the agent), so the fstab route is a dead end.
# Instead each mount is a systemd *user* service running sshfs as martin,
# which FUSE permits without root via the setuid fusermount3 wrapper.
#
# Mounts marked autoStart mount at login; the rest never start on their own
# and are mounted on demand, without root:
#
#   systemctl --user start sshfs-lg1     # mount
#   systemctl --user stop  sshfs-lg1     # unmount
#
# Because these are user services they start asynchronously with the session
# and can never block boot or login: if a host is unreachable the unit simply
# retries in the background until it succeeds (or is stopped).
#
# Authentication MUST come from the 1Password SSH agent (started at login by
# onepassword.nix): the IdentityAgent option below points the ssh that sshfs
# spawns straight at 1Password's socket, and BatchMode forbids every
# interactive fallback — without it, ssh responds to a missing agent by
# raising the desktop askpass dialog and asking for the remote password.
# With it, an attempt made before 1Password is up (or while it is locked)
# simply fails and the unit retries. That is also why the units are tied to
# graphical-session.target rather than default.target: 1Password authorises
# key use with a GUI popup, which needs a desktop to appear on.
#
# The mountpoints are also created at every boot, owned by martin, by
# modules/nixos/mounts.nix (systemd-tmpfiles). Keep the two lists in sync —
# drift is non-fatal, as each service mkdir -p's its own mountpoint.
{ pkgs, lib, ... }:

let
  mountsDir = "/home/martin/mounts";

  # Attribute name = directory under ${mountsDir} = unit name suffix.
  mounts = {
    waldorf      = { remote = "martin@waldorf:/home/martin"; autoStart = true; };
    lg1      = { remote = "lg:/volume1/lg/lg"; };
    lg2      = { remote = "sh:/volume2/lg2/lg"; };
    sm_mount = { remote = "sh:/volume1/sh"; };
    ia           = { remote = "backup:/volume2/interneta"; };
  };

  # sshfs passes unrecognised -o options through to ssh.
  sshOptions = [
    "reconnect"              # remount transparently after suspend/network drops
    "ServerAliveInterval=15" # with ServerAliveCountMax, detect dead links fast
    "ServerAliveCountMax=3"
    "BatchMode=yes"          # key auth only: never prompt for a password
    "IdentityAgent=/home/martin/.1password/agent.sock" # the 1Password agent
  ];

  mkMount = name: cfg:
    let
      mountPoint = "${mountsDir}/${name}";
      # Clean up any stale mount left by a crashed/disconnected session
      # (which leaves "Transport endpoint is not connected"), then ensure the
      # mount point exists.
      preStart = pkgs.writeShellScript "sshfs-${name}-pre" ''
        fusermount3 -uz ${mountPoint} 2>/dev/null || true
        mkdir -p ${mountPoint}
      '';
    in
    {
      Unit = {
        Description = "sshfs mount of ${cfg.remote} at ${mountPoint}";
        # Never started before the desktop is up, so 1Password can show its
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
        # -f keeps sshfs in the foreground so systemd supervises it directly.
        ExecStart = "${pkgs.sshfs}/bin/sshfs -f -o ${builtins.concatStringsSep "," sshOptions} ${cfg.remote} ${mountPoint}";
        ExecStop = "fusermount3 -uz ${mountPoint}";
        # Retry quietly until the host is reachable and 1Password has
        # authorised the key. Spaced out enough that a locked 1Password is
        # not nagged with rapid-fire agent requests.
        Restart = "on-failure";
        RestartSec = "15s";
      };
    }
    // lib.optionalAttrs (cfg.autoStart or false) {
      Install.WantedBy = [ "graphical-session.target" ];
    };
in
{
  systemd.user.services =
    lib.mapAttrs' (name: cfg: lib.nameValuePair "sshfs-${name}" (mkMount name cfg))
      mounts;
}
