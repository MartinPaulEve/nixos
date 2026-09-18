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
    espanso.nix            uinput access for espanso's Wayland EVDEV injection
    fonts.nix              System fonts, incl. Nerd Fonts
    keyd.nix               System-wide key remapping (evdev, Wayland-safe)
    localization.nix       Time zone, locale, console keymap
    mounts.nix             Boot-time creation of ~/mounts sshfs mountpoints (tmpfiles)
    networking.nix         NetworkManager, firewall, Tailscale, OpenVPN, NextDNS (DoT)
    nix.nix                Nix daemon settings, unfree
    packages.nix           System packages + Zotero/LibreOffice integration
    plymouth-themes/       Vendored Plymouth boot theme (nixos-mac-style)
    power.nix              Battery/power tuning for the Parallels guest
    printing.nix           CUPS + Avahi
    security.nix           SSH, 1Password, YubiKey, GnuPG
    shutdown.nix           Shutdown latency fixes (caps user-service stop timeouts)
    transcribe-client.nix  Runtime deps for the mpe-transcribe voice client
    users.nix              User accounts, login shell, SSH authorized keys
    virtualisation.nix     Docker
    vm.nix                 QEMU/SPICE test-VM variant (build-vm only; never affects the real system)
home/                      Home Manager wiring, attached as a NixOS module
  default.nix              Enables home-manager and attaches per-user config
  martin/                  Per-user configuration
    default.nix
    avatar.nix             Profile picture (~/.face); image in avatar.jpg
    bitwarden.nix          Bitwarden notes only: the app manages its own autostart (a declarative entry breaks it)
    byobu.nix              Byobu backend configuration
    fish.nix               Fish shell: byobu auto-launch, fastfetch, autoloaded functions
    git.nix                Git config, incl. SSH commit signing via the Bitwarden SSH agent
    gnome.nix              GNOME settings as declarative dconf
    mac-folders.nix        Maps the macOS host's Parallels-shared folders into $HOME
    moji.nix               Sets Moji as the default Markdown opener (via xdg-mime, not xdg.mimeApps)
    mounts.nix             sshfs mounts under ~/mounts (systemd user services) + sshmount/sshumount helpers
    music.nix              Music tagging: beets (declarative config) + EasyTAG
    obsidian.nix           Pinned Obsidian community plugins for the commons-docs vault
    remmina.nix            Pins Remmina's self-created autostart entry to Hidden=true
    shell.nix              Starship prompt + Atuin history
    ssh.nix                OpenSSH client config + public keys (verbatim from ssh/)
    sublime.nix            Sublime Text plugins (Jekyll, MarkdownEditing), pinned
    transcribe-client.nix  Autostarts the mpe-transcribe voice client (ARM Parallels guest only)
    unison.nix             Unison sync profile
    whipper.nix            Whipper CD ripper package + config
    zotero.nix             Registers the Zotero LibreOffice extension (per-user)
    functions/             Fish functions, linked into ~/.config/fish/functions
    gnome/                 GNOME assets (monitors.xml display layout)
    ssh/                   ~/.ssh/config source and public keys (secrets stay in the Bitwarden agent)
    sublime/               Sublime User files (Jekyll front-matter override plugin)
    transcribe/            transcribe.toml for the voice-transcription client
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
| Userspace filesystem mounts | sshfs, fuse |
| Core CLI utilities | wget, curl, nano, jq, net-tools, expect, libargon2 |
| Terminal / shell | eza, btop, zellij, fastfetch, byobu, tmux |
| File sync & dotfiles | rsync, unison, stow |
| Editors & IDEs | JetBrains PyCharm / PhpStorm / WebStorm, Sublime Text, Obsidian, Moji |
| Development tooling | jdk, uv, bundler, php, composer, subversion, jekyll, imagemagick, exiftool, commonmeta, sequoia-cli, commitizen, github-cli, claude-code, codex |
| Build toolchain & C libraries | gcc, gnumake, binutils, cmake, ninja, meson, autoconf, automake, libtool, m4, patch, pkg-config, libmysqlclient, mariadb (+ connector headers), postgresql |
| Web browsers & automation | chromium, tor-browser, puppeteer-cli, chromedriver |
| Networking & VPN | tailscale, tailscale-systray, openvpn3, tcpdump |
| Security & authentication | 1Password (GUI + CLI), Bitwarden (GUI + CLI), yubikey-manager, yubikey-personalization |
| Office & research | libreoffice-fresh, zotero, pdftk |
| Graphics & media | audacity, gimp-with-plugins, rhythmbox, vlc, ymuse, yt-dlp |
| Communication | signal-desktop, telegram-desktop, holos |
| System & disk utilities | libnotify, xclip, file-roller, gparted, safeeyes, remmina |
| Miscellaneous | herdr, worksummary |

