# animal: a bare-metal machine — AMD processor, NVIDIA graphics card, GRUB
# bootloader.
#
# Written by scripts/install.sh from this machine's own answers; edit it
# freely afterwards. A host directory holds only what is particular to one
# machine. The shared system modules, the Home Manager configuration and the
# hostname — which is this directory's name — are all supplied by flake.nix,
# so every host gets the same packages and home directory.
{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/amd.nix
    ../../modules/hardware/nvidia.nix
    # This machine also carries Windows and Ubuntu, and its firmware starts
    # GRUB, whose menu lists them; see modules/hardware/grub.nix.
    ../../modules/hardware/grub.nix
    # The hub on the desk (mouse receiver, audio interface, webcam, YubiKey)
    # drops off the bus during a cold boot and stays dead until replugged;
    # see modules/hardware/usb-hub-recover.nix.
    ../../modules/hardware/usb-hub-recover.nix
    # The older home partition on the first NVMe drive, mounted at boot, with
    # ~/Documents, ~/Music and ~/Pictures linked onto it.
    ./central-home.nix
  ];

  # NVIDIA's open kernel module (required for the RTX 50 series) instead of
  # the proprietary one; see modules/hardware/nvidia.nix.
  hardware.nvidia.open = true;

  # Keep the PCIe links out of their power-saving states (ASPM). The Ubuntu
  # install on this machine has always booted with this parameter; NixOS
  # came up without it, with link power saving active on all three NVMe
  # drives, and within two days had frozen once in a way that points at the
  # root drive going away: the system log stops dead mid-evening, yet the
  # next morning sshd still answered — only to reset every connection — and
  # the screens, long since blanked, would not come back. That is a kernel
  # still running with nothing left to read programs from or write logs to.
  # Unproven as the cause (a freeze like that leaves no log), but it is the
  # one known difference from the install that does not freeze, and costs a
  # few watts at idle. Check it took with:
  #   cat /sys/module/pcie_aspm/parameters/policy
  #
  # It froze the same way a second time, on the evening of 22 November 2026 —
  # which says nothing against this parameter: it had been added that
  # morning without a reboot, so that boot ran without it too. The boot of
  # 23 November is the first with it. If the machine freezes like this
  # again on a boot where the check above says [performance], the links are
  # cleared and the next suspect is the drives' own idle states (APST):
  #   nvme_core.default_ps_max_latency_us=0
  boot.kernelParams = [ "pcie_aspm.policy=performance" ];

  # The monitor layout for the login screen: three side by side, the middle
  # one (the VS248 on DP-3) primary, which is where GDM puts the login
  # dialog. GDM runs as its own user and never sees ~/.config/monitors.xml,
  # so without this it falls back to the first connector, the left-hand
  # screen. Mutter reads monitors.xml from the system config directories as
  # well as the user's, hence /etc/xdg; a layout saved from Settings →
  # Displays still wins inside the session.
  #
  # The file is the matching <configuration> from ~/.config/monitors.xml. It
  # is keyed to connectors and serial numbers, so after recabling or swapping
  # a monitor, set the layout up in Settings → Displays and copy it across
  # again; until then the login screen just uses its default layout.
  environment.etc."xdg/monitors.xml".source = ./monitors.xml;

  # No waldorf mount here: waldorf is the Ubuntu install on this machine's
  # own disks, so it is never running while animal is. Left in, the unit
  # retried for ever against a host that cannot answer.
  sshfsMounts.exclude = [ "waldorf" ];

  # The NixOS release this system was first installed with.
  # See `man configuration.nix` before changing.
  system.stateVersion = "26.05";
}
