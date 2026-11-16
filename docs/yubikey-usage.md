# YubiKey runbook: enrolling two keys and putting things on them

Step-by-step instructions for setting up a **primary** YubiKey and a
**backup** YubiKey so that either one works everywhere, and for the routine
tasks afterwards. For *why* the system is wired the way it is, see
[yubikey.md](yubikey.md); this file is just what to type.

Throughout, "both keys" means: do the step with the primary plugged in, then
swap in the backup and do it again. Where the two keys must hold the *same*
secret (OpenPGP, TOTP) the steps say so explicitly; everywhere else each key
gets its own credential and the remote side is told about both.

## 0. Before you start

1. **Rebuild** so the tooling and services are in place: `build_aarch64_mac.sh`.
2. **Pass the key through to the VM.** Parallels → Devices → USB & Bluetooth
   → the YubiKey. Set it to connect to this VM automatically. Only one key
   needs to be attached at a time; `ykman list` shows what the guest sees.
3. **Check what each key can do:**

   ```sh
   ykman info
   ```

   Note the serial, firmware and the enabled applications (FIDO2, OpenPGP,
   OATH, PIV). Both keys should be the same model or you will hit odd gaps.
4. **Label the keys** physically (a dot of nail varnish on the backup is
   enough). Record each serial in Bitwarden with the PINs you set below.

## 1. Set the PINs (both keys)

Every applet has its own PIN and ships with a well-known default. Change the
ones you will use, and store them in a Bitwarden item per key.

| Applet | Default | Change with |
|---|---|---|
| FIDO2 (SSH keys, passkeys) | none set | `ykman fido access change-pin` |
| OpenPGP user PIN | `123456` | `ykman openpgp access change-pin` |
| OpenPGP admin PIN | `12345678` | `ykman openpgp access change-admin-pin` |
| PIV PIN (age) | `123456` | `ykman piv access change-pin` |
| PIV PUK | `12345678` | `ykman piv access change-puk` |
| PIV management key | fixed default | `ykman piv access change-management-key --generate --protect` |

The FIDO2 PIN is the one you will type most (resident SSH keys and passkeys
ask for it). Eight wrong FIDO2 PINs in a row wipe the FIDO2 applet, so keep
it memorable. Skip the PIV rows if you will not use age; skip the OpenPGP
rows if you will not use PGP.

## 2. Tap-to-unlock for login, sudo and 1Password (both keys)

Primary key attached:

```sh
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys     # touch when it blinks
```

Swap to the backup key:

```sh
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys # -n: append to the same user line
```

The file is one line: `martin:<key1>:<key2>`. `pamu2fcfg -n` prints a key
entry without the username and without a trailing newline, which is exactly
what the append needs. Check with `cat ~/.config/Yubico/u2f_keys | tr ':' '\n'`
— you should see the username followed by two entries.

Test all three paths before relying on it:

```sh
sudo -k && sudo true    # primary attached: "Please touch the device", tap
sudo -k && sudo true    # backup attached: same
sudo -k && sudo true    # no key: normal password prompt
```

Do the same at the GDM login screen. Then, in 1Password → Settings →
Security, turn on "Unlock using system authentication".

## 3. SSH keys on the YubiKey (FIDO2, both keys)

Each key gets its own resident SSH credential. The `application` name keeps
them distinguishable on the key and when recovering them later.

Primary attached:

```sh
ssh-keygen -t ed25519-sk -O resident -O verify-required \
  -O application=ssh:primary -C "yubikey-primary" -f ~/.ssh/id_ed25519_sk_primary
```

Backup attached:

```sh
ssh-keygen -t ed25519-sk -O resident -O verify-required \
  -O application=ssh:backup -C "yubikey-backup" -f ~/.ssh/id_ed25519_sk_backup
```

Each asks for the FIDO2 PIN and a touch. `-O verify-required` means every
later use asks for the PIN as well as the touch; leave it off for touch-only.

Then, per host you want them on:

