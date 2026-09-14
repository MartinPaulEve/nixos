# Bitwarden: deliberately NO declarative configuration — this module is
# documentation only.
#
# Do NOT declare ~/.config/autostart/bitwarden.desktop here. Bitwarden's
# main process rewrites that exact file on every launch ("open at login"
# defaults to on), with fs.writeFileSync straight through whatever is at the
# path. A Home Manager store symlink there makes that write throw EROFS,
# which kills the rest of the app's init chain uncaught: the application
# menu never installs (File shows only Quit, Settings unreachable), the
# tray never registers, and the SSH agent IPC handlers never register
# ("No handler registered for 'sshagent.clearkeys'"). Diagnosed live on
# 2026-09-14; the write is in messaging.main.ts (addOpenAtLogin).
#
# Autostart therefore belongs to the app: it writes the entry itself,
# pointing at the current /nix/store bin path with an --autostart flag that
# starts it minimised to tray, and self-heals the path on every launch.
# The system module (modules/nixos/packages.nix) installs the app.
#
# Some one-time steps are per-user state and cannot be declared here:
#   1. Settings → Enable SSH agent (off by default) — the socket at
#      ~/.bitwarden-ssh-agent.sock serves git commit signing (git.nix) and
#      the sshfs mounts (mounts.nix);
#   2. importing the SSH keys into the vault (the signing key
#      id_ed25519_waldorf plus the keys the sshfs mounts authenticate with);
#   3. Secure Notes named sshmount-<name> whose body is each bw:// mount's
#      host:path (see mounts.nix);
#   4. a one-time `bw login`, so the CLI that sshmount resolves those notes
#      with can unlock the vault (plus `bw sync` whenever a note changes).
{ ... }:

{ }
