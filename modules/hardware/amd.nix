# Hardware profile: a bare-metal machine with an AMD processor.
#
# Opt-in — imported by the hosts that are one (hosts/<name>/default.nix), not
# by modules/nixos. These are stated here, not left to a host's
# hardware-configuration.nix, so they survive that file being regenerated.
# Graphics is a separate choice: see ./nvidia.nix.
{ ... }:

{
  # CPU microcode updates, loaded early at boot.
  hardware.cpu.amd.updateMicrocode = true;

  # Firmware blobs real devices need and a VM never does: Wi-Fi/Bluetooth
  # chips (Intel, MediaTek, Realtek), Radeon graphics, and the microcode above.
  hardware.enableRedistributableFirmware = true;

  # KVM, so QEMU test VMs (scripts/vm_start.sh) run hardware-accelerated.
  boot.kernelModules = [ "kvm-amd" ];

  # Firmware updates for the board, SSD and peripherals via LVFS
  # (`fwupdmgr update`); GNOME Software surfaces them too.
  services.fwupd.enable = true;
}
