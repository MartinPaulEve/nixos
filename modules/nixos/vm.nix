# QEMU VM variant of this system, for testing config changes without touching
# real hardware. Everything in `virtualisation.vmVariant` applies ONLY to the
# VM built by `nixos-rebuild build-vm` (or
# `nix build .#nixosConfigurations.nixos.config.system.build.vm`); the real
# system is unaffected.
#
# Usage:
#   nix build .#nixosConfigurations.nixos.config.system.build.vm
#   ./result/bin/run-nixos-vm &
#   remote-viewer spice://127.0.0.1:5930
#
# The VM runs headless and exposes its display over SPICE on localhost:5930
# (qxl video + vdagent, so clipboard sharing and resolution auto-resize work
# once logged in). State lives in ./nixos.qcow2 next to where the runner is
# invoked; delete that file for a fresh VM.
{ ... }:

{
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192; # MiB
      cores = 8;
      diskSize = 32768; # MiB

      qemu.options = [
        # Headless: the display is served over SPICE rather than a host window,
        # so the VM also runs fine from a session with no GUI (SSH, agents).
        "-display none"
        # virtio-vga rather than qxl: boot.nix already loads virtio_gpu in the
        # initrd for early KMS, so the VM gets the same graphics path.
        "-vga none"
        "-device virtio-vga"
        "-spice port=5930,addr=127.0.0.1,disable-ticketing=on"
        # vdagent channel: clipboard sharing + dynamic resolution in the guest.
        "-device virtio-serial-pci"
        "-chardev spicevmc,id=vdagent,name=vdagent"
        "-device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
      ];
    };

    # Guest-side agent for the SPICE channel declared above.
    services.spice-vdagentd.enable = true;

    # The real machine's login password is imperative state (mutableUsers), so
    # the account would otherwise have no password inside the VM and GDM login
    # would be impossible. VM-only known password: "nixos".
    users.users.martin.initialPassword = "nixos";
  };
}
