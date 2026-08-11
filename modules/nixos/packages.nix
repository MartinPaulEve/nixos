# System-wide packages and package-related activation.
{ pkgs, inputs, lib, ... }:

let
  # A pkgs instance that permits the (insecure) OpenSSL 1.1 that Sublime Text needs.
  pkgs-insecure = import inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [ "openssl-1.1.1w" ];
    };
  };

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
    net-tools                # Legacy net utilities (ifconfig, netstat, …)
    expect                   # Scripts interactive command-line programs

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

    # --- Development tooling ---
    jdk                      # Java Development Kit
    uv                       # Fast Python package / project manager
    bundler                  # Ruby dependency manager
    jekyll                   # Static site generator
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

    # --- Networking & VPN ---
    tailscale                # Mesh VPN
    tailscale-systray        # Tailscale system-tray indicator
    openvpn3                 # OpenVPN 3 client

    # --- Security & authentication ---
    _1password-gui           # 1Password desktop app
    _1password-cli           # 1Password CLI (`op`)
    yubikey-manager          # YubiKey configuration tool (ykman)
    yubikey-personalization  # YubiKey personalization utilities

    # --- Office & research ---
    libreoffice-fresh        # Office suite
    zotero                   # Reference / citation manager
    pdftk                    # PDF manipulation toolkit

    # --- Graphics & media ---
    gimp-with-plugins        # Image editor with plugins
    vlc                      # Media player
    ymuse                    # GTK client for the Music Player Daemon (MPD)
    yt-dlp                   # CLI media downloader

    # --- Communication ---
    # Proton Mail bridge + Thunderbird are configured in email.nix.
    signal-desktop           # Signal messenger
    telegram-desktop         # Telegram messenger

    # --- System & disk utilities ---
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
