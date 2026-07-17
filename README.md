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
    boot.nix               Bootloader, kernel, LUKS, Plymouth splash
    desktop.nix            X11, GNOME, GNOME Tweaks, Firefox
    email.nix              Thunderbird + Proton Mail bridge (headless service)
    fonts.nix              System fonts, incl. Nerd Fonts
    localization.nix       Time zone, locale, console keymap
    networking.nix         NetworkManager, firewall, Tailscale, OpenVPN
    nix.nix                Nix daemon settings, unfree
    packages.nix           System packages + Zotero/LibreOffice integration
    printing.nix           CUPS + Avahi
    security.nix           SSH, 1Password, YubiKey, GnuPG
    users.nix              User accounts and login shell
    virtualisation.nix     Docker
home/                      Home Manager wiring, attached as a NixOS module
  default.nix              Enables home-manager and attaches per-user config
  martin/                  Per-user configuration
    default.nix
    fish.nix               Fish shell: fastfetch + autoloaded functions
    git.nix                Git config, incl. SSH commit signing via 1Password
    gnome.nix              GNOME settings as declarative dconf
    shell.nix              Starship prompt + Atuin history
    unison.nix             Unison sync profile
    whipper.nix            Whipper CD ripper package + config
    functions/             Fish functions, linked into ~/.config/fish/functions
    unison/                Unison profile source
    whipper/               Whipper config source
```

## Packages

System-wide packages live in `modules/nixos/packages.nix`, grouped by
function:

| Category | Packages |
| --- | --- |
| Core CLI utilities | wget, curl, nano, net-tools, expect |
| Terminal / shell | eza, btop, zellij, fastfetch |
| File sync & dotfiles | rsync, unison, stow |
| Editors & IDEs | JetBrains PyCharm / PhpStorm / WebStorm, Sublime Text |
| Development tooling | jdk, uv, bundler, jekyll, commitizen, github-cli, claude-code |
| Web browsers & automation | chromium, puppeteer-cli |
| Networking & VPN | tailscale, tailscale-systray, openvpn3 |
| Security & authentication | 1Password (GUI + CLI), yubikey-manager, yubikey-personalization |
| Office & research | libreoffice-fresh, zotero, pdftk |
| Graphics & media | gimp-with-plugins, vlc, ymuse |
| Communication | signal-desktop, telegram-desktop |
| System & disk utilities | gparted, safeeyes |
| Miscellaneous | herdr |

Sublime Text is pulled from a dedicated `pkgs` instance that permits the
insecure OpenSSL 1.1 it depends on. The Docker CLI is provided separately by
`virtualisation.nix`. After activation, the Zotero LibreOffice integration
extension is registered automatically.

Email is configured in `modules/nixos/email.nix`, which installs Thunderbird
and the Proton Mail bridge. The bridge runs as a per-user systemd service using
the headless `protonmail-bridge` build with `--noninteractive --no-window`,
avoiding the GUI build that otherwise crashes at login.

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
