# Running this configuration on a bare-metal AMD machine

This repository builds any number of real machines from one set of modules.
Each machine is a directory under `hosts/`, and the directory's name is the
machine's hostname:

| Host directory | Machine | Architecture | Rebuild with |
| --- | --- | --- | --- |
| `hosts/nixos` | Parallels guest on the Mac | aarch64 | `build_aarch64_mac.sh` |
| `hosts/nixos-amd64` | Bare metal, AMD CPU, NVIDIA card | x86_64 | `build_amd64_metal.sh` |
| `hosts/<your-name>` | Any further machine (see below) | x86_64 | `build_amd64_metal.sh` |

Every host gets the same `modules/nixos` and the same `home/`, so they all
have the same packages and the same home directory configuration. Anything
that only makes sense on one kind of hardware is gated, and a set of checks
(`check_hosts.sh`) fails if any host drifts from the others.

## Status: what has and has not been verified

Everything below was done from the Parallels guest. Nothing has been built or
booted on AMD hardware yet.

- **Verified.** The `nixos-amd64` system evaluates completely, so every
  package in the configuration exists for x86_64. The third-party flake inputs
  (`claude-code`, `herdr`, `worksummary`) all publish x86_64 packages. The
  x86_64 Holos AppImage hash in `packages.nix` matches the file upstream
  serves today. The NVIDIA driver (595.71.05) is not marked broken for the
  configured kernel (7.3.4). All parity checks pass, and a throwaway second
  host directory was picked up and passed the same checks with no other edits.
- **Verified.** The Parallels guest is unchanged. Comparing the `nixos` system
  derivation before and after this work, the only difference is the path of
  the repository source itself; no package, unit, file or setting changed.
- **Not verified.** That the system builds and boots on the real machine. A
  dry run shows about 2,900 paths coming from the binary cache (8.8 GiB) and
  about 1,100 small local derivations (wrappers, config files, unit files).
  The real compilation is `herdr` (Rust), `commonmeta` (Go) and the Jekyll
  gems, as on the guest, plus the NVIDIA kernel module, which is unfree and
  so never in the binary cache. It compiles in a few minutes and again on
  every kernel update.
- **Verified.** `scripts/install.sh` is covered by `tests/install_test.sh`,
  which runs it against fake machines (AMD and Intel, NVIDIA and Radeon,
  encrypted disks, small and oddly mounted EFI partitions) and checks what the
  resulting host evaluates to. Its interactive prompts were exercised by hand.