Sublime Text and the Bitwarden desktop app are pulled from a dedicated `pkgs`
instance that permits the insecure packages they depend on (OpenSSL 1.1 and an
end-of-life Electron respectively), scoped so the exceptions never apply to
the rest of the system; on a nixpkgs bump, check whether `bitwarden-desktop`
has moved to a supported Electron and drop its entry. Hydra does not build
insecure-marked packages, so `bitwarden-desktop` is compiled locally on first
rebuild (its Electron is the repackaged official binary, so this is the app
build only, not a Chromium build). The Docker CLI is
provided separately by `virtualisation.nix`. After activation, the Zotero
LibreOffice integration extension is registered automatically.

Rhythmbox's plugin set is pinned declaratively (dconf, in
`home/martin/gnome.nix`) rather than left to the app: Rhythmbox normally
enables its default plugins only on "first sight" of each one, which is
fragile once per-user state exists. The pinned set is the stock defaults plus
the point of the exercise, `audioscrobbler` — the Last.fm/Libre.fm scrobbling
plugin — so Last.fm support is always available under Preferences → Plugins.
The Last.fm account login itself is interactive (the plugin's preferences
pane) and its session key is per-user state outside this repo.

No OpenPGP packages appear in the list because the stack is assembled
elsewhere: `programs.gnupg.agent` in `modules/nixos/security.nix` installs
GnuPG itself and runs `gpg-agent`, which doubles as the SSH agent; GNOME's
desktop module supplies `pinentry-gnome3` for passphrase prompts; and `pcscd`
(also `security.nix`) provides the smartcard access used for OpenPGP keys on a
YubiKey. (`gpa` was tried as a graphical front-end and removed again — it
crashes at startup on this system.)

Sublime Text plugins are pinned declaratively in `home/martin/sublime.nix`
rather than installed at runtime through Package Control: each plugin's release
tarball is fetched by hash and unpacked into `Packages/`, where Sublime loads it
automatically. This installs the Jekyll plugin (pointed at the blog's
`_posts`/`_drafts`/`_templates`) and MarkdownEditing (enhanced markdown editing
with automatic folding of inline link URLs). Because the settings files are
store symlinks, adjust plugin options in the Nix module and rebuild — not
through Sublime's own settings UI.

