# Running this configuration on a bare-metal AMD machine

This repository now builds two real machines from one set of modules:

| Flake output | Machine | Architecture | Rebuild with |
| --- | --- | --- | --- |
| `nixos` | Parallels guest on the Mac | aarch64 | `build_aarch64_mac.sh` |
| `nixos-amd64` | Bare-metal AMD desktop/laptop | x86_64 | `build_amd64_metal.sh` |

Both import the same `modules/nixos` and the same `home/`, so they get the same
packages and the same home directory configuration. Anything that only makes
sense on one of them is gated, and a set of checks (`check_hosts.sh`) fails if
the two drift apart.

## Status: what has and has not been verified

Everything below was done from the Parallels guest. Nothing has been built or
booted on AMD hardware yet.

- **Verified.** The `nixos-amd64` system evaluates completely, so every
  package in the configuration exists for x86_64. The third-party flake inputs
  (`claude-code`, `herdr`, `worksummary`) all publish x86_64 packages. The
  x86_64 Holos AppImage hash in `packages.nix` matches the file upstream
  serves today. All 46 parity checks pass.
- **Verified.** The Parallels guest is unchanged. Comparing the `nixos` system
  derivation before and after this work, the only difference is the path of
  the repository source itself; no package, unit, file or setting changed.
- **Not verified.** That the system builds and boots on the real machine. A
  dry run shows about 2,900 paths coming from the binary cache (8.8 GiB) and
  about 1,100 small local derivations (wrappers, config files, unit files).
  The only real compilation is the same as on the guest: `herdr` (Rust),
  `commonmeta` (Go) and the Jekyll gems.
- **Placeholder.** `hosts/nixos-amd64/hardware-configuration.nix` is a
  stand-in, because the real one can only be generated on the machine. See the
  install steps.

## What changed in the repository

### New

- `hosts/nixos-amd64/default.nix` is the host entry point. It sets the
  hostname and the things real AMD hardware needs:
  - AMD CPU microcode updates.
  - Redistributable firmware (Radeon graphics, Wi-Fi and Bluetooth chips).
  - The `kvm-amd` module, so the QEMU test VM runs accelerated.
  - Early KMS for Radeon graphics (`hardware.amdgpu.initrd.enable`), so the
    Plymouth splash appears properly. This is the counterpart of `virtio_gpu`
    on the guest.
  - `fwupd`, for firmware updates to the board, SSD and peripherals.
- `hosts/nixos-amd64/hardware-configuration.nix` is the placeholder hardware
  scan. It mounts root and `/boot` by filesystem label (`nixos` and `boot`).
- `flake.nix` gains the `nixos-amd64` output.
- `scripts/build_amd64_metal.sh` rebuilds and switches the bare-metal machine.
  It refuses to run on anything but x86_64.
- `tests/hosts.nix` and `scripts/check_hosts.sh` are the parity checks.

### Changed so that Parallels-only settings stay on Parallels

| File | Before | Now |
| --- | --- | --- |
| `modules/nixos/boot.nix` | Loaded `virtio_gpu` in the initrd on every host | Driver is chosen per host: `virtio_gpu` in `hosts/nixos` and in the test VM (`vm.nix`), `amdgpu` in `hosts/nixos-amd64` |
| `home/martin/gnome.nix` | Pinned `~/.config/monitors.xml` to the virtual 1440x900 display everywhere | Only on the Parallels guest and the test VM |
| `home/martin/obsidian.nix` | Vault path fixed at the Parallels share | Share path on the guest; `~/Documents/Programming/MESH/commons-docs` elsewhere |
| `scripts/update.sh` | Always called `build_aarch64_mac.sh` | Calls the build script for the machine's architecture |

The `monitors.xml` change matters more than it looks. On real hardware GNOME
writes your actual monitor layout to that file. Left as a read-only link, the
first change in Settings → Displays would replace it, and the next rebuild
would collide with Home Manager's backup of it.

### Already gated correctly, left alone

These were already conditional on `hardware.parallels.enable` or on the
architecture, and need no change:

- `modules/nixos/power.nix`: Parallels printing-daemon mask, file indexer off,
  powertop.
