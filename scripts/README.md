# Scripts

Helper commands for managing the two hardware environments this flake builds:
the real system (aarch64, Parallels guest on the Mac) and an x86_64 QEMU test
VM viewable over SPICE. All scripts locate the repository from their own path,
so they work from any checkout location. They are added to `PATH` on NixOS
machines via `environment.shellInit` in `modules/nixos/users.nix` (as
`/home/martin/nixos/scripts`; on other machines, add the checkout's `scripts/`
directory to `PATH` yourself).

## Rebuild commands

| Script | What it does | Where to run it |
|---|---|---|
| `build_aarch64_mac.sh` | `sudo nixos-rebuild switch --flake <repo>#nixos` — rebuilds and activates the real system. Refuses to run on non-aarch64 machines. | The Mac/Parallels NixOS guest |
| `build_x86_vm_spice.sh` | `nix build <repo>#nixosConfigurations.nixos-vm-x86.config.system.build.vm` — builds the test VM runner. Never touches the running system. | Any x86_64 machine with Nix |

## VM lifecycle

The test VM (settings in `modules/nixos/vm.nix`) runs headless; its display is
served over SPICE on `127.0.0.1:5930`. State lives in
`~/.local/state/nixos-vm/` — the disk image (`nixos.qcow2`, delete for a
factory-fresh VM), the QEMU monitor socket, and logs (`vm.log` for QEMU
itself, `console.log` for the guest serial console).

| Script | What it does |
|---|---|
| `vm_start.sh` | Starts the VM in the background (building it first if needed). Refuses to start a second instance. |
| `spice_vm_connect.sh` | Opens `remote-viewer spice://127.0.0.1:5930` on the running VM. Clipboard sharing and window auto-resize work via the SPICE vdagent. |
| `vm_shutdown.sh` | Graceful shutdown: ACPI power-button press via the QEMU monitor, with a kill fallback after 90 s. |

Inside the VM, log in as `martin` with the VM-only password `nixos` (the real
login password is imperative state that does not exist in a fresh VM image).

Typical session:

```
build_x86_vm_spice.sh   # only needed after config changes
vm_start.sh
spice_vm_connect.sh
...
vm_shutdown.sh
```
