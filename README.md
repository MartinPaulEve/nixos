# NixOS configuration

Flake-based NixOS configuration for the host `nixos`. This repository is the
source of truth — rebuild directly from here.

## Layout

```
flake.nix                  Flake inputs (nixpkgs, home-manager, herdr, worksummary) and outputs
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
    keyd.nix               System-wide key remapping (evdev, Wayland-safe)
    localization.nix       Time zone, locale, console keymap
    networking.nix         NetworkManager, firewall, Tailscale, OpenVPN, NextDNS (DoT)
    nix.nix                Nix daemon settings, unfree
    packages.nix           System packages + Zotero/LibreOffice integration
    plymouth-themes/       Vendored Plymouth boot theme (nixos-mac-style)
    printing.nix           CUPS + Avahi
    security.nix           SSH, 1Password, YubiKey, GnuPG
    users.nix              User accounts, login shell, SSH authorized keys
    virtualisation.nix     Docker
    vm.nix                 QEMU/SPICE test-VM variant (build-vm only; never affects the real system)
home/                      Home Manager wiring, attached as a NixOS module
  default.nix              Enables home-manager and attaches per-user config
  martin/                  Per-user configuration
    default.nix
    avatar.nix             Profile picture (~/.face); image in avatar.jpg
    fish.nix               Fish shell: byobu auto-launch, fastfetch, autoloaded functions
    git.nix                Git config, incl. SSH commit signing via 1Password
    gnome.nix              GNOME settings as declarative dconf
    shell.nix              Starship prompt + Atuin history
    sublime.nix            Sublime Text plugins (Jekyll, MarkdownEditing), pinned
    unison.nix             Unison sync profile
    whipper.nix            Whipper CD ripper package + config
    zotero.nix             Registers the Zotero LibreOffice extension (per-user)
    functions/             Fish functions, linked into ~/.config/fish/functions
    unison/                Unison profile source
    whipper/               Whipper config source
scripts/                   Environment-management commands (on PATH; see scripts/README.md)
  build_aarch64_mac.sh     Rebuild + switch the real system (Mac/Parallels)
  build_x86_vm_spice.sh    Build the x86_64 SPICE test VM
  vm_start.sh              Start the test VM (headless, SPICE on localhost:5930)
  vm_shutdown.sh           Gracefully shut the test VM down
  spice_vm_connect.sh      Open remote-viewer on the running test VM
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
| Development tooling | jdk, uv, bundler, php, composer, subversion, jekyll, commonmeta, commitizen, github-cli, claude-code, codex |
| Web browsers & automation | chromium, puppeteer-cli, chromedriver |
| Networking & VPN | tailscale, tailscale-systray, openvpn3 |
| Security & authentication | 1Password (GUI + CLI), yubikey-manager, yubikey-personalization |
| Office & research | libreoffice-fresh, zotero, pdftk |
| Graphics & media | gimp-with-plugins, vlc, ymuse |
| Communication | signal-desktop, telegram-desktop |
| System & disk utilities | file-roller, gparted, safeeyes |
| Miscellaneous | herdr, worksummary |

Sublime Text is pulled from a dedicated `pkgs` instance that permits the
insecure OpenSSL 1.1 it depends on. The Docker CLI is provided separately by
`virtualisation.nix`. After activation, the Zotero LibreOffice integration
extension is registered automatically.

Sublime Text plugins are pinned declaratively in `home/martin/sublime.nix`
rather than installed at runtime through Package Control: each plugin's release
tarball is fetched by hash and unpacked into `Packages/`, where Sublime loads it
automatically. This installs the Jekyll plugin (pointed at the blog's
`_posts`/`_drafts`/`_templates`) and MarkdownEditing (enhanced markdown editing
with automatic folding of inline link URLs). Because the settings files are
store symlinks, adjust plugin options in the Nix module and rebuild — not
through Sublime's own settings UI.

`commonmeta` (a scholarly-metadata format converter) is not packaged in
nixpkgs, so `packages.nix` builds it from its pinned upstream release with
`buildGoModule`. Its upstream test suite is disabled in the build because it
reaches the network and diffs against live services; on a version bump, reset
`vendorHash` to `lib.fakeHash`, rebuild, and copy the reported hash back.

`programs.nix-ld.enable` is set in `packages.nix` so prebuilt, non-Nix ELF
binaries can find a dynamic loader at the FHS `/lib64/ld-linux` path NixOS
otherwise lacks. `uv` relies on this: the standalone CPython builds it downloads
are dynamically linked for a normal FHS layout and will not run without it.

The browser is Chromium rather than Google Chrome: Google ships no
`aarch64-linux` build of Chrome, and this host is ARM, so `google-chrome`
refuses to evaluate. `allowUnsupportedSystem` does not help — there is no ARM
binary to unpack. `packages.nix` carries a commented-out `google-chrome` line
and the full rationale, for use if this config is ever run on x86_64.

The GNOME dock favourites in `home/martin/gnome.nix` are matched by exact
desktop-entry ID, and GNOME silently drops any entry it cannot resolve — a
wrong ID looks like the app simply refusing to pin. IDs must match the
`.desktop` filename the package actually ships, which is not always the
package name: Chromium installs `chromium-browser.desktop`, not
`chromium.desktop`, and Telegram installs `org.telegram.desktop`. Check with
`ls /run/current-system/sw/share/applications` before adding a favourite.

The user profile picture is tracked as `home/martin/avatar.jpg`. `users.nix`
links it to `/var/lib/AccountsService/icons/martin` *and* writes the
AccountsService state file `/var/lib/AccountsService/users/martin` with a
matching `Icon=` entry. Both are required for the GDM login screen: GDM reads
avatars over D-Bus from AccountsService, which only reports an icon it has
recorded in that state file. The `~/.face` copy installed by
`home/martin/avatar.nix` is not sufficient on its own, because the greeter runs
as the `gdm` user and cannot read the `0700` home directory. Because both paths
are managed declaratively, changing the avatar in GNOME Settings will not
persist — replace `avatar.jpg` and rebuild.

Email is configured in `modules/nixos/email.nix`, which installs Thunderbird
and the Proton Mail bridge. The bridge runs as a per-user systemd service using
the headless `protonmail-bridge` build with `--noninteractive --no-window`,
avoiding the GUI build that otherwise crashes at login.

Boot uses a graphical Plymouth splash (`modules/nixos/boot.nix`), with the
console quietened via `quiet`/`splash` kernel params so the splash shows in
place of kernel logs. The theme is `nixos-mac-style` — a macOS-style
boot animation carrying the NixOS logo — vendored under
`modules/nixos/plymouth-themes/` and packaged locally (its hardcoded `/usr/share`
image path is rewritten to the Nix store), since the upstream download is only a
short-lived signed URL.

For the splash to appear rather than flicker away mid-boot, the real KMS
driver must come up in the initrd *before* Plymouth starts drawing. Otherwise
Plymouth renders on the EFI simple-framebuffer (`simpledrm`) and the actual GPU
driver only loads seconds into stage-2 boot; that framebuffer handoff hides the
splash. `boot.nix` therefore force-loads the driver early via
`boot.initrd.kernelModules`. **This value is machine-specific and must be changed
per host.** The current VM (Parallels on Apple Silicon) uses the paravirtualised
`virtio_gpu`; on other hardware substitute the appropriate driver:

| Hardware | initrd module |
| --- | --- |
| Parallels / QEMU / KVM guest | `virtio_gpu` |
| Intel graphics | `i915` |
| AMD graphics | `amdgpu` |
| NVIDIA (open) | `nouveau` |
| Apple Silicon (bare metal) | `appledrm` / DCP stack |

Leaving `virtio_gpu` in place on bare metal is harmless (it finds no matching
device and no-ops) but provides no early-KMS benefit, so add the real driver
when migrating to physical hardware — the same as regenerating
`hardware-configuration.nix` for the new machine.

[keyd](https://github.com/rvaiya/keyd) (`modules/nixos/keyd.nix`) provides
system-wide key remapping at the evdev level, so it works under Wayland (unlike
the X11-only AutoKey). The `gb(mac)` layout already carries `£` and `#` on the
`3` key (at Shift and AltGr respectively), so keyd remaps the familiar chords
onto those native combinations rather than synthesising Unicode: `Ctrl+Shift+3`
emits `Shift+3` (`£`) and `Ctrl+4` emits `AltGr+3` (`#`).

