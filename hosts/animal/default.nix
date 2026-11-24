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

  # The drive this system runs from has three times vanished while the
  # machine was up (about 18:17 on 21 November 2026, 18:31 on the
  # 22nd, 01:37 on the 24th). Each time looks the same: the system log stops
  # dead, sshd still answers but resets every connection, a new terminal
  # says "exec syscall failed … error.FileSystem", and whatever is open
  # reports I/O errors on files in /home. / , /nix and /home are all on that
  # one drive, so that is a kernel still running with nothing to read
  # programs from or write logs to — and, the journal being on the drive
  # that went, with no record of what happened to it.
  #
  # What is known about the drive: a Samsung 990 PRO (firmware 4B2QJXD7) in
  # an M.2 slot fed through the motherboard chipset, at PCI address
  # 0000:0c:00.0. The Ubuntu install on this machine, which does not freeze,
  # runs from a different drive in a different slot (the 9100 PRO at
  # 0000:02:00.0), so "it never happened on Ubuntu" does not clear this
  # drive or its slot.
  #
  # Two settings, one per layer of power saving between the kernel and the
  # drive:
  #
  # - pcie_aspm.policy=performance keeps the PCIe links out of their own
  #   power-saving states (ASPM). Ubuntu here has always booted with it. It
  #   is not the whole answer: the freeze of the 24th was on a boot that had
  #   it, with every NVMe link showing ASPM off.
  #
  # - nvme_core.default_ps_max_latency_us=0 stops the drives putting
  #   themselves into their idle power states (APST) and coming back out,
  #   which is where this model on this firmware is known to fall off the
  #   bus ("controller is down; will reset: CSTS=0xffffffff" is the kernel's
  #   message, and this parameter its own suggested remedy). Samsung's later
  #   firmware (7B2QJXD7 onwards) lists "intermittent non-recognition" among
  #   its fixes; updating both 990 PROs is the cure, this the workaround.
  #   Costs a watt or so per drive at idle.
  #
  # Check both took with:
  #   cat /sys/module/pcie_aspm/parameters/policy              # [performance]
  #   cat /sys/module/nvme_core/parameters/default_ps_max_latency_us   # 0
  #
  # If it freezes again with both in place, power saving is cleared at both
  # layers, and what is left is the drive itself (firmware, or a
  # replacement) or its slot (reseat it, move the drive to a slot fed by the
  # processor, or hold the slot at a lower link speed in the firmware
  # setup). The kernel's messages at the moment the drive goes would tell
  # the two apart — a controller that stopped answering is the drive; a PCIe
  # link going down or AER errors are the slot — but they are lost with the
  # journal unless something is copying them to another drive at the time.
  boot.kernelParams = [
    "pcie_aspm.policy=performance"
    "nvme_core.default_ps_max_latency_us=0"
  ];

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
