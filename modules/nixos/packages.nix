# System-wide packages and package-related activation.
{ pkgs, inputs, lib, ... }:

let
  # A pkgs instance that permits the insecure packages some apps depend on:
  # Sublime Text needs OpenSSL 1.1, and Bitwarden's desktop app ships an EOL
  # Electron. Scoped here so the exceptions never leak into the system-wide
  # pkgs. Electron pin: check whether a nixpkgs bump lets bitwarden-desktop
  # build against a supported Electron, and drop the entry when it does.
  pkgs-insecure = import inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "openssl-1.1.1w"
        "electron-39.8.10"
      ];
    };
  };

  # Tor Browser only exists upstream as official stable binaries for
  # x86_64/i686 Linux. On the aarch64 host we use the Tor Project's official
  # *nightly* aarch64 build: running the x86_64 stable through QEMU user-mode
  # emulation was tried first and proved unusably slow. The overrideAttrs
  # reuses the whole nixpkgs derivation (autoPatchelf, preference lockdown,
  # wrapper, desktop entry) and only swaps in the nightly tarball, whose
  # sha256 was cross-checked against the published
  # sha256sums-unsigned-build.txt. Nightly date directories eventually rotate
  # off the server, so the pinned URL goes stale — rebuilds keep working from
  # the tarball already in the store until a garbage-collect evicts it. To
  # bump: pick a recent date from
  # https://nightlies.tbb.torproject.org/nightly-builds/tor-browser-builds/
  # and refresh tbbNightly + hash (`nix store prefetch-file <url>`). Beware:
  # the local network filter MITM-blocks *.torproject.org (FortiGate "Web
  # Filter Violation" page), so downloading needs an unfiltered route. If
  # upstream ever ships stable aarch64-linux builds (check tor-browser's
  # meta.platforms after a nixpkgs bump), delete all this and use
  # pkgs.tor-browser directly.
  tbbNightly = "tbb-nightly.2026.08.18";
  tor-browser' =
    if pkgs.stdenv.hostPlatform.isx86_64
    then pkgs.tor-browser
    else
      pkgs.tor-browser.overrideAttrs (old: {
        version = tbbNightly;
        src = pkgs.fetchurl {
          url = "https://nightlies.tbb.torproject.org/nightly-builds/tor-browser-builds/${tbbNightly}/nightly-linux-aarch64/tor-browser-linux-aarch64-${tbbNightly}.tar.xz";
          hash = "sha256-aNTTFlxNo7AHyWurt2w++LRZ7oXfzfIUVn8g+pcb7cQ=";
        };
        # The nightly bundle layout moved TorBrowser/Data/Tor/* (torrc-defaults,
        # geoip) into TorBrowser/Tor/*; retarget the inherited build script.
        buildPhase =
          builtins.replaceStrings
            [ "TorBrowser/Data/Tor/" ]
            [ "TorBrowser/Tor/" ]
            old.buildPhase;
        meta = old.meta // {
          platforms = old.meta.platforms ++ [ "aarch64-linux" ];
        };
      });

  # commonmeta: CLI to convert scholarly metadata between formats (Crossref,
  # DataCite, Schema.org, CSL, …). Not in nixpkgs, so we build it from the
  # pinned upstream release. Refresh on bump: set vendorHash to lib.fakeHash,
  # rebuild, and copy the reported hash back.
  commonmeta = pkgs.buildGoModule rec {
    pname = "commonmeta";
    version = "0.35.2";

    src = pkgs.fetchFromGitHub {
      owner = "front-matter";
      repo = "commonmeta";
      rev = "v${version}";
      hash = "sha256-solx6gVY77FoMMeSv7Sf3ccSIhhTMRjSH/PnDbVNavk=";
    };

    vendorHash = "sha256-gzEnypW5VD9q3v+1zbI55e2mNIwz4mA0M9W6oh1SX5Y=";

    # Upstream tests reach the network and diff against live-service fixtures.
    doCheck = false;

    meta = {
      description = "Convert scholarly metadata between formats";
      homepage = "https://github.com/front-matter/commonmeta";
      license = lib.licenses.mit;
      mainProgram = "commonmeta";
    };
  };

  # sequoia-cli: publishes Standard.site blog documents to the AT Protocol
  # (https://sequoia.pub). Distributed only on npm, not in nixpkgs. The
  # published tarball is a single self-contained `bun build` bundle (all deps
  # inlined, no node_modules, no native/postinstall steps), so we just fetch it
  # and wrap it with node. xdg-utils is on PATH so `sequoia login` can open a
  # browser for OAuth. Refresh on bump: update version + hash (via
  # `nix store prefetch-file <tarball-url>`).
  sequoia-cli = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "sequoia-cli";
    version = "0.5.7";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/sequoia-cli/-/sequoia-cli-${version}.tgz";
      hash = "sha256-z2gUEKAIfU/IY9y8lcTgwIhex4g8E7lLIRV2Bqgc+hM=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/sequoia-cli"
      cp -r dist package.json README.md "$out/lib/sequoia-cli/"
      makeWrapper ${pkgs.nodejs}/bin/node "$out/bin/sequoia" \
        --add-flags "$out/lib/sequoia-cli/dist/index.js" \
        --prefix PATH : ${lib.makeBinPath [ pkgs.xdg-utils ]}
      runHook postInstall
    '';

    meta = {
      description = "Publish Standard.site documents to the AT Protocol";
      homepage = "https://sequoia.pub";
      mainProgram = "sequoia";
    };
  };

  # holos: Electron desktop client for holos.social. Not in nixpkgs — the
  # nixpkgs `holos` attribute is the unrelated holos.run platform CLI. Upstream
  # ships binaries only (https://holos.social/download), with separate builds
  # per architecture: the plain AppImage is x64 (for the bare-metal amd64
  # host), the -arm64 one covers the aarch64 VM. wrapType2 runs the AppImage's
  # payload in an FHS env; the desktop entry and icon are copied out of the
  # image so GNOME can launch and pin it. Refresh on bump: update version and
  # BOTH hashes (`nix store prefetch-file <url>`).
  holos =
    let
      pname = "holos";
      version = "1.15.0";
      src =
        if pkgs.stdenv.hostPlatform.isx86_64
        then
          pkgs.fetchurl
            {
              url = "https://files.fedilab.app/holos-desktop/Holos-${version}.AppImage";
              hash = "sha256-Z0WEQHOsnAI3TporuM7ADsA6x68nNNnbPW2grLmDVkA=";
            }
        else
          pkgs.fetchurl {
            url = "https://files.fedilab.app/holos-desktop/Holos-${version}-arm64.AppImage";
            hash = "sha256-BVjOviokCTuEUcaEX1Ib2Uu11XOMMIZYxcGnXXKsBl8=";
          };
      appimageContents = pkgs.appimageTools.extract { inherit pname version src; };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;
      # Keep upstream's Exec flags (--no-sandbox %U) but point it at the
      # wrapper binary instead of the AppImage-internal AppRun.
      extraInstallCommands = ''
        install -Dm444 ${appimageContents}/holos.desktop \
          "$out/share/applications/holos.desktop"
        substituteInPlace "$out/share/applications/holos.desktop" \
          --replace-fail 'Exec=AppRun' 'Exec=holos'
        install -Dm444 \
          ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/holos.png \
          "$out/share/icons/hicolor/1024x1024/apps/holos.png"
      '';
      meta = {
        description = "Desktop client for holos.social";
        homepage = "https://holos.social";
        mainProgram = "holos";
        platforms = [ "x86_64-linux" "aarch64-linux" ];
      };
    };

  # moji: Markdown viewer/editor (Electron), the default opener for .md files
  # (the file association lives in home/martin/moji.nix). Not in nixpkgs, and
  # upstream's Linux release binaries are x86_64-only, so on the aarch64 host
  # it is built from source. electron-vite inlines every dependency into out/
  # (electron-builder packs no node_modules), so the build output plus
  # package.json is the whole app, run unpacked by nixpkgs' Electron.
  # Electron pin: upstream develops against ^43; this nixpkgs tops out at
  # electron_42, which runs it fine — on a nixpkgs bump, move to the newest
  # electron_NN at or above 43. Refresh on bump: update version, src hash
  # (`nix flake prefetch github:alexishida/Moji/v<version>`) and npmDepsHash
  # (`prefetch-npm-deps package-lock.json` in the tagged checkout).
  moji = pkgs.buildNpmPackage rec {
    pname = "moji";
    version = "1.0.7";

    src = pkgs.fetchFromGitHub {
      owner = "alexishida";
      repo = "Moji";
      rev = "v${version}";
      hash = "sha256-c9z7BR3AF9ygQ+whcJh+Kvh0afM0VDJPwFrHrfK4Wjc=";
    };

    npmDepsHash = "sha256-7iixeQnC5xlRvrpQ+MJYCP8Qb5s6DeinKT/Sm5936Tc=";

    # The sandbox has no network, but `npm ci`'s lifecycle scripts try to use
    # it: upstream's postinstall downloads the Electron binary (we run the
    # nixpkgs one instead; Electron ≥ 42's install.js no longer honours
    # ELECTRON_SKIP_BINARY_DOWNLOAD) and Playwright fetches browsers. Nothing
    # in the tree actually needs install scripts — esbuild/rollup natives are
    # prebuilt optional deps — and `npm run build` still runs the explicitly
    # named script.
    npmFlags = [ "--ignore-scripts" ];

    nativeBuildInputs = [ pkgs.makeWrapper ];

    # buildNpmPackage's default buildPhase runs `npm run build`
    # (electron-vite build), which emits the bundled app into out/.

    installPhase = ''
      runHook preInstall

      # Everything electron-builder would pack (`files:` in
      # electron-builder.yml), plus build/icon.png, which main.ts reads for
      # the window icon when running unpacked (app.isPackaged == false).
      mkdir -p $out/share/moji
      cp -r out package.json samples $out/share/moji/
      install -Dm444 build/icon.png $out/share/moji/build/icon.png

      for size in 16 24 32 48 64 128 256 512 1024; do
        install -Dm444 "build/icons/''${size}x''${size}.png" \
          "$out/share/icons/hicolor/''${size}x''${size}/apps/moji.png"
      done

      # Upstream's desktop entry launches the AppImage's AppRun; point it at
      # the wrapper instead (and keep the Chromium sandbox, which nixpkgs'
      # Electron supports fine on NixOS).
      install -Dm444 build/linux/moji.desktop $out/share/applications/moji.desktop
      substituteInPlace $out/share/applications/moji.desktop \
        --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=moji %U'

      # Electron reads package.json in the app dir for the entry point.
      # The Wayland flags mirror nixpkgs' Electron-app wrappers: inert unless
      # NIXOS_OZONE_WL is set in a Wayland session.
      makeWrapper ${lib.getExe pkgs.electron_42} $out/bin/moji \
        --add-flags $out/share/moji \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

      runHook postInstall
    '';

    meta = {
      description = "Clean cross-platform Markdown viewer and editor";
      homepage = "https://github.com/alexishida/Moji";
      license = lib.licenses.mit;
      mainProgram = "moji";
      platforms = [ "x86_64-linux" "aarch64-linux" ];
    };
  };
