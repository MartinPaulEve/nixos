# YubiKey: tap-to-unlock, FIDO2 SSH keys, OpenPGP, TOTP and file encryption

The YubiKey is used here as an **optional** factor everywhere: every route
below keeps its password (or passphrase, or PIN-less fallback) so nothing
becomes inaccessible when the key is on the other desk. Sections 1 to 3
cover the original tap-to-unlock setup; 4 onwards are the extra things the
key can do and how they are wired in this configuration.

For a step-by-step checklist, including setting up a second, backup key,
see [yubikey-usage.md](yubikey-usage.md).

## 1. Tap-to-unlock for login, sudo, and 1Password

The system is configured in `modules/nixos/security.nix` so that a YubiKey tap works as an **optional first authentication factor**
for GDM login, `sudo`, and polkit — polkit being the mechanism behind
1Password's "unlock with system authentication". The password always remains
available as a fallback.

### Why you cannot be locked out

Each PAM service is rendered as:

```
auth sufficient pam_u2f.so cue
auth sufficient pam_unix.so ...
```

`sufficient` means a touched key succeeds on its own, but *any* failure — no
key plugged in, key not enrolled, wrong key, u2f breakage — just falls
through to the next line, which is the ordinary password check. There is no
configuration in which the key is *demanded*. Until a key is enrolled, the
u2f line fails instantly and everything behaves as it always has. (This
machine has no LUKS, so there is no disk-unlock step to consider.)

GDM's `gdm-password` service does not list `pam_u2f` itself: its auth stack
is a `substack login`, and `login` carries the u2f line, so the login screen
inherits it.

## 2. Setup steps (needs the YubiKey at hand)

The NixOS side is active after any rebuild (`build_aarch64_mac.sh`). Then:

1. **Attach the YubiKey to the VM.** Parallels menu → Devices → USB &
   Bluetooth → click the YubiKey. In the VM's configuration you can set it
   to connect to this VM automatically whenever it is plugged in. Until
   this is done the guest sees nothing: `lsusb` shows no Yubico device and
   `ykman info` says "No YubiKey detected". Once attached, `ykman info`
   lists the model, firmware and which applications (FIDO2, OpenPGP, PIV,
   OATH) are enabled.

2. **Enroll the key** (one-time):

   ```sh
   mkdir -p ~/.config/Yubico
   pamu2fcfg > ~/.config/Yubico/u2f_keys
   ```

   Touch the key when it flashes. To register a backup key later, append it
   with:

   ```sh
   pamu2fcfg -n >> ~/.config/Yubico/u2f_keys
   ```

   (`pamu2fcfg` is installed system-wide by `security.nix`.)

3. **Turn on 1Password's system authentication.** 1Password → Settings →
   Security → "Unlock using system authentication". Unlocking then shows the
   polkit dialog: key present → "Please touch the device", tap, done; key
   absent → password field as normal.

4. **Test the fallback before trusting it.** Run `sudo -k && sudo true`
   twice — once with the key attached (tap to pass) and once with it
   unplugged (should give the normal password prompt). Do the same
   double-check at the GDM login screen.

## 3. Known caveat: GNOME Keyring at the login screen

If you log in at GDM by tapping the key instead of typing your password,
GNOME Keyring cannot auto-unlock (it derives its unlock key from the typed
password), so it may prompt for your password shortly after login anyway. If
that gets annoying, the u2f factor can be scoped to just `sudo` + polkit and
GDM left password-only: set
`security.pam.services.gdm-password.u2f.enable = false;` in
`modules/nixos/security.nix`.

## 4. Touch notifications

A YubiKey waiting for a touch only blinks its LED, which is easy to miss on a
key plugged into the Mac. `yubikey-touch-detector` runs as a user service
(`home/martin/yubikey.nix`) and pops a GNOME notification whenever gpg, a
FIDO2 operation or a pcscd client is blocked on a tap. Nothing to set up.

## 5. SSH keys that live on the YubiKey (FIDO2, recommended)

OpenSSH is built with libfido2, so the key can hold an SSH private key that
never exists on disk. The server needs OpenSSH 8.2 or newer (2020), which
every host in `~/.ssh/config` has.

```sh
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "yubikey" -f ~/.ssh/id_ed25519_sk
```

- `-O resident` stores the credential on the key itself, so on any other
  machine `ssh-keygen -K` (or `ssh-add -K`) recreates the handle files from
  the key. Resident keys need a FIDO2 PIN: set one first with
  `ykman fido access change-pin` (or `fido2-token -S`).
- `-O verify-required` asks for that PIN as well as the touch on each use.
  Drop it if you want touch-only.
- The private handle file `~/.ssh/id_ed25519_sk` is useless without the
  physical key, so it is safe to leave lying around.

