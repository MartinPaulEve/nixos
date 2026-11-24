# The home partition that predates this install, mounted at boot, and the
# three folders of it that stand in for their local equivalents.
#
# The partition is ext4, labelled "home", the large one on the first NVMe
# drive; martin's files are under martin/ on it, owned by uid 1000, which is
# martin's uid here as well, so they are readable and writable as they stand.
#
# Nothing here touches what is on the volume: ownership and modes stay
# exactly as they were found. Keep it that way — in particular, never give
# the mountpoint a systemd-tmpfiles `d` rule like the sshfs ones in
# modules/nixos/mounts.nix. tmpfiles runs after the mount, so such a rule
# would chown and chmod the root directory of the volume itself. systemd
# creates the mountpoint directory on its own when it is missing.
{ lib, pkgs, ... }:

let
  mountPoint = "/home/martin/mounts/central_home";
  # Where martin's own files sit on the volume.
  source = "${mountPoint}/martin";
  folders = [ "Documents" "Music" "Pictures" ];

  # Makes ~/<folder> a symlink to the same folder on the volume. It only ever
  # acts on the home directory, never on the volume: a local folder is
  # replaced only if it is empty (rmdir refuses anything else), and nothing
  # is merged across. Anything it will not do lands as a warning in the
  # journal (journalctl --user -u central-home-links).
  linkScript = pkgs.writeShellScript "link-central-home-folders" ''
    set -u
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}

    for name in ${lib.concatStringsSep " " folders}; do
      src="${source}/$name"
      dst="$HOME/$name"

      if [ ! -d "$src" ]; then
        echo "WARNING: not linking $dst: $src is not a directory" >&2
        continue
      fi
      # Already linked correctly.
      if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        continue
      fi
      # A wrong/stale symlink can just be replaced.
      if [ -L "$dst" ]; then
        rm "$dst"
      fi
      if [ -e "$dst" ] && ! rmdir "$dst" 2>/dev/null; then
        echo "WARNING: not linking $dst -> $src: $dst is not an empty folder; move its contents away first" >&2
        continue
      fi

      ln -sT "$src" "$dst" && echo "linked $dst -> $src"
    done
  '';
in
{
  # By UUID: the three NVMe drives are not promised the same numbering from
  # one boot to the next. `nofail` keeps a missing or unmountable drive from
  # dropping the boot into emergency mode; the mountpoint is then just an
  # empty directory.
  fileSystems.${mountPoint} = {
    device = "/dev/disk/by-uuid/1e785ace-7107-477b-95bd-301844ae3ba5";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  # A user service rather than Home Manager's home.file, which would refuse
  # (or move aside) the folders GNOME has already created, and would point
  # the links through the Nix store.
  home-manager.users.martin.systemd.user.services.central-home-links = {
    Unit = {
      Description = "Symlink Documents, Music and Pictures onto the central home volume";
      # Skip quietly (rather than fail) when the volume is not mounted.
      ConditionPathIsMountPoint = mountPoint;
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${linkScript}";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