in
{
  environment.systemPackages = with pkgs; [
    # --- Tools to mount userspace devices ---
    sshfs                    # SSH filesystem mount
    fuse                     # Filesystems in Userspace

    # --- Core command-line utilities ---
    wget                     # HTTP(S) file downloader
    curl                     # Multi-protocol data-transfer tool
    nano                     # Lightweight terminal text editor
    jq                       # Command-line JSON processor
    net-tools                # Legacy net utilities (ifconfig, netstat, …)
    expect                   # Scripts interactive command-line programs
    libargon2                # Argon2 password hashing (CLI + library)

    # --- Terminal / shell enhancements ---
    eza                      # Modern `ls` replacement
    btop                     # Resource monitor (CPU / memory / network)
    zellij                   # Terminal multiplexer
    fastfetch                # System information fetch tool
    byobu                    # Terminal multiplexer
    tmux                     # Terminal multiplexer

    # --- File sync & dotfile management ---
    rsync                    # Fast incremental file copying / backup
    unison                   # Bidirectional file synchroniser
    stow                     # Symlink farm manager for dotfiles

    # --- Editors & IDEs ---
    jetbrains.pycharm        # Python IDE
    jetbrains.phpstorm       # PHP IDE
    jetbrains.webstorm       # JavaScript / web IDE
    pkgs-insecure.sublime4   # Sublime Text (needs OpenSSL 1.1, see pkgs-insecure)
    obsidian                 # Note-taking app
    moji                     # Markdown viewer/editor (built above); default .md opener

    # --- Development tooling ---
    jdk                      # Java Development Kit
    uv                       # Fast Python package / project manager
    bundler                  # Ruby dependency manager
    php                      # PHP interpreter (CLI)
    phpPackages.composer     # PHP dependency manager
    subversion               # Subversion version control (svn)
    (jekyll.override {       # Static site generator; full variant bundles
      withOptionalDependencies = true;  # jekyll-feed etc. needed by the blog
    })
    imagemagick              # `convert` — used by the blog's og_image plugin
    exiftool                 # Embeds bibliographic metadata in the blog's PDF editions
    commonmeta               # Scholarly-metadata format converter (built above)
    sequoia-cli              # Publish blog posts to the AT Protocol (built above)
    commitizen               # Conventional-commit helper
    github-cli               # GitHub CLI (`gh`)
    claude-code              # Anthropic Claude Code CLI
    codex                    # OpenAI Codex CLI coding agent
    pkg-config               # Package checker
    libmysqlclient           # MySQL client
    mariadb                  # MariaDB
    mariadb-connector-c      # MariaDB C files
    mariadb-connector-c.dev  # MariaDB C headers
    postgresql               # Postgres
    stdenv.cc                # Native C/C++ compiler and linker
    gnumake                  # Build toolchain
    binutils
    cmake
    ninja
    meson
    autoconf
    automake
    libtool
    m4
    patch
    tcpdump
    # docker CLI is provided by virtualisation.docker (see virtualisation.nix)

    # --- Web browsers & automation ---
    # Chromium stands in for Google Chrome, which cannot be installed here.
    # Chrome is a Google-built binary that nixpkgs only repackages, and Google
    # publishes no ARM Linux build, so meta.platforms is:
    #
    #   x86_64-linux, x86_64-darwin, aarch64-darwin
    #
    # The original host is aarch64-linux (ARM VM on Apple Silicon), so evaluation fails
    # with "not available on the requested hostPlatform". allowUnsupportedSystem
    # does NOT rescue it: that flag only suppresses the platform check, and the
    # build then fails anyway because there is no ARM binary to fetch. Emulating
    # x86_64 via binfmt would work in principle but is a poor trade for a
    # browser, which wants native graphics and CPU.
    #
    # On an x86_64-linux host, drop Chromium and uncomment the line below
    # (allowUnfree is already set in modules/nixos/nix.nix, so no extra config
    # is needed). Chrome's desktop ID is google-chrome.desktop, so the dock
    # favourites in home/martin/gnome.nix need updating to match.
    #
    #   google-chrome        # Web browser (unfree; desktop ID google-chrome.desktop)
    #
    # If the draw is Google-account sync or Widevine DRM rather than Chrome
    # itself, brave or vivaldi are Chromium-based, build on aarch64-linux, and
    # keep working sync — Google restricts the sync API to official builds.
    chromium                 # Web browser (desktop ID chromium-browser.desktop)
    puppeteer-cli            # Headless-Chrome automation CLI (bundles its own Chromium)
    chromedriver             # Add chromedriver for selenium
    tor-browser'             # Tor Browser (official nightly aarch64 build on ARM, see above)

    # --- Networking & VPN ---
    tailscale                # Mesh VPN
    tailscale-systray        # Tailscale system-tray indicator
    openvpn3                 # OpenVPN 3 client

    # --- Security & authentication ---
    _1password-gui           # 1Password desktop app
    _1password-cli           # 1Password CLI (`op`)
    pkgs-insecure.bitwarden-desktop  # Bitwarden desktop app (EOL Electron, see pkgs-insecure)
    bitwarden-cli            # Bitwarden CLI (`bw`)
    yubikey-manager          # YubiKey configuration tool (ykman)
    yubikey-personalization  # YubiKey personalization utilities
    # NOTE: no OpenPGP entries are needed here — programs.gnupg.agent
    # (security.nix) installs gnupg itself and runs gpg-agent, GNOME supplies
    # pinentry-gnome3, and pcscd (security.nix) covers smartcard/YubiKey
    # OpenPGP. gpa was tried as a GUI front-end and removed: it crashes at
    # startup on this system.

    # --- Office & research ---
    libreoffice-fresh        # Office suite
    zotero                   # Reference / citation manager
    pdftk                    # PDF manipulation toolkit

    # --- Graphics & media ---
    audacity                 # Audio editor
    gimp-with-plugins        # Image editor with plugins
    rhythmbox                # GNOME music player
    vlc                      # Media player
    ymuse                    # GTK client for the Music Player Daemon (MPD)
    yt-dlp                   # CLI media downloader

    # --- Communication ---
    # Proton Mail bridge + Thunderbird are configured in email.nix.
    signal-desktop           # Signal messenger
    telegram-desktop         # Telegram messenger
    holos                    # holos.social desktop client (AppImage wrap, built above)

    # --- System & disk utilities ---
    libnotify                # Desktop notifications from the CLI (notify-send)
    xclip                    # X11 clipboard CLI (X apps/XWayland; Wayland side is
                             # wl-clipboard, from transcribe-client.nix)
    file-roller              # Zip file handler
    gparted                  # Partition editor
    safeeyes                 # Break reminder to reduce eye strain
    remmina                  # RDP client

    # --- Miscellaneous (tools installed from third-party flakes/systems) ---
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default                # Terminal multiplexer for AI agents
    inputs.worksummary.packages.${pkgs.stdenv.hostPlatform.system}.default          # Self-authored work-logging CLI; bundles its own fish completion.
  ];

  # nix-ld provides a stub dynamic loader at the conventional /lib64/ld-linux
  # path (which does not otherwise exist on NixOS), so prebuilt, non-Nix ELF
  # binaries can find an interpreter and their libraries. uv needs this: it
  # downloads standalone CPython builds from python-build-standalone that are
  # dynamically linked against a normal FHS layout, and without nix-ld they fail
  # to execute with "no such file or directory" on the missing loader.
  programs.nix-ld.enable = true;

  # We have to set the environment variable for pkg-config to be able to find
  # the C header files for MariaDB. This let us buils mysqlclient in python.
  environment.sessionVariables.PKG_CONFIG_PATH =
    lib.makeSearchPath "lib/pkgconfig" [
      pkgs.mariadb-connector-c.dev
    ];

  # The Zotero↔LibreOffice integration is registered per-user via Home Manager
  # (home/martin/zotero.nix), not a system.userActivationScripts fragment: the
  # latter runs user activation for every session including gdm-greeter, which
  # hung switch-to-configuration on a D-Bus timeout.
}
