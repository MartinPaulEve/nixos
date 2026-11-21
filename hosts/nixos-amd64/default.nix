# Host "nixos-amd64": the bare-metal AMD (x86_64) machine.
#
# Same modules and the same Home Manager configuration as the Parallels guest
# (hosts/nixos), so both machines carry the same packages and home directory.
# Only what real AMD hardware needs lives here; everything Parallels-specific
# elsewhere in the repo is gated on hardware.parallels.enable, which this host
# never sets. See AMD64.md for the full picture and the install steps.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos
    ../../home
  ];

  # Host identity. Deliberately not "nixos": the hostname is this machine's
  # name on the tailnet and its device label in NextDNS (networking.nix), and
  # two machines sharing one would be indistinguishable in both.
  networking.hostName = "nixos-amd64";

  # --- AMD hardware ---------------------------------------------------------
  # These are stated here, not left to hardware-configuration.nix, so they
  # survive that file being regenerated on the machine.

  # CPU microcode updates, loaded early at boot.
  hardware.cpu.amd.updateMicrocode = true;

  # Firmware blobs real devices need and a VM never does: Radeon graphics,
  # Wi-Fi/Bluetooth chips (Intel, MediaTek, Realtek), and the microcode above.
  hardware.enableRedistributableFirmware = true;

  # KVM, so QEMU test VMs (scripts/vm_start.sh) run hardware-accelerated.
  boot.kernelModules = [ "kvm-amd" ];

  # Early KMS for Radeon graphics — the bare-metal counterpart of the guest's
  # virtio_gpu (hosts/nixos/default.nix): the real driver comes up in the
  # initrd, so Plymouth draws the splash on it from the start. Covers both
  # integrated (Ryzen APU) and discrete Radeon cards. With an NVIDIA or Intel
  # card instead the module loads and finds nothing; see AMD64.md.
  hardware.amdgpu.initrd.enable = true;

  # Firmware updates for the board, SSD and peripherals via LVFS
  # (`fwupdmgr update`); GNOME Software surfaces them too.
  services.fwupd.enable = true;

  # The NixOS release this system was first installed with.
  # See `man configuration.nix` before changing.
  system.stateVersion = "26.05";
}
