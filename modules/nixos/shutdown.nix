# Shutdown latency fixes.
#
# Every shutdown was stalling inside user@1000.service teardown: the systemd
# user manager gives each user service DefaultTimeoutStopSec (90s) to react
# to SIGTERM, and some session services never exit cleanly, so poweroff sat
# waiting for the full window before SIGKILL. Caught in the journal doing
# exactly this: prlcc (every shutdown) and xdg-document-portal (a FUSE
# filesystem that hangs once its backing session is gone).
{ config, lib, ... }:

{
  config = lib.mkMerge [
    {
      # Nothing in a desktop session legitimately needs 90s to stop; cap the
      # wait so a wedged service can only delay shutdown briefly.
      systemd.user.extraConfig = ''
        DefaultTimeoutStopSec=15s
      '';
    }

    (lib.mkIf config.hardware.parallels.enable {
      # Parallels Control Center ignores SIGTERM outright ("State
      # 'stop-sigterm' timed out. Killing." at nearly every shutdown and
      # logout). It holds no state worth waiting for — kill it fast.
      systemd.user.services.prlcc.serviceConfig.TimeoutStopSec = 5;
    })
  ];
}
