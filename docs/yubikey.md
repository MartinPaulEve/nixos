# YubiKey tap-to-unlock for login, sudo, and 1Password

The system is configured (in `modules/nixos/security.nix`, commit `e348a7c`)
so that a YubiKey tap works as an **optional first authentication factor**
for GDM login, `sudo`, and polkit — polkit being the mechanism behind
1Password's "unlock with system authentication". The password always remains
available as a fallback.

## Why you cannot be locked out

Each PAM service is rendered as:

```
auth sufficient pam_u2f.so cue
auth sufficient pam_unix.so ...
```

`sufficient` means a touched key succeeds on its own, but *any* failure — no
key plugged in, key not enrolled, wrong key, u2f breakage — just falls
through to the next line, which is the ordinary password check. There is no
configuration in which the key is *demanded*. Until a key is enrolled, the
u2f line fails instantly and everything behaves as it always has. Disk
encryption (LUKS), if any, is untouched — that happens before PAM.

## Setup steps (needs the YubiKey at hand)

The NixOS side is already active after any
`sudo nixos-rebuild switch --flake ~/nixos` that includes commit `e348a7c`.
Then:

1. **Attach the YubiKey to the VM.** Parallels menu → Devices → USB &
   Bluetooth → click the YubiKey. In the VM's configuration you can set it
   to connect to this VM automatically whenever it is plugged in.

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

## Known caveat: GNOME Keyring at the login screen

If you log in at GDM by tapping the key instead of typing your password,
GNOME Keyring cannot auto-unlock (it derives its unlock key from the typed
password), so it may prompt for your password shortly after login anyway. If
that gets annoying, the u2f factor can be scoped to just `sudo` + polkit and
GDM left password-only: set
`security.pam.services.gdm-password.u2f.enable = false;` in
`modules/nixos/security.nix`.

## How it hangs together

- `security.pam.u2f` in `modules/nixos/security.nix` enables `pam_u2f` with
  `control = "sufficient"` and `cue = true` (prints "Please touch the
  device" while a registered key waits for a tap). NixOS applies it to all
  login-type PAM services by default.
- Enrolled keys live in `~/.config/Yubico/u2f_keys` (per-user, not managed
  by Nix — it contains key handles specific to your physical keys).
- The pam_u2f origin/appid defaults to `pam://<hostname>` (`pam://nixos`).
  If the hostname ever changes, re-enroll with
  `pamu2fcfg -o pam://<newhost> -i pam://<newhost>` or logins will silently
  fall back to password.
- Background on why this exists: macOS Touch ID cannot reach the VM (the
  sensor talks only to the Secure Enclave; no hypervisor can pass it
  through), so a YubiKey tap is the closest officially-supported
  equivalent for unlocking 1Password on the Linux guest.
