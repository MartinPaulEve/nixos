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
# and are mounted on demand, without root, via the sshmount/sshumount
# helpers generated below (plain `systemctl --user start/stop sshfs-<name>`
# works too):
#
#   sshmount lg1             # mount one (also: sshmount ~/mounts/lg1)
#   sshmount                     # mount everything
#   sshumount lg1            # unmount one
#   sshumount                    # unmount everything
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
  #
  # A remote is either a literal host:path or a 1Password secret reference
  # (op://vault/item/field), resolved with `op read` when the unit starts so
  # the real host paths never appear in this repo. The referenced items are
  # Secure Notes in the Personal vault with a single text field `remote`
  # holding the literal host:path; `op read` authorises through the desktop
  # app (same GUI prompt as the SSH agent), which is fine because these
  # mounts only start on demand from within the session.
  #
  # The NAS paths are share-relative, NOT absolute: DSM's SFTP service
  # chroots each user into a virtual root containing only the DSM shared
  # folders, so /volumeX prefixes do not exist over SFTP and only shares
  # (not arbitrary directories or symlinks under /volumeX) are reachable.
  mounts = {
    waldorf      = { remote = "martin@waldorf:/home/martin"; autoStart = true; };
    lg1      = { remote = "op://Personal/sshmount-lg1/remote"; };
    lg2      = { remote = "op://Personal/sshmount-lg2/remote"; };
    sm_mount = { remote = "op://Personal/sshmount-sm_mount/remote"; };
    ia           = { remote = "backup:/interneta"; };
  };

  # sshfs passes unrecognised -o options through to ssh.
  sshOptions = [
    "reconnect"              # remount transparently after suspend/network drops
    # Several ssh connections per mount, so one bulk consumer (Nautilus
    # thumbnailing a directory of PDFs, say) cannot queue every other
    # request behind it and make interactive `ls` hang for minutes.
    "max_conns=4"
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
      # Resolve an op:// remote via 1Password at mount time (literal remotes
      # pass straight through), then exec sshfs. `op` comes from
      # /run/wrappers/bin, which the unit's PATH puts first. A failed read
      # (1Password locked, authorisation declined) fails the unit, which
      # then retries on the usual RestartSec cadence.
      launch = pkgs.writeShellScript "sshfs-${name}-launch" ''
        remote='${cfg.remote}'
        case "$remote" in
          op://*) remote="$(op read "$remote")" || exit 1 ;;
        esac
        # -f keeps sshfs in the foreground so systemd supervises it directly.
        exec ${pkgs.sshfs}/bin/sshfs -f -o ${builtins.concatStringsSep "," sshOptions} "$remote" ${mountPoint}
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
        ExecStart = "${launch}";
        ExecStop = "/run/wrappers/bin/fusermount3 -uz ${mountPoint}";
        # At shutdown the system tears the network down concurrently with the
        # user session, so sshfs blocks on the dead server for the whole
        # ServerAlive window (45s) before it notices and exits — stalling
        # poweroff. The lazy unmount above has already detached the
        # mountpoint by then, so there is nothing worth waiting for: kill the
        # leftover sshfs process quickly.
        TimeoutStopSec = "5s";
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

  # Command-line helpers generated from the same attrset, so their mount list
  # can never drift from the units. An argument may be a bare mount name
  # (lg1) or any path ending in one (~/mounts/lg1); only the final
  # path component is significant. With no arguments they act on every mount.
  knownMounts = builtins.concatStringsSep " " (builtins.attrNames mounts);

  # Turns the command's arguments into a validated `targets` array, failing
  # fast (before anything is mounted or unmounted) on an unknown name.
  resolveTargets = ''
    known="${knownMounts}"
    resolve() {
      local arg="''${1%/}" name k
      name="''${arg##*/}"
      for k in $known; do
        if [ "$k" = "$name" ]; then printf '%s\n' "$k"; return 0; fi
      done
      echo "''${0##*/}: unknown mount '$1' (known: $known)" >&2
      return 1
    }
    targets=()
    if [ "$#" -eq 0 ]; then
      for k in $known; do targets+=("$k"); done
    else
      for arg in "$@"; do targets+=("$(resolve "$arg")"); done
    fi
  '';

  sshmount = pkgs.writeShellScriptBin "sshmount" ''
    set -euo pipefail
    ${resolveTargets}
    for name in "''${targets[@]}"; do
      systemctl --user start "sshfs-$name"
    done
    # The services are Type=simple, so `start` returns before ssh has
    # actually connected: poll briefly, then report. Anything still pending
    # keeps retrying inside its unit.
    for _ in $(seq 1 20); do
      ok=1
      for name in "''${targets[@]}"; do
        mountpoint -q "${mountsDir}/$name" || ok=0
      done
      [ "$ok" -eq 1 ] && break
      sleep 0.5
    done
    for name in "''${targets[@]}"; do
      if mountpoint -q "${mountsDir}/$name"; then
        echo "mounted ${mountsDir}/$name"
      else
        echo "sshfs-$name is not up yet; it will keep retrying in the" \
             "background (is 1Password unlocked and the host reachable?)"
      fi
    done
  '';

  sshumount = pkgs.writeShellScriptBin "sshumount" ''
    set -euo pipefail
    ${resolveTargets}
    for name in "''${targets[@]}"; do
      mp="${mountsDir}/$name"
      # Stopping the unit unmounts, and also halts a unit that is still in
      # its retry loop without having mounted anything yet.
      systemctl --user stop "sshfs-$name"
      if mountpoint -q "$mp"; then
        # Mounted outside the unit (e.g. sshfs run by hand): unmount directly.
        fusermount3 -uz "$mp"
      fi
      if mountpoint -q "$mp"; then
        echo "sshumount: failed to unmount $mp" >&2
        exit 1
      fi
      echo "unmounted $mp"
    done
  '';
in
{
  systemd.user.services =
    lib.mapAttrs' (name: cfg: lib.nameValuePair "sshfs-${name}" (mkMount name cfg))
      mounts;

  home.packages = [ sshmount sshumount ];
}
