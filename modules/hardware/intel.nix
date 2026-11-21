# Hardware profile: a bare-metal machine with an Intel processor.
#
# The Intel counterpart of ./amd.nix — opt-in, imported by the hosts that are
# one (hosts/<name>/default.nix; scripts/install.sh picks it by detection).
{ ... }:

{
  # CPU microcode updates, loaded early at boot.
  hardware.cpu.intel.updateMicrocode = true;

  # Firmware blobs real devices need and a VM never does: Wi-Fi/Bluetooth
  # chips, integrated graphics, and the microcode above.
  hardware.enableRedistributableFirmware = true;

  # KVM, so QEMU test VMs (scripts/vm_start.sh) run hardware-accelerated.
  boot.kernelModules = [ "kvm-intel" ];

  # Firmware updates for the board, SSD and peripherals via LVFS
  # (`fwupdmgr update`); GNOME Software surfaces them too.
  services.fwupd.enable = true;
}