- `modules/nixos/shutdown.nix`: the `prlcc` stop timeout.
- `home/martin/ghostty.nix`: the software-OpenGL wrapper. On AMD, ghostty is
  the stock package on the real GPU.
- `home/martin/mac-folders.nix`: the symlinks onto the Mac's folders.
- `home/martin/transcribe-client.nix`: the voice client that talks to the Mac.
- `modules/nixos/packages.nix`: Tor Browser (stable release on x86_64, nightly
  ARM build on the guest) and Holos (per-architecture AppImage).

## How the two machines differ

This is the complete list. The checks in `tests/hosts.nix` fail if anything
else differs in packages, fonts, home files, user services, dconf settings,
groups, locale, keyboard, firewall or PAM settings.

| Area | Parallels guest | Bare-metal AMD |
| --- | --- | --- |
| Hostname | `nixos` | `nixos-amd64` |
| Guest tools | `prl-tools`, `prltoolsd` | none |
| Clock | kept by the Mac host | `systemd-timesyncd` |
| File indexer (`localsearch`) | off | on (stock GNOME) |
| `powertop` auto-tuning | on | off |
| Firmware updates (`fwupd`) | off | on |
| ghostty rendering | software OpenGL wrapper | real GPU |
| `~/.config/monitors.xml` | pinned to 1440x900 | owned by GNOME |
| Mac folder symlinks | `~/Documents` etc. link to the Mac | ordinary local folders |
| Voice transcription client | autostarts | not started (no Mac host to talk to) |
| Tor Browser | nightly ARM build | stable release from nixpkgs |

The hostname differs on purpose. It is the machine's name on the tailnet and
its device label in NextDNS, so two machines called `nixos` would be
indistinguishable in both. To change it, edit `networking.hostName` in
`hosts/nixos-amd64/default.nix`; if you rename the flake output to match,
update `build_amd64_metal.sh` and `tests/hosts.nix` too.

## Installing on the AMD machine

1. **Firmware settings.** Boot in UEFI mode with Secure Boot off. The
   configuration uses systemd-boot, which is unsigned.
2. **Boot the NixOS 26.05 x86_64 installer** and get online.
3. **Partition and format.** At minimum an EFI system partition (1 GiB is
   comfortable) and a root partition, mounted at `/mnt` and `/mnt/boot`:

   ```sh
   mkfs.fat -F 32 -n boot /dev/<esp>
   mkfs.ext4 -L nixos /dev/<root>
   mount /dev/disk/by-label/nixos /mnt
   mount --mkdir -o umask=077 /dev/disk/by-label/boot /mnt/boot
   ```

   Disk encryption and swap are your choice here. If you set up LUKS or a
   swap partition, the next step records them.
4. **Put the repository at `/mnt/home/martin/nixos`.** The path matters:
   `users.nix` puts `/home/martin/nixos/scripts` on `PATH`.

   ```sh
   nix-shell -p git
   git clone <this repository> /mnt/home/martin/nixos
   cd /mnt/home/martin/nixos
   ```
5. **Replace the placeholder hardware scan** with the real one:

   ```sh
   nixos-generate-config --root /mnt --show-hardware-config \
     > hosts/nixos-amd64/hardware-configuration.nix
   ```

   This records the real disk UUIDs, any LUKS device, swap and the initrd
   storage modules. Commit it later from the installed system.
6. **Install:**

   ```sh
   nixos-install --flake /mnt/home/martin/nixos#nixos-amd64
   ```
7. **Set your login password.** It is not in the repository, so the account
   has none after installation and GDM would refuse the login:

   ```sh
   nixos-enter --root /mnt -c 'passwd martin'
   chown -R 1000:100 /mnt/home/martin
   ```
8. **Reboot.** From then on, rebuild with `build_amd64_metal.sh` and update
   with `update.sh`.

## State the repository does not carry

The configuration is identical, but these live outside it and have to be set
up again or copied from the guest:

- **Your files.** On the guest, `~/Documents`, `~/Downloads`, `~/Desktop` and
  `~/Dropbox` are the Mac's folders. On the AMD machine they are empty local
  folders. `~/Programming` (the blog checkout Sublime's Jekyll plugin uses,
  among others) and `~/dotfiles` are local to the guest and need copying. The
  unison profile (`unison`) can pull the `Documents` subtrees and the fish
  config from `statler`.
