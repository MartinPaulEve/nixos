# Maps the macOS host's folders onto their $HOME equivalents.
#
# Parallels mounts the Mac folders it is allowed to see under /mnt/psf. This
# replaces the matching local folders (~/Documents, ~/Downloads, …) with
# symlinks onto the share, so both OSes work on the same files. macOS privacy
# (TCC) controls what appears in /mnt/psf/Home: currently Desktop, Documents
# and Downloads. Granting Parallels access to more Mac folders (System
# Settings → Privacy & Security → Files & Folders, or Full Disk Access) makes
# them appear, and the next login links them automatically — including the
# Mac's Movies onto the Linux ~/Videos. Dropbox is a separate share and is
# linked to ~/Dropbox, where it lives on the Mac.
#
# Entirely inert off the Mac: the whole module is gated on the system being
# an aarch64 Parallels guest (the x86 QEMU test VM force-disables
# hardware.parallels), and at runtime the service only starts when the share
# is actually mounted.
#
# The linking is deliberately conservative: files already in a local folder
# are merged into the share without overwriting anything, and a folder is
# only replaced by a symlink once it is empty — on any collision it is left
# alone and a warning lands in the journal (journalctl --user -u
# mac-folder-links).
{ lib, pkgs, osConfig, ... }:

let
  isParallelsMacGuest =
    osConfig.hardware.parallels.enable
    && pkgs.stdenv.hostPlatform.isAarch64;

  linkScript = pkgs.writeShellScript "map-mac-folders" ''
    set -u
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.findutils ]}

    link_dir() {
      src="$1" dst="$2"
      [ -d "$src" ] || return 0

      # Already linked correctly.
      if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        return 0
      fi
      # A wrong/stale symlink can just be replaced.
      if [ -L "$dst" ]; then
        rm "$dst"
      fi

      if [ -d "$dst" ]; then
        # Merge any local contents into the share, never overwriting.
        find "$dst" -mindepth 1 -maxdepth 1 -exec mv -n {} "$src"/ \;
        if [ -n "$(ls -A "$dst")" ]; then
          echo "WARNING: not linking $dst -> $src: local files with clashing names remain" >&2
          return 0
        fi
        rmdir "$dst"
      fi

      ln -sT "$src" "$dst" && echo "linked $dst -> $src"
    }

    link_dir /mnt/psf/Home/Desktop   "$HOME/Desktop"
    link_dir /mnt/psf/Home/Documents "$HOME/Documents"
    link_dir /mnt/psf/Home/Downloads "$HOME/Downloads"
    link_dir /mnt/psf/Home/Music     "$HOME/Music"
    link_dir /mnt/psf/Home/Pictures  "$HOME/Pictures"
    link_dir /mnt/psf/Home/Public    "$HOME/Public"
    link_dir /mnt/psf/Home/Movies    "$HOME/Videos"
    link_dir /mnt/psf/Dropbox        "$HOME/Dropbox"
  '';
in
{
  config = lib.mkIf isParallelsMacGuest {
    systemd.user.services.mac-folder-links = {
      Unit = {
        Description = "Symlink Mac host folders from the Parallels share into HOME";
        # Skip quietly (rather than fail) when the share is not mounted.
        ConditionPathIsDirectory = "/mnt/psf/Home";
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${linkScript}";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
