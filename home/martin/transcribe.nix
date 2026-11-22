# Voice transcription (mpe-transcribe): press the hotkey, speak, press it
# again, and the text is pasted into the focused window. System-side runtime
# deps (ydotoold, the input/ydotool groups) live in
# modules/nixos/transcribe.nix; this module supervises the app.
#
# A machine runs it one of two ways, decided by its hardware:
#
#   standalone — a machine with an NVIDIA card does everything itself:
#     hotkey, recording from its own microphone, transcription on the GPU
#     with NVIDIA's Parakeet model, paste. It serves nobody else and needs
#     nobody else. (The app's own name for this is "standalone"; its "host"
#     mode is the same thing plus a network listener for clients, which is
#     not wanted here.)
#
#   client — the aarch64 Parallels guest has no GPU to transcribe with, so it
#     only does the hotkey and the paste; the Mac host records and
#     transcribes, over encrypted UDP.
#
# Anything else (the x86 QEMU test VM, a machine with neither) gets nothing.
#
# Either way the service runs from its own clone in
# ~/.local/share/mpe-transcribe rather than an interactive checkout: uv keeps
# the virtualenv inside the project, and transcribe.toml — which the app
# reads from the project root — is this machine's, linked in from here. The
# first start makes the clone: from ~/Programming/mpe-transcribe where there
# is one, from GitHub otherwise. Update the app later with:
#
#   git -C ~/.local/share/mpe-transcribe pull   # then restart the service
#
# transcribe.toml is gitignored upstream, so checkouts never clash with the
# link. It is generated below; edit it here and rebuild — the deployed file
# is a read-only store symlink.
{ lib, pkgs, osConfig, ... }:

let
  isParallelsMacGuest =
    osConfig.hardware.parallels.enable
    && pkgs.stdenv.hostPlatform.isAarch64;
  hasNvidia = builtins.elem "nvidia" osConfig.services.xserver.videoDrivers;

  role =
    if isParallelsMacGuest then "client"
    else if hasNvidia then "standalone"
    else null;

  appDir = "/home/martin/.local/share/mpe-transcribe";
  localCheckout = "/home/martin/Programming/mpe-transcribe";
  upstream = "https://github.com/MartinPaulEve/mpe-transcribe.git";

  # Settings every machine shares, so a correction added once applies
  # wherever the text ends up being pasted. See transcribe.toml.example in
  # the app repo for all options.
  common = {
    # "ctrl+v" (default) or "type".
    paste_method = "ctrl+v";

    hotkey = "ctrl+\\";

    notifications = {
      visual = false; # desktop notifications (notify-send)
      sound = true; # the ding
    };

    # Voice recognition corrections — exact replacements (case-insensitive):
    # key = what the transcriber produces, value = what you meant.
    replacements = {
      comet = "commit";
      "martin poll eve" = "Martin Paul Eve";
    };

    # Fuzzy-matched terms — corrected via similarity matching.
    custom_terms = {
      terms = [ "Martin Paul Eve" "Birkbeck" ];
      threshold = 0.8;
    };
  };

  settings = {
    # No [network] section at all: that is what makes it standalone.
    standalone = common // {
      # NVIDIA Parakeet, run on the GPU through NeMo. This is the fast 0.6B
      # model (~2 GB of VRAM, held for as long as the service runs);
      # "nvidia/parakeet-rnnt-1.1b" is slower and more accurate (~4 GB).
      model = "nvidia/parakeet-tdt-0.6b-v3";
    };

    client = common // {
      network = {
        mode = "client";
        server_host = "10.211.55.2"; # the Mac, via Parallels shared networking
        client_label = "nixos-vm";
        # The pre-shared key stays out of the repo.
        key_file = "/home/martin/.config/transcribe/psk";
      };
    };
  };

  # First-start setup. The data dir is already non-empty (Home Manager has
  # linked transcribe.toml into it) and `git clone` refuses a non-empty
  # target, so materialise the clone with init + fetch + checkout instead.
  setupScript = pkgs.writeShellScript "transcribe-setup" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.git pkgs.coreutils ]}

    [ -e ${appDir}/.git ] && exit 0

    if [ -d ${localCheckout}/.git ]; then
      source=${localCheckout}
    else
      source=${upstream}
    fi

    git init -q ${appDir}
    git -C ${appDir} remote add origin "$source"
    git -C ${appDir} fetch -q origin main
    git -C ${appDir} checkout -q -B main origin/main
  '';

  # The standalone install is PyTorch, NeMo and a CUDA runtime, all of it
  # prebuilt wheels that expect an ordinary Linux: libstdc++ and libz on the
  # loader's search path, PortAudio where ctypes can find it by name. NixOS
  # has no such paths, so the service runs uv inside a small FHS environment
  # that provides them — a private /usr holding exactly the packages below —
  # instead of patching wheels uv would only download again. Everything else
  # (home directory, /run, /dev, the GPU driver in /run/opengl-driver) is the
  # real system's.
  standaloneEnv = pkgs.buildFHSEnv {
    name = "transcribe-env";
    targetPkgs = p: with p; [
      uv
      # The interpreter uv builds the virtualenv from. 3.12 is the oldest the
      # app supports and the one every wheel in its lock file exists for.
      python312
      # python-evdev (the hotkey listener) ships no wheel: it is compiled on
      # first start, against the kernel's input headers.
      gcc
      linuxHeaders
      # What the wheels load at run time.
      stdenv.cc.cc.lib # libstdc++
      zlib
      portaudio # sounddevice: microphone capture and the ding
      libsndfile
      # What the app shells out to.
      xclip # clipboard, via the XWayland bridge (its first choice)
      wl-clipboard # clipboard fallback
      ydotool # the Ctrl+V itself
      libnotify # notify-send
      pulseaudio # pactl, to check the microphone before recording
    ];
    runScript = "uv";
  };

  # `uv run` syncs the venv (creating it on first start) before launching.
  command = {
    standalone = "${standaloneEnv}/bin/transcribe-env run --project ${appDir} --python 3.12 --extra linux transcribe --standalone";
    # Light enough to run on the system's own Python. The PSK is read via
    # key_file in transcribe.toml, so no EnvironmentFile is needed.
    client = "${lib.getExe pkgs.uv} run --project ${appDir} --extra client-linux transcribe --client";
  };

  description = {
    standalone = "Voice transcription (hotkey, recording, Parakeet on the GPU, paste)";
    client = "Voice transcription client (network trigger + paste)";
  };

  # The guest's unit keeps the name it has always had.
  unit = if role == "client" then "transcribe-client" else "transcribe";
in
{
  config = lib.mkIf (role != null) {
    xdg.dataFile."mpe-transcribe/transcribe.toml".source =
      (pkgs.formats.toml { }).generate "transcribe.toml" settings.${role};

    systemd.user.services.${unit} = {
      Unit = {
        Description = description.${role};
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStartPre = "${setupScript}";
        ExecStart = command.${role};
        Restart = "on-failure";
        RestartSec = 5;
        # python-evdev compiles against linux/input.h, which NixOS does not
        # put in /usr/include. Normally uv reuses the wheel it has already
        # built, but this keeps a from-scratch build working.
        Environment = "C_INCLUDE_PATH=${pkgs.linuxHeaders}/include";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
