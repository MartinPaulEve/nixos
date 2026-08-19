# Mountpoints for the sshfs user mounts defined in home/martin/mounts.nix.
#
# systemd-tmpfiles creates them at every boot, owned by martin, so the
# directories exist before any login and the user services can mount into
# them without root. Keep this list in sync with home/martin/mounts.nix —
# drift is non-fatal, as each mount service also mkdir -p's its own
# mountpoint before mounting.
{ ... }:

{
  systemd.tmpfiles.rules = [
    "d /home/martin/mounts              0755 martin users -"
    "d /home/martin/mounts/waldorf      0755 martin users -"
    "d /home/martin/mounts/lg1      0755 martin users -"
    "d /home/martin/mounts/lg2      0755 martin users -"
    "d /home/martin/mounts/sm_mount 0755 martin users -"
    "d /home/martin/mounts/ia           0755 martin users -"
  ];
}