The Jekyll plugin's new-post/new-draft front matter is customised by
`home/martin/sublime/jekyll_eve_frontmatter.py`, installed into
`Packages/User/` (which Sublime loads last, so its re-registered commands
replace the stock ones without touching the plugin itself). New posts get a
quoted title, today's date, a DOI minted at creation time via `commonmeta
encode`, and the eve.gd image placeholder block. The README installed
alongside it documents the details.

`commonmeta` (a scholarly-metadata format converter) is not packaged in
nixpkgs, so `packages.nix` builds it from its pinned upstream release with
`buildGoModule`. Its upstream test suite is disabled in the build because it
reaches the network and diffs against live services; on a version bump, reset
`vendorHash` to `lib.fakeHash`, rebuild, and copy the reported hash back.

`sequoia-cli` (publishes blog posts to the AT Protocol) is likewise absent from
nixpkgs. It is distributed only on npm, but the published tarball is a single
self-contained `bun build` bundle, so `packages.nix` just fetches it by hash and
wraps it with node — no npm install step. On a version bump, update the version
and hash (`nix store prefetch-file <tarball-url>`).

`holos` (the desktop client for holos.social) is also not in nixpkgs — the
nixpkgs attribute of that name is the unrelated holos.run platform CLI.
Upstream ships prebuilt binaries only, with separate builds per architecture,
so `packages.nix` fetches the matching official AppImage (x64 on the
bare-metal amd64 host, arm64 on the aarch64 VM) and wraps it with
`appimageTools.wrapType2`, copying the desktop entry and icon out of the image
so GNOME can launch it. On a version bump, update the version and both hashes
(`nix store prefetch-file <url>`).

`programs.nix-ld.enable` is set in `packages.nix` so prebuilt, non-Nix ELF
binaries can find a dynamic loader at the FHS `/lib64/ld-linux` path NixOS
otherwise lacks. `uv` relies on this: the standalone CPython builds it downloads
are dynamically linked for a normal FHS layout and will not run without it.

The browser is Chromium rather than Google Chrome: Google ships no
`aarch64-linux` build of Chrome, and this host is ARM, so `google-chrome`
refuses to evaluate. `allowUnsupportedSystem` does not help — there is no ARM
binary to unpack. `packages.nix` carries a commented-out `google-chrome` line
and the full rationale, for use if this config is ever run on x86_64.

Tor Browser has a similar ARM problem: upstream ships stable binaries only for
x86_64/i686 Linux. Rather than emulating the x86_64 build (tried; unusably
slow), `packages.nix` overrides the nixpkgs derivation on aarch64 to swap in
the Tor Project's official *nightly* aarch64 tarball, keeping the rest of the
packaging intact; x86_64 hosts get plain `pkgs.tor-browser`. Nightly date
directories eventually rotate off the server, so the pinned URL goes stale —
the comment in `packages.nix` explains how to bump it (and warns that the
local network filter blocks `*.torproject.org`, so downloading needs an
unfiltered route).

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

`modules/nixos/transcribe-client.nix` carries the runtime dependencies for the
mpe-transcribe voice-transcription client: `wl-clipboard` (Wayland clipboard
get/set), `programs.ydotool.enable` (the `ydotoold` daemon that synthesises the
Ctrl+V paste), and membership of the `input` and `ydotool` groups so the evdev
hotkey listener can read `/dev/input/event*` and reach the ydotoold socket.
Recording and transcription happen on the Mac host over encrypted UDP. Group
changes only apply to fresh sessions, so a re-login is needed after first
activation. For X11/XWayland apps the clipboard CLI is `xclip` (in
`packages.nix`); Wayland-native use goes through `wl-copy`/`wl-paste`.

The client itself is autostarted by `home/martin/transcribe-client.nix` as a
systemd user service tied to the graphical session, gated (like
`mac-folders.nix`) to the aarch64 Parallels guest. On first start it clones
the app from the Parallels share into `~/.local/share/mpe-transcribe` — its
own clone, because the share's `.venv` can only serve one OS and this VM's
config differs from the Mac's — and `uv run` builds the venv from there
(update later with `git -C ~/.local/share/mpe-transcribe pull`). The client
config, `home/martin/transcribe/transcribe.toml` (client mode, the Mac's
address, hotkey, corrections), is linked into the clone root where the app
looks for it; the pre-shared key stays out of the repo in
`~/.config/transcribe/psk`, referenced from the toml by path. The checkout in
`~/src/mpe-transcribe` remains a scratch clone for interactive use and is not
managed here.

`modules/nixos/espanso.nix` grants the device access espanso's Wayland EVDEV
backend needs: reading keyboards comes from the `input` group above, and
injection requires opening `/dev/uinput`, enabled via `hardware.uinput` plus
the `uinput` group. Without the uinput half espanso crash-loops, briefly
flashing its layout-detection window at every restart. The espanso app and
config themselves are still imperative (stowed dotfiles and a hand-registered
systemd user unit), pending the Home Manager migration.

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

## Remote sshfs mounts

Remote filesystems are mounted over sshfs under `~/mounts`, defined in
`home/martin/mounts.nix`:

| Unit | Remote | Mountpoint | At login? |
| --- | --- | --- | --- |
| `sshfs-waldorf` | `martin@waldorf:/home/martin` | `~/mounts/waldorf` | yes |
| `sshfs-lg1` | `bw://sshmount-lg1` | `~/mounts/lg1` | no |
| `sshfs-lg2` | `bw://sshmount-lg2` | `~/mounts/lg2` | no |
| `sshfs-sm_mount` | `bw://sshmount-sm_mount` | `~/mounts/sm_mount` | no |
| `sshfs-ia` | `backup:/interneta` | `~/mounts/ia` | no |

