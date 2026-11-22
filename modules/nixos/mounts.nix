# Mountpoints for the sshfs user mounts defined in home/martin/mounts.nix,
# and the per-host switch that leaves a mount out.
#
# systemd-tmpfiles creates the mountpoints at every boot, owned by martin, so
# the directories exist before any login and the user services can mount into
# them without root. Keep the list in sync with home/martin/mounts.nix —
# drift is non-fatal, as each mount service also mkdir -p's its own
# mountpoint before mounting.
{ config, lib, ... }:

let
  mountsDir = "/home/martin/mounts";
  mounts = [ "waldorf" "lg1" "lg2" "sm_mount" "ia" ];
  excluded = config.sshfsMounts.exclude;
in
{
  options.sshfsMounts.exclude = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "waldorf" ];
    description = ''
      sshfs mounts (by name, as in home/martin/mounts.nix) that this host
      must not have at all: no unit, no mountpoint, and not known to
      sshmount/sshumount. For a mount that can never work from here — a
      machine cannot mount itself, or the other system installed on its own
      disks. Set it in the host's own file (hosts/<name>/default.nix).
    '';
  };

  config.systemd.tmpfiles.rules =
    [ "d ${mountsDir} 0755 martin users -" ]
    ++ map (name: "d ${mountsDir}/${name} 0755 martin users -")
      (lib.subtractLists excluded mounts)
    # Tidy away the mountpoint an excluded mount left behind. `r` only ever
    # removes an empty directory, so nothing can be lost to it.
    ++ map (name: "r ${mountsDir}/${name}") excluded;
}
