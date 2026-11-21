# Scripts

Helper commands for managing the hardware environments this flake builds: the
aarch64 Parallels guest on the Mac, the bare-metal x86_64 machines, and an
x86_64 QEMU test VM viewable over SPICE. All scripts locate the repository from their own path,
so they work from any checkout location. They are added to `PATH` on NixOS
machines via `environment.shellInit` in `modules/nixos/users.nix` (as
`/home/martin/nixos/scripts`; on other machines, add the checkout's `scripts/`
directory to `PATH` yourself).

## Setting up a new machine

| Script | What it does | Where to run it |
|---|---|---|
| `install.sh` | Turns a base NixOS install into this configuration. Asks for the hostname; finds (or regenerates) the hardware scan; detects the processor, graphics card, install release and EFI partition; carries over disk-encryption settings; writes `hosts/<hostname>/`; checks it evaluates; then offers to build, switch and set the `martin` password. Run as `./scripts/install.sh` from the checkout (it is not on `PATH` yet). `--help` lists a flag for every question. See `AMD64.md`. | A new x86_64 machine, once |

## Rebuild commands

| Script | What it does | Where to run it |
|---|---|---|
| `build_aarch64_mac.sh` | `sudo nixos-rebuild switch --flake <repo>#nixos` — rebuilds and activates the Parallels guest. Refuses to run on non-aarch64 machines. | The Mac/Parallels NixOS guest |
| `build_amd64_metal.sh [HOST]` | `sudo nixos-rebuild switch --flake <repo>#<hostname>` — rebuilds and activates the bare-metal machine it is run on. The output is the machine's hostname (its directory under `hosts/`); pass `HOST` to override. Refuses to run on non-x86_64 machines or for a host with no directory. First-time installation is described in `AMD64.md`. | Any bare-metal machine |
| `update.sh` | Pulls security/package updates and rebuilds: `nix flake update nixpkgs home-manager --commit-lock-file`, then this machine's build script (`build_aarch64_mac.sh` or `build_amd64_metal.sh`, chosen by architecture) if the lock moved, then `nix store diff-closures` against the booted system and a reboot hint if the kernel changed. `--all` updates every input, `INPUT...` only the named ones, `--rebuild` forces a rebuild. Refuses to start with uncommitted `flake.lock` changes. | Any real machine |
| `check_hosts.sh` | Evaluates every real host and checks they all still come out as the same packages, home files, user services and settings, apart from the explicit hardware differences listed in `tests/hosts.nix`. Builds nothing; exits non-zero on any mismatch. | Any real machine |
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