1. Append **both** `.pub` files to `~/.ssh/authorized_keys` on the host.
   The existing Bitwarden key must stay there too: that is the fallback.
2. In `home/martin/ssh/config`, add both to the host's block, above the
   Bitwarden entry so they are tried first:

   ```
   IdentityFile /home/martin/.ssh/id_ed25519_sk_primary
   IdentityFile /home/martin/.ssh/id_ed25519_sk_backup
   ```

   With a key absent, ssh reports that identity as unavailable and moves on
   to the next, ending at the Bitwarden key. Rebuild to deploy the config.
3. Commit the two `.pub` files into `home/martin/ssh/` alongside the others
   if you want Home Manager to place them; the private handle files are
   useless without the physical key but are not needed on other machines
   either, see below.

**On another machine**, plug a key in and run `ssh-keygen -K` in `~/.ssh`:
it recreates the handle files from the resident credentials, named
`id_ed25519_sk_rk_primary` (or `_backup`), and you are set.

## 4. OpenPGP on both keys (same subkeys on each)

This is the fiddly one, because `keytocard` *moves* a subkey: after loading
the primary, the on-disk copy is a stub pointing at that card, and the
backup card needs the real subkeys again. So: back up first, load key one,
restore, load key two.

Only do this if you actually use PGP (email, signing releases). If you just
want SSH and commit signing, section 3 is enough.

### 4a. Have a key with three subkeys

Either use your existing key or create one. The card wants separate
**sign**, **encrypt** and **authenticate** subkeys:

```sh
gpg --expert --edit-key <KEYID>
gpg> addkey      # pick ECC (sign only), Curve 25519
gpg> addkey      # pick ECC (encrypt only), Curve 25519
gpg> addkey      # pick ECC (set your own capabilities) → toggle to Authenticate only
gpg> save
```

### 4b. Back up the secret key, offline

```sh
gpg --armor --export-secret-keys <KEYID> > ~/pgp-master-and-subkeys.asc
gpg --armor --export-secret-subkeys <KEYID> > ~/pgp-subkeys.asc
```

Put `pgp-master-and-subkeys.asc` somewhere offline (encrypted USB stick in a
drawer, or an age file encrypted to a Bitwarden-held age key). This backup
is the recovery path if **both** YubiKeys are lost. Keep `pgp-subkeys.asc`
to hand for the next step.

### 4c. Load the primary key

Primary attached:

```sh
gpg --edit-key <KEYID>
gpg> key 1          # select the signing subkey (an asterisk appears)
gpg> keytocard      # choose (1) Signature key; admin PIN
gpg> key 1          # deselect
gpg> key 2
gpg> keytocard      # (2) Encryption key
gpg> key 2
gpg> key 3
gpg> keytocard      # (3) Authentication key
gpg> save
```

Then require a touch per operation (admin PIN):

```sh
ykman openpgp keys set-touch sig on
ykman openpgp keys set-touch enc on
ykman openpgp keys set-touch aut on
```

### 4d. Restore the subkeys and load the backup key

```sh
gpg --delete-secret-keys <KEYID>        # removes the stubs; public key stays
gpg --import ~/pgp-subkeys.asc
```

Backup attached: repeat 4c exactly, including the `set-touch` commands.
Afterwards your keyring again holds stubs, now pointing at the backup card.
Delete `~/pgp-subkeys.asc` (the offline backup from 4b is the keeper).

### 4e. Switching between the two cards

gpg remembers which card serial it last saw the subkeys on. When you plug
in the other key, tell it to look again:

```sh
gpg-connect-agent "scd serialno" "learn --force" /bye
```

Worth putting in a fish abbreviation (`yk-switch`). `gpg --card-status`
confirms which card is in and that the three key slots are populated.

### 4f. SSH via the authentication subkey

With either card in, `ssh-add -L` lists the authentication subkey (the
system gpg-agent is the SSH agent and offers card keys automatically). Add
that public line to `authorized_keys` on hosts where you want it. Because
both cards hold the *same* subkey, this is one public key, not two.

