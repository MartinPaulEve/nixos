# Hardware profile: an NVIDIA graphics card on NVIDIA's own driver.
#
# Opt-in — imported by the hosts that have one (hosts/<name>/default.nix).
# The driver is unfree; modules/nixos/nix.nix already allows that.
{ config, lib, ... }:

{
  # Despite the name this selects the driver for Wayland sessions as well as
  # X11, and is what pulls NVIDIA's kernel modules and userspace in.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics.enable = true;

  hardware.nvidia = {
    # The current production driver branch, built for the running kernel.
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Which kernel module to use. false = NVIDIA's proprietary module, which
    # drives every card up to and including the RTX 40 series. NVIDIA also
    # ships an open-source kernel module (the userspace stays proprietary
    # either way); the RTX 50 series works ONLY with that one, so a host with
    # such a card must set `hardware.nvidia.open = true` in its own file.
    # Cards older than the GTX 16 / RTX 20 series work only with false.
    open = lib.mkDefault false;

    # Kernel modesetting: required for GNOME on Wayland (GDM falls back to
    # X11 without it) and for a proper console framebuffer.
    modesetting.enable = true;

    # Save and restore video memory across suspend. Without it, resuming
    # from sleep leaves corrupted windows or a black screen on Wayland.
    powerManagement.enable = true;

    # The nvidia-settings control panel.
    nvidiaSettings = true;
  };

  # Early KMS, the counterpart of virtio_gpu on the Parallels guest (see
  # modules/nixos/boot.nix): with the driver in the initrd the Plymouth
  # splash and the LUKS prompt draw on the real card from the start.
  boot.initrd.kernelModules =
    [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
}
