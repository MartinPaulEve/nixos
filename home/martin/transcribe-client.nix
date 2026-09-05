# Voice-transcription client: hotkey + paste in this VM, recording and
# transcription on the Mac host over encrypted UDP. System-side runtime deps
# (wl-clipboard, ydotoold, the input/ydotool groups) live in
# modules/nixos/transcribe-client.nix; this module supervises the app.
#
# The service runs from its own clone in ~/.local/share/mpe-transcribe rather
# than the interactive checkout in ~/Programming: the checkout's .venv serves
# interactive use, and this VM needs a different transcribe.toml (client mode,
# Mac host address) from the Mac's (host mode). The first start clones from
# the interactive checkout; transcribe.toml itself is managed
# declaratively (./transcribe/transcribe.toml) and linked into the clone
# root, where the app looks for it. It is gitignored upstream, so checkouts
# never clash with the link. Update the app later with:
#
#   git -C ~/.local/share/mpe-transcribe pull   # then restart the service
#
# Inert everywhere except the aarch64 Parallels guest — the x86 QEMU test VM
# force-disables hardware.parallels (see flake.nix).
{ lib, pkgs, osConfig, ... }:

let
  isParallelsMacGuest =
    osConfig.hardware.parallels.enable
    && pkgs.stdenv.hostPlatform.isAarch64;

  appDir = "/home/martin/.local/share/mpe-transcribe";
  cloneSource = "/home/martin/Programming/mpe-transcribe";

  # First-start setup. The data dir is already non-empty (Home Manager has
  # linked transcribe.toml into it) and `git clone` refuses a non-empty
  # target, so materialise the clone with init + fetch + checkout instead.
  setupScript = pkgs.writeShellScript "transcribe-client-setup" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.git pkgs.coreutils ]}

    [ -e ${appDir}/.git ] && exit 0

    if [ ! -d ${cloneSource}/.git ]; then
      echo "clone source ${cloneSource} unavailable (checkout missing?)" >&2
      exit 1
    fi

    git init -q ${appDir}
    git -C ${appDir} remote add origin ${cloneSource}
    git -C ${appDir} fetch -q origin main
    git -C ${appDir} checkout -q -B main origin/main
  '';
in
{
  config = lib.mkIf isParallelsMacGuest {
    # The client's config; the app reads <project root>/transcribe.toml.
    # Edit the copy in this repo and rebuild — the deployed file is a
    # read-only store symlink.
    xdg.dataFile."mpe-transcribe/transcribe.toml".source =
      ./transcribe/transcribe.toml;

    systemd.user.services.transcribe-client = {
      Unit = {
        Description = "Voice transcription client (network trigger + paste)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStartPre = "${setupScript}";
        # `uv run` syncs the venv (creating it on first start) before
        # launching. The PSK is read via key_file in transcribe.toml, so no
        # EnvironmentFile is needed.
        ExecStart = "${lib.getExe pkgs.uv} run --project ${appDir} --extra client-linux transcribe --client";
        Restart = "on-failure";
        RestartSec = 5;
        # python-evdev compiles against linux/input.h, which NixOS does not
        # put in /usr/include. Normally uv reuses the wheel already cached by
        # the interactive setup, but this keeps a from-scratch build working.
        Environment = "C_INCLUDE_PATH=${pkgs.linuxHeaders}/include";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