[worksummary](https://github.com/MartinPaulEve/worksummary) is a self-authored
CLI for logging daily work items. It is consumed as a flake input (built from a
`flake.nix` in its own repo) rather than vendored, so a rebuild always installs
whatever the `flake.lock` pins. Pull the latest release with:

```sh
nix flake update worksummary   # then rebuild
```

Its fish completion ships inside the package (under
`share/fish/vendor_completions.d/`), so fish loads it automatically once the
package is installed — no separate completion wiring required.

Tailscale's node identity lives in `/var/lib/tailscale/tailscaled.state`, not in
this repo — it cannot be expressed declaratively, because the node key is
generated at registration. `nixos-rebuild` preserves that file, so rebuilding
never creates a duplicate node. A fresh install or a recreated VM starts with an
empty `/var`, so `tailscale up` registers a *new* node; the old one still holds
the name, the new one is suffixed (`nixos-1`), and MagicDNS keeps resolving
`nixos` to the stale, offline node — so inbound SSH and ping to it simply hang.

To keep the same identity across a reinstall, preserve and restore that file:

```sh
sudo cp /var/lib/tailscale/tailscaled.state ~/tailscaled.state.bak      # before
sudo install -Dm600 ~/tailscaled.state.bak \
  /var/lib/tailscale/tailscaled.state                                   # after, before `tailscale up`
```

Failing that, delete the stale node in the Tailscale admin console *before*
running `tailscale up`, so the new registration reclaims the name. Disabling key
expiry on the node stops it lapsing while the VM is powered off.

Home Manager is integrated as a NixOS module, so the whole system (including
the per-user environment) is built and switched in one `nixos-rebuild`. The
fish configuration is fully managed here, having replaced an earlier GNU Stow
setup; `home/default.nix` sets `backupFileExtension` and the fish files use
`force = true` so activation cleanly supersedes any leftover stow symlinks.

Interactive fish shells launch byobu automatically (`home/martin/fish.nix`).
The init guards against recursion — byobu starts tmux, whose nested fish has
`$TMUX` set and so skips the re-exec — and against having no controlling tty, so
scp/rsync and editor-embedded shells are left alone.

## Rebuilding

Two hardware environments build from this flake, each with a script in
`scripts/` (on PATH on NixOS machines; see `scripts/README.md`):

The real system — the aarch64 Parallels guest on the Mac:

```sh
build_aarch64_mac.sh        # sudo nixos-rebuild switch --flake ~/nixos#nixos
```

Update inputs with `nix flake update` (commit the resulting `flake.lock`).

## Testing in a VM

The `nixos-vm-x86` flake output rebuilds the same configuration for x86_64 so
config changes can be test-driven in a local QEMU VM on any x86_64 Linux host
with Nix and KVM, before touching the real machine. The VM runs headless with
its display served over SPICE (settings in `modules/nixos/vm.nix`; VM-only
login password `nixos`):

```sh
build_x86_vm_spice.sh       # build the VM runner
vm_start.sh                 # boot it in the background
spice_vm_connect.sh         # view it: remote-viewer spice://127.0.0.1:5930
vm_shutdown.sh              # graceful ACPI power-off
```

None of this affects the real system: the VM variant and the x86_64 output
evaluate separately, and the `nixos` output's derivation is unchanged by them.
