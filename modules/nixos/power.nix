# Battery/power tuning for the Parallels guest.
#
# Everything here is gated on hardware.parallels.enable, so it is inert in
# the x86 QEMU test VM (which force-disables Parallels tools) and on any
# future non-Parallels install.
{ config, lib, ... }:

{
  config = lib.mkIf config.hardware.parallels.enable {
    # Parallels Tools' shared-printing daemon has a long-standing bug on
    # Linux guests where it spins at 100% CPU forever — measured here eating
    # a full core, which was by far the largest battery drain. Mask its
    # standalone unit; prltoolsd still runs its own (well-behaved) copy, and
    # ordinary network printing through CUPS is unaffected.
    systemd.services.prlshprint.enable = false;

    # GNOME's localsearch file indexer continuously crawls the XDG folders,
    # which on this guest are symlinks onto fuse-mounted Parallels shares —
    # about the most expensive thing an indexer can chew on. File search in
    # Nautilus falls back to plain recursive search.
    services.gnome.localsearch.enable = lib.mkForce false;

    # Apply powertop's auto-tuning (runtime power management for devices)
    # at boot.
    powerManagement.powertop.enable = true;
  };
}