- **Bitwarden.** Log in to the desktop app, enable its SSH agent in Settings,
  and run `bw login` once. Git commit signing and the sshfs mounts depend on
  it (see `home/martin/bitwarden.nix`).
- **Tailscale.** `sudo tailscale up`. The NAS mounts resolve over MagicDNS.
- **YubiKey login.** Copy `~/.config/Yubico/u2f_keys` if you have enrolled a
  key, or enrol on the new machine with `pamu2fcfg`. Existing enrolments
  stay valid because the PAM origin is pinned to `pam://nixos` rather than
  derived from the hostname. GnuPG keys in `~/.gnupg` need copying too.
- **Application logins and profiles.** 1Password, Firefox, Thunderbird, the
  Proton Mail bridge, Signal, Telegram, Zotero, the JetBrains IDEs, Sublime's
  licence, `gh auth login`, `aws configure`, atuin, Claude Code.
- **espanso.** Its config and user unit are still set up by hand from
  `~/dotfiles`, as the comment in `modules/nixos/espanso.nix` says. Only the
  device access is declarative.
- **Architecture-specific caches.** Docker images, `uv`-managed Pythons and
  virtualenvs are ARM builds on the guest. Recreate them; do not copy them.
- **SSH host keys.** The new machine generates its own, so other machines
  will see it as a new host.

## Decisions I left for you

I kept these identical to the guest, as asked, but each is a place where the
AMD machine might reasonably want something different.

1. **Keyboard layout.** The system uses the `gb` layout with the `mac`
   variant, and `keyd.nix` remaps `£` and `#` on that assumption. With an
   Apple keyboard on the AMD machine this is right. With a PC keyboard, `@`,
   `"`, `#` and `\` will be in the wrong places, and the layout wants
   overriding for that host in three places: `services.xserver.xkb` in
   `desktop.nix`, the `gb+mac` input source in `gnome.nix`, and the keyd
   chords.
2. **Graphics card.** The host assumes Radeon graphics, integrated or
   discrete. With an NVIDIA card it still boots (on `nouveau`), but you
   would want `services.xserver.videoDrivers = [ "nvidia" ]` and the
   `hardware.nvidia` options in `hosts/nixos-amd64/default.nix`, and to drop
   the `amdgpu` line.
3. **Chrome.** `packages.nix` installs Chromium because Google ships no ARM
   Linux build of Chrome, and its comment suggests swapping to
   `google-chrome` on x86_64. I left Chromium on both so the package set and
   the dock favourites stay the same. Swapping means making the package and
   the `chromium-browser.desktop` favourite in `gnome.nix` conditional on the
   architecture.
4. **Voice transcription.** The system-side pieces (ydotool, wl-clipboard,
   the `input` group) are installed on both machines, but the client only
   runs on the guest because it sends audio work to the Mac. Running it on
   the AMD machine needs a decision about where transcription happens.
5. **CD ripping.** `whipper.conf` holds the read offset calibrated for the
   ASUS SDRW-08D2S-U drive. A different drive needs its own entry added to
   `home/martin/whipper/whipper.conf`.
6. **Laptop or desktop.** GNOME's `power-profiles-daemon` is on by default,
   which suits both. Nothing laptop-specific (lid, battery thresholds) is
   configured.

## Keeping the two in step

Run `check_hosts.sh` on either machine after any change that might be
hardware-specific. It evaluates both hosts without building anything and
prints one line per check. When a difference between the machines is
intended, add it to the short allow-lists at the top of `tests/hosts.nix`, so
the list of differences stays explicit.

For a new hardware-specific setting, follow the existing pattern:

- Something Parallels needs: gate it on `config.hardware.parallels.enable`
  (`osConfig.hardware.parallels.enable` in Home Manager modules).
- Something only real AMD hardware needs: put it in
  `hosts/nixos-amd64/default.nix`.
- A package that differs by architecture: branch on
  `pkgs.stdenv.hostPlatform.isx86_64`, as Tor Browser and Holos do.