Then add the public key to `authorized_keys` on the hosts you want it for,
and add `IdentityFile ~/.ssh/id_ed25519_sk` to their blocks in
`home/martin/ssh/config`. The existing Bitwarden-agent keys stay in place
and keep working, so a host that has not had the new key added, or a session
without the YubiKey, falls back to them automatically. This route does not
involve any agent at all: ssh talks to the key directly.

A FIDO2 key can also sign commits (`gpg.format ssh` already, so only
`user.signingkey` would change). Leave signing on the Bitwarden key unless
you want every commit to require a tap.

## 6. OpenPGP on the YubiKey

gpg-agent is already the system's SSH agent and `scdaemon` is set to share
the card via pcscd, so the OpenPGP applet works out of the box. Two ways to
get a key onto it:

- **Move an existing key** (keeps your identity and signatures):
  `gpg --edit-key <id>` → `keytocard` for the signing, encryption and
  authentication subkeys. `keytocard` is destructive to the on-disk copy:
  back up `~/.gnupg` (or `gpg --export-secret-keys`) somewhere offline
  first. That backup *is* the fallback if the key is lost.
- **Generate on the key**: `gpg --card-edit` → `admin` → `generate`. The
  private material never leaves the key, which also means no backup is
  possible: losing the key means losing the ability to decrypt. Only
  sensible for signing/authentication, not for encrypting anything you
  need to keep.

Change the default PINs first (`123456` user, `12345678` admin):
`ykman openpgp access change-pin` and `change-admin-pin`. Require a touch
per operation with `ykman openpgp keys set-touch sig on` (and `enc`, `aut`).

Once an **authentication** subkey is on the card, gpg-agent offers it over
`SSH_AUTH_SOCK` automatically (`ssh-add -L` shows it). That is a second
YubiKey SSH route, useful if you want one key hierarchy for everything, but
the FIDO2 route above is simpler and does not depend on gpg-agent state.

Signing commits with it instead of the Bitwarden SSH key would mean
`gpg.format openpgp` in `home/martin/git.nix`; not done here.

## 7. TOTP codes on the key

`yubioath-flutter` (Yubico Authenticator, in the app grid) stores TOTP
secrets in the key's OATH applet, so the 2FA codes for GitHub, Google and
so on are generated from the key, not from a phone. Codes can be read with
`ykman oath accounts code` as well. Keep each site's recovery codes in
Bitwarden as the fallback.

Separately, the key works as a **WebAuthn / passkey** authenticator in
Firefox with nothing extra: register it under each site's security
settings alongside the existing password.

## 8. Encrypting files with age

`age` with `age-plugin-yubikey` keeps an age identity in one of the key's
PIV slots:

```sh
age-plugin-yubikey                       # interactive: generate an identity
age-plugin-yubikey --identity > ~/.config/age/yubikey.txt
age -r age1yubikey1... -o secret.age secret.txt
age -d -i ~/.config/age/yubikey.txt secret.age   # tap to decrypt
```

Encrypt to **two** recipients, the YubiKey and an ordinary age key held in
Bitwarden, so the file is still decryptable without the key. This is also
the obvious path if secrets are ever moved into this repo via `agenix` or
`sops-nix`.

## 9. How it hangs together

- `security.pam.u2f` in `modules/nixos/security.nix` enables `pam_u2f` with
  `control = "sufficient"` and `cue = true` (prints "Please touch the
  device" while a registered key waits for a tap). NixOS applies it to all
  login-type PAM services by default.
- Enrolled keys live in `~/.config/Yubico/u2f_keys` (per-user, not managed
  by Nix — it contains key handles specific to your physical keys).
- The pam_u2f origin/appid are pinned to `pam://nixos` in `security.nix`
  (rather than derived from the hostname at run time), so a hostname change
  cannot silently invalidate the enrolments. `pamu2fcfg` uses the same
  default, so plain `pamu2fcfg` enrolments match.
- udev: `yubikey-personalization` tags YubiKeys as security tokens for the
  CCID side; systemd's own `60-fido-id.rules` + `70-uaccess.rules` give the
  logged-in user access to the FIDO HID interface, so browsers and
  `ssh-keygen -t ed25519-sk` work without extra rules. `pcscd` (root)
  serves the smartcard interface to gpg, ykman, the authenticator and age.
- Per-user side: `home/martin/yubikey.nix` sets `disable-ccid` in
  `~/.gnupg/scdaemon.conf` so gpg shares the card through pcscd instead of
  grabbing the USB interface and locking everyone else out, and runs
  `yubikey-touch-detector` as a user service.
- Background on why this exists: macOS Touch ID cannot reach the VM (the
  sensor talks only to the Secure Enclave; no hypervisor can pass it
  through), so a YubiKey tap is the closest officially-supported
  equivalent for unlocking 1Password on the Linux guest.
