# NixOS configuration

Flake-based NixOS configuration for the host `nixos`. This repository is the
source of truth — rebuild directly from here.

## Layout

```
flake.nix                  Flake inputs (nixpkgs, home-manager, herdr) and outputs
hosts/
  nixos/
    default.nix            Host entry point: hardware scan + host identity
    hardware-configuration.nix
modules/
  nixos/                   System-level modules, aggregated by default.nix
    audio.nix              PipeWire
    boot.nix               Bootloader, kernel, LUKS
    desktop.nix            X11, GNOME, Firefox
    localization.nix       Time zone, locale, console keymap
    networking.nix         NetworkManager, firewall, Tailscale, OpenVPN
    nix.nix                Nix daemon settings, unfree
    packages.nix           System packages + Zotero/LibreOffice integration
    printing.nix           CUPS + Avahi
    security.nix           SSH, 1Password, YubiKey, GnuPG
    users.nix              User accounts and login shell
home/                      Home Manager wiring, attached as a NixOS module
  default.nix              Enables home-manager and attaches per-user config
  martin/                  Per-user configuration
    default.nix
    fish.nix               Fish shell: fastfetch + autoloaded functions
    git.nix
    shell.nix              Starship prompt + Atuin history
    functions/             Fish functions, linked into ~/.config/fish/functions
```

Home Manager is integrated as a NixOS module, so the whole system (including
the per-user environment) is built and switched in one `nixos-rebuild`. The
fish configuration is fully managed here, having replaced an earlier GNU Stow
setup; `home/default.nix` sets `backupFileExtension` and the fish files use
`force = true` so activation cleanly supersedes any leftover stow symlinks.

## Rebuilding

```sh
sudo nixos-rebuild switch --flake ~/nixos#nixos
```

Update inputs with `nix flake update` (commit the resulting `flake.lock`).