The `bw://` remotes are Bitwarden secure-note references: `sshmount`
resolves every one in a single `bw unlock` (one master-password prompt per
session) into a tmpfs cache wiped at logout, so the real `host:path` values
never appear in this repo. Each referenced item is a Secure Note whose body
is the literal `host:path`; the CLI needs a one-time `bw login`, and a
`bw sync` after a note changes. Because `bw` can only unlock interactively,
starting a `bw://` unit directly with systemctl before `sshmount` has filled
the cache fails (and retries) rather than prompting. The NAS paths
(including `ia`'s) are relative to the Synology SFTP chroot, which exposes
DSM shared folders at `/` rather than the real filesystem — `/volumeX`
paths do not exist over SFTP.

Each mount is a systemd *user* service running sshfs as martin. The waldorf
mount starts with the graphical session; the NAS mounts never start on their
own and are mounted on demand, without root, via the `sshmount`/`sshumount`
helpers (generated in `home/martin/mounts.nix` from the same mount list, so
they cannot drift; plain `systemctl --user start/stop sshfs-<name>` works
too). An argument may be a bare mount name or any path ending in one:

```sh
sshmount lg1              # mount one
sshmount ~/mounts/lg1     # same
sshmount                      # mount everything
sshumount lg1             # unmount one
sshumount                     # unmount everything
```

`sshmount` waits up to ten seconds for the mounts to appear and then reports
per mount; anything not yet connected keeps retrying inside its unit.
`sshumount` stops the unit (which also halts a still-retrying one) and falls
back to `fusermount3 -uz` for a mount made by hand.

They are deliberately *not* fstab entries (`fileSystems` with `noauto,user`):
a user-invoked fstab mount runs the FUSE helper — and therefore ssh — as
root, and authentication here comes from martin's Bitwarden SSH agent, whose
socket is user-owned and only serves same-user clients in the desktop
session. Running sshfs as martin instead needs no root at any point (FUSE's
setuid `fusermount3` wrapper does the privileged part) and picks up the agent
naturally. The corollary is that mounting requires Bitwarden to be running
and unlocked; an attempt made while it is locked fails quietly and the unit
retries every 15 s (`BatchMode=yes` stops ssh falling back to an interactive
password prompt). Because they are user services started after
`graphical-session.target`, an unreachable host can never hang boot or login.

The mountpoints themselves are created at every boot, owned by martin, by
systemd-tmpfiles rules in `modules/nixos/mounts.nix`, which mirrors the mount
list in `home/martin/mounts.nix` — keep the two in sync when adding a mount
(drift is non-fatal: each service also `mkdir -p`'s its own mountpoint). The
NAS hostnames resolve over Tailscale MagicDNS, so the tailnet must be up for
those mounts to connect.

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