- **Not verified.** The script's final build-and-switch step, which needs a
  real machine. That includes `--install-bootloader` on the first switch,
  added after `animal` was found booting a stale GRUB menu (see "Installing
  on a machine").
- **Verified on `animal`** (AMD CPU, RTX 50-series card, dual boot with
  Windows and Ubuntu): the system builds with GRUB as its bootloader, with
  the same firmware entry (`NixOS-boot`) the base install registered, and the
  installer detects GRUB there from the kernel command line.
- **Placeholder.** `hosts/nixos-amd64/hardware-configuration.nix` is a
  stand-in. Real machines get their own host directory from `install.sh`.

## What changed in the repository

### New

- `hosts/nixos-amd64/` is the first bare-metal host. Its `default.nix` only
  picks hardware profiles and records the install release.
- `modules/hardware/amd.nix` is the AMD processor profile: CPU microcode,
  redistributable firmware (Wi-Fi, Bluetooth), the `kvm-amd` module so the
  QEMU test VM runs accelerated, and `fwupd` for firmware updates.
- `modules/hardware/intel.nix` is the same for an Intel processor, so the
  installer has a profile for either.
- `modules/hardware/grub.nix` is the GRUB profile, for a machine that shares
  its disks with other operating systems: GRUB installed as an EFI program,
  `os-prober` adding the other systems to its menu, and the same ten-entry
  limit as systemd-boot. A host that imports it boots with GRUB instead of
  the shared default.
- `scripts/install.sh` sets a machine up from a base NixOS install; see
  "Installing on a machine". `tests/install_test.sh` tests it.
- `modules/hardware/nvidia.nix` is the NVIDIA profile: NVIDIA's own driver,
  kernel modesetting (GNOME on Wayland needs it), video-memory save and
  restore across suspend, the `nvidia-settings` panel, and the driver loaded
  in the initrd so the Plymouth splash draws on the card from the start. The
  `nouveau` driver is blacklisted automatically.
- `hosts/nixos-amd64/hardware-configuration.nix` is the placeholder hardware
  scan. It mounts root and `/boot` by filesystem label (`nixos` and `boot`).
- `flake.nix` now turns every directory under `hosts/` into a flake output
  and sets its hostname from the directory name.
- `home/martin/browser.nix` declares Firefox as the default browser.
- `scripts/build_amd64_metal.sh` rebuilds and switches whichever bare-metal
  machine it is run on. It refuses to run on anything but x86_64.
- `tests/hosts.nix` and `scripts/check_hosts.sh` are the parity checks.

### Changed so that Parallels-only settings stay on Parallels

| File | Before | Now |
| --- | --- | --- |
| `modules/nixos/boot.nix` | Loaded `virtio_gpu` in the initrd on every host | Driver is chosen per host: `virtio_gpu` in `hosts/nixos` and in the test VM (`vm.nix`), the NVIDIA modules via `modules/hardware/nvidia.nix` |
| `hosts/nixos/default.nix` | Imported the shared modules and set the hostname itself | Hardware only; `flake.nix` supplies the shared modules and the hostname for every host |
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

## How the guest and a bare-metal host differ

This is the complete list. The checks in `tests/hosts.nix` fail if anything
else differs in packages, fonts, home files, user services, dconf settings,
groups, locale, keyboard, firewall or PAM settings.

| Area | Parallels guest | Bare-metal AMD |
| --- | --- | --- |
| Hostname | `nixos` | the host directory's name |
| Guest tools | `prl-tools`, `prltoolsd` | none |
| Graphics driver | `virtio_gpu` | NVIDIA (`nvidia-x11`, `nvidia-settings`, suspend units, `acpid`) |
| Clock | kept by the Mac host | `systemd-timesyncd` |
| Bootloader | systemd-boot | systemd-boot, or GRUB on a host that imports `grub.nix` |
| Filesystem tools | for the guest's ext4 disk | for the machine's own filesystems (`btrfs-progs` on btrfs, …) |
| CPU microcode, device firmware | none | AMD microcode, redistributable firmware |
| File indexer (`localsearch`) | off | on (stock GNOME) |
| `powertop` auto-tuning | on | off |
| Firmware updates (`fwupd`) | off | on |
| ghostty rendering | software OpenGL wrapper | real GPU |
| `~/.config/monitors.xml` | pinned to 1440x900 | owned by GNOME |
| Mac folder symlinks | `~/Documents` etc. link to the Mac | ordinary local folders |
| Voice transcription client | autostarts | not started (no Mac host to talk to) |
| Tor Browser | nightly ARM build | stable release from nixpkgs |

## Hostnames and adding machines

A machine's hostname is the name of its directory under `hosts/`. That one
name is used everywhere: the flake output, the tailnet name, and the device
label in NextDNS. Hostnames must be unique, or two machines become
indistinguishable in Tailscale and NextDNS.

**To rename the first machine** before installing it, rename the directory:

```sh
git mv hosts/nixos-amd64 hosts/<name>
```

Nothing else needs editing, except that `tests/hosts.nix` has three extra
hardware checks keyed to the name `nixos-amd64`; rename that string there too
if you want them to keep running.

**To add another machine,** run `scripts/install.sh` on it (next section). It
asks for the hostname and creates `hosts/<name>/` from that machine's own
hardware. `check_hosts.sh` picks the new host up automatically and holds it
to the same parity checks.

`hosts/nixos-amd64` is not a real machine: its hardware scan is a
placeholder. It is there so the x86_64 build can be checked from the guest
before any bare-metal machine exists, and as the model for a host file. Once
a real x86_64 host is committed you can delete it; move the string
`nixos-amd64` in `tests/hosts.nix` to the real host's name if you do.

Use lowercase letters, digits and hyphens for the name. Do not rename
`hosts/nixos`: the Parallels guest's build script and the test VM refer to it.

Existing YubiKey login enrolments work on every host, because the PAM origin
is pinned to `pam://nixos` in `security.nix` rather than taken from the
hostname.

## Installing on a machine

The supported route is: put a plain NixOS install on the machine, then let
`scripts/install.sh` turn it into this configuration.

1. **Install NixOS normally** from the official x86_64 installer, in UEFI
   mode with Secure Boot off (the bootloaders this configuration installs,
   systemd-boot and GRUB, are unsigned). Any disk layout, with or without
   encryption. The username and hostname you choose there do not matter. On
   a machine that also runs Windows or another Linux, set the base install
   up with GRUB if you want those in the boot menu; the script keeps it.
2. **Get this repository onto it** and run the installer script:

   ```sh
   nix-shell -p git
   git clone <this repository> ~/nixos
   ~/nixos/scripts/install.sh
   ```

The script asks for, or detects and asks you to confirm:

| Question | How it is detected | Where the answer goes |
| --- | --- | --- |
| Hostname | suggests the current one, unless it is the default `nixos` | the name of `hosts/<hostname>/` |
| Hardware scan | finds `/etc/nixos/hardware-configuration.nix`; can generate a fresh one or take a path | `hosts/<hostname>/hardware-configuration.nix` |
| Processor | CPU vendor | imports `amd.nix` or `intel.nix` |
| Graphics card | PCI display adapters; NVIDIA wins over integrated graphics | imports `nvidia.nix`, or Radeon early KMS |
| NVIDIA kernel module | asks: `nvidia` (proprietary) or `nvidia-open` (required for RTX 50) | `hardware.nvidia.open` |
| Release first installed | `system.stateVersion` in `/etc/nixos/configuration.nix` | `system.stateVersion` |
| EFI partition | the vfat filesystem in the scan, and its size | mount point if not `/boot`; fewer boot entries if under 1 GiB |
| Bootloader | GRUB if it started the running system (`BOOT_IMAGE=` on the kernel command line) or the base `configuration.nix` enables it; otherwise systemd-boot | imports `grub.nix` for GRUB |
| Disk encryption | LUKS lines the base install wrote to `configuration.nix` instead of the scan | copied into the host file |

It refuses to go on if the machine was not booted in UEFI mode, if the
hostname is taken or invalid, or if the scan is missing. It writes nothing
until every answer is in, then stages the new host directory in git and
checks that the whole system evaluates.

Finally it offers to build and switch. If you accept, it also:

- asks you to choose a password for `martin` when that account is new. The
  password is not in the repository, and the login screen refuses an account
  without one.
- copies the repository to `/home/martin/nixos` if you ran it from somewhere
  else, because `users.nix` puts that path's `scripts/` on `PATH`.

Then reboot and log in as `martin`. From then on, rebuild with
`build_amd64_metal.sh` and update with `update.sh`. Commit the new host
directory once Bitwarden is set up (commits are signed through its agent).

Two things to know about the switch:

- The account you created during the base install is removed if it is not
  `martin`, because the configuration does not declare it. Its home
  directory is left in place.
- The bootloader stays the one the machine already boots with, unless you
  answer otherwise (`--bootloader systemd-boot|grub`). This first switch
  runs with `--install-bootloader`, which installs that bootloader and puts
  it first in the firmware's boot order; later rebuilds do not need it. If
  you change bootloader, the old one's entry stays in the firmware's boot
  menu but is no longer updated.

The reason for the care: the firmware goes on starting whichever bootloader
is first in its boot order, and a rebuild writes new generations only into
the menu of the bootloader the configuration manages. When the two differ,
every rebuild appears to work and every reboot comes back in the old system.
That happened on `animal`, whose base install booted with GRUB while the
configuration managed systemd-boot. The README's boot section says how to
recognise and fix it.

Every question has a flag (`install.sh --help`), so the script can also be
run unattended, and re-run with `--hostname <name> --force` to regenerate a
host.

### Installing without a base install

From the installer ISO instead: partition and mount at `/mnt`, clone the
repository to `/mnt/home/martin/nixos`, copy `hosts/nixos-amd64` to
`hosts/<name>`, replace its scan with the output of
`nixos-generate-config --root /mnt --show-hardware-config`, `git add` it, and
run `nixos-install --flake /mnt/home/martin/nixos#<name>`. Before rebooting,
set the password and ownership:

```sh
nixos-enter --root /mnt -c 'passwd martin'
chown -R 1000:100 /mnt/home/martin
```

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

## Decisions made, and ones still open

Settled:

- **Graphics.** NVIDIA's driver, as described above.
- **Browsers.** Firefox is the principal browser and the declared default on
  every host. Chromium stays installed on every host as the backup. Google
  ships no ARM Linux build of Chrome, so Chromium is the one browser that
  keeps the package set and the dock identical everywhere.
- **Hostnames.** Taken from the host directory, as described above.
- **Bootloader.** systemd-boot by default; GRUB with `os-prober` on a machine
  that shares its disks with other operating systems, by importing
  `modules/hardware/grub.nix` from its host file. `os-prober` runs at every
  rebuild, so a system installed later appears after the next one.

One NVIDIA setting depends on the exact card, which I do not know:

- **`hardware.nvidia.open`.** `install.sh` asks which you want. It defaults to `false`, NVIDIA's proprietary
  kernel module, which drives every card up to and including the RTX 40
  series. **An RTX 50-series card works only with NVIDIA's open kernel
  module**, so for one of those add `hardware.nvidia.open = true;` to the
  host's `default.nix` before installing. The userspace driver is NVIDIA's
  proprietary one either way.

Also worth knowing about the NVIDIA driver: it has to support the running
kernel, and this configuration tracks the newest kernel
(`boot.kernelPackages = pkgs.linuxPackages_latest` in `boot.nix`). The two
agree today. If a future `update.sh` fails because the driver does not build
against a brand-new kernel, pin that host to the long-term kernel by adding
`boot.kernelPackages = lib.mkForce pkgs.linuxPackages;` to its `default.nix`.
The parity check `same-kernel-series` will then fail for that host, which is
the intended reminder that it has diverged.

Still open, kept identical to the guest:

1. **Keyboard layout.** The system uses the `gb` layout with the `mac`
   variant, and `keyd.nix` remaps `£` and `#` on that assumption. With an
   Apple keyboard on the AMD machine this is right. With a PC keyboard, `@`,
   `"`, `#` and `\` will be in the wrong places, and the layout wants
   overriding for that host in three places: `services.xserver.xkb` in
   `desktop.nix`, the `gb+mac` input source in `gnome.nix`, and the keyd
   chords.
2. **Voice transcription.** The system-side pieces (ydotool, wl-clipboard,
   the `input` group) are installed on every machine, but the client only
   runs on the guest because it sends audio work to the Mac. Running it on
   bare metal needs a decision about where transcription happens.
3. **CD ripping.** `whipper.conf` holds the read offset calibrated for the
   ASUS SDRW-08D2S-U drive. A different drive needs its own entry added to
   `home/martin/whipper/whipper.conf`.
4. **Laptop or desktop.** GNOME's `power-profiles-daemon` is on by default,
   which suits both. Nothing laptop-specific (lid, battery thresholds, hybrid
   graphics switching) is configured.

## Keeping the hosts in step

Run `check_hosts.sh` on any machine after any change that might be
hardware-specific. It evaluates every host without building anything and
prints one line per check. When a difference between the machines is
intended, add it to the short allow-lists at the top of `tests/hosts.nix`, so
the list of differences stays explicit.

For a new hardware-specific setting, follow the existing pattern:

- Something Parallels needs: gate it on `config.hardware.parallels.enable`
  (`osConfig.hardware.parallels.enable` in Home Manager modules).
- Something a kind of hardware needs: put it in a profile under
  `modules/hardware/` and import it from the hosts that have that hardware.
  The bootloader choice (`grub.nix`) works the same way.
- Something one machine alone needs: put it in that host's `default.nix`.
- A package that differs by architecture: branch on
  `pkgs.stdenv.hostPlatform.isx86_64`, as Tor Browser and Holos do.
