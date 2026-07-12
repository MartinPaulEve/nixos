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
  martin/                  Per-user configuration
    default.nix
    fish.nix               Fish shell + autoloaded functions
    git.nix
    shell.nix              Starship + Atuin
    functions/             Fish functions, linked into ~/.config/fish/functions
```

## Rebuilding

```sh
sudo nixos-rebuild switch --flake ~/nixos#nixos
```

Update inputs with `nix flake update` (commit the resulting `flake.lock`).
