# Machine quirk: bring back a USB hub that failed to enumerate at boot.
#
# Opt-in — imported by the hosts that need it (hosts/<name>/default.nix).
#
# The symptom is a hub that is plugged in but dead after a cold boot, with
# everything behind it missing, until it is unplugged and plugged back in. In
# the kernel log the hub stops answering part-way through bringing its ports
# up, a few seconds into the boot:
#
#   hub 1-5:1.0: hub_ext_port_status failed (err = -71)
#   usb 1-5-port4: cannot reset (err = -71)
#   usb 1-5-port4: Cannot enable. Maybe the USB cable is bad?
#   usb 1-5-port4: unable to enumerate USB device
#
# -71 is EPROTO: the hub itself went quiet on the wire, so the kernel gives
# its ports up for lost and never looks again. The same hub enumerates
# cleanly when it is plugged in on a running system, which is all the
# unplug-and-replug was doing.
#
# This does that replug in software, once per boot: it reads the kernel log
# for hubs that failed this way, and power-cycles the motherboard port each
# one hangs off (both its USB 2 and USB 3 halves), which makes the kernel
# enumerate the hub from scratch. A boot where every hub came up is left
# entirely alone, as is a hub that has already been re-enumerated since it
# failed (by hand, or by an earlier run of this).
#
# It treats the symptom, not the cause — see what it logged with
#   journalctl -b -u usb-hub-recover
{ lib, pkgs, ... }:

let
  recover = pkgs.writeShellApplication {
    name = "usb-hub-recover";
    runtimeInputs = with pkgs; [ util-linux coreutils gnugrep gnused ];
    text = ''
      # The motherboard ports ("1-5": bus 1, port 5) with a failed hub
      # somewhere behind them. A failure on a nested hub (1-5.4) is put
      # right from the top as well. Root hubs log as "usb usb1-port5", which
      # deliberately does not match: there is no port above them to cycle.
      failed_ports() {
        dmesg | sed -nE \
          -e 's/.*hub ([0-9]+-[0-9]+)[0-9.]*:[0-9.]+: hub_ext_port_status failed.*/\1/p' \
          -e 's/.*usb ([0-9]+-[0-9]+)[0-9.]*-port[0-9]+: unable to enumerate USB device.*/\1/p' \
          | sort -u
      }

      # Line number of the last kernel message matching $1, or 0.
      last_line() {
        dmesg | grep -nE "$1" | tail -n 1 | cut -d: -f1 | grep . || echo 0
      }

      # Matches a failure message about the hub on $1 or any hub nested
      # behind it (1-5, 1-5.4, ... but not 1-50).
      failure_on() {
        echo "(hub|usb) $1(\\.[0-9.]+)?(:|-port).*(hub_ext_port_status failed|unable to enumerate)"
      }

      status=0
      for top in $(failed_ports); do
        bus="''${top%%-*}"
        port="''${top#*-}"
        failed_at="$(last_line "$(failure_on "$top")")"
        enumerated_at="$(last_line "usb $top: new [a-zA-Z-]+ USB device number")"
        if [ "$enumerated_at" -gt "$failed_at" ]; then
          echo "hub on $top failed earlier but has been re-enumerated since; leaving it alone"
          continue
        fi

        usb2="/sys/bus/usb/devices/usb$bus/$bus-0:1.0/usb$bus-port$port"
        switches=()
        for dir in "$usb2" "$usb2/peer"; do
          if [ -w "$dir/disable" ]; then switches+=("$dir/disable"); fi
        done
        if [ "''${#switches[@]}" -eq 0 ]; then
          echo "hub on $top failed to enumerate, but $usb2 has no power switch; replug it by hand" >&2
          status=1
          continue
        fi

        echo "hub on $top failed to enumerate at boot; power-cycling its port"
        for switch in "''${switches[@]}"; do echo 1 > "$switch" || true; done
        sleep 2
        for switch in "''${switches[@]}"; do echo 0 > "$switch" || true; done

        # Give the hub and what is behind it time to come back, then check
        # the kernel raised no fresh complaint about it.
        sleep 10
        if [ "$(last_line "$(failure_on "$top")")" -gt "$failed_at" ]; then
          echo "hub on $top failed again after the power cycle; replug it by hand" >&2
          status=1
        elif [ "$(last_line "usb $top: new [a-zA-Z-]+ USB device number")" -gt "$failed_at" ]; then
          echo "hub on $top is back"
        else
          echo "hub on $top did not reappear after the power cycle; replug it by hand" >&2
          status=1
        fi
      done
      exit "$status"
    '';
  };
in
{
  systemd.services.usb-hub-recover = {
    description = "Re-enumerate USB hubs that failed to come up at boot";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe recover;
    };
    # Once per boot is the point: a rebuild must not make it look again.
    restartIfChanged = false;
  };
}