## 5. TOTP codes (same secret on both keys)

When a site offers an authenticator-app QR code, enrol the same secret into
both keys before you confirm on the site:

1. Open Yubico Authenticator with the primary attached, add the account by
   scanning the QR code (or paste the secret), and **do not** close the
   site's dialog yet.
2. Swap to the backup and add the same QR code / secret again. From a
   terminal the equivalent is
   `ykman oath accounts add --touch "GitHub:martin" <SECRET>` on each key.
3. Now enter the current code on the site to finish. Both keys generate the
   same codes from then on.
4. Store the site's recovery codes in Bitwarden. That is the fallback.

`ykman oath accounts code` prints codes from whichever key is attached.

## 6. Passkeys / WebAuthn (register both keys)

On each site (GitHub, Google, Bitwarden, Microsoft, …), go to the security
settings and register a security key twice: once per YubiKey. Name them
"YubiKey primary" and "YubiKey backup" so you can revoke the right one
later. Firefox needs nothing extra. Keep the site's password or recovery
codes as the fallback.

Resident passkeys use slots on the key: 25 on firmware below 5.7, 100 from
5.7. `ykman fido credentials list` shows what is stored.

## 7. age file encryption (an identity on each key)

Primary attached:

```sh
age-plugin-yubikey --generate --name primary --touch-policy cached
```

Backup attached:

```sh
age-plugin-yubikey --generate --name backup --touch-policy cached
```

Each prints an `age1yubikey1…` recipient. Collect both, plus an ordinary
software key kept in Bitwarden (`age-keygen`), and always encrypt to all
three:

```sh
age -r age1yubikey1<primary> -r age1yubikey1<backup> -r age1<software> -o file.age file
```

Decrypting needs an identity file for whichever key is attached:

```sh
mkdir -p ~/.config/age
age-plugin-yubikey --identity > ~/.config/age/yubikey.txt   # with each key attached, append both
age -d -i ~/.config/age/yubikey.txt file.age                 # tap to decrypt
```

`age-plugin-yubikey --list` shows the identities on the attached key.

## 8. Day to day

- **Touch prompts** appear as GNOME notifications (yubikey-touch-detector).
  If a command seems to hang, look for the blinking key.
- **What is on this key?**
  `ykman fido credentials list`, `ykman oath accounts list`,
  `ykman openpgp info`, `age-plugin-yubikey --list`.
- **Switching keys for gpg:** section 4e. Everything else just works with
  whichever key is attached.
- **Test the backup** every few months: log in, sudo, ssh to one host, read
  a TOTP code, decrypt one age file. A backup that has never been tried is
  a hope, not a backup.
- **Store the backup off-site** (not in the same bag as the laptop).

## 9. If a key is lost

Work through the places it was registered, in the order of what an attacker
could reach fastest:

1. **Passkeys:** remove the lost key's registration from each site (that is
   what the "primary"/"backup" names were for). Change passwords on sites
   where the key was the second factor and you are not sure the PIN held.
2. **SSH:** remove its `id_ed25519_sk_<name>.pub` line from every
   `authorized_keys`, and from `home/martin/ssh/config`.
3. **PAM:** regenerate `~/.config/Yubico/u2f_keys` with the remaining key
   (section 2, first command only).
4. **OpenPGP:** the subkeys are protected by the user PIN (three attempts),
   but if in doubt revoke them with the offline master key and issue new
   ones (`gpg --edit-key`, `revkey`, then 4a to 4d with the surviving key
   and its replacement).
5. **TOTP:** re-enrol affected sites, which issues new secrets.
6. **age:** re-encrypt files to a new identity and drop the lost recipient.

Then buy a replacement and run this document again with it as the new
backup. If the lost key turns up, factory-reset the applets before reuse:
`ykman fido reset`, `ykman openpgp reset`, `ykman oath reset`, `ykman piv reset`.
