# System-wide packages and package-related activation.
{ pkgs, inputs, ... }:

let
  # A pkgs instance that permits the (insecure) OpenSSL 1.1 that Sublime Text needs.
  pkgs-insecure = import inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [ "openssl-1.1.1w" ];
    };
  };
in
{
  environment.systemPackages = with pkgs; [
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

    # --- File sync & dotfile management ---
    rsync                    # Fast incremental file copying / backup
    unison                   # Bidirectional file synchroniser
    stow                     # Symlink farm manager for dotfiles

    # --- Editors & IDEs ---
    jetbrains.pycharm        # Python IDE
    jetbrains.phpstorm       # PHP IDE
    jetbrains.webstorm       # JavaScript / web IDE
    pkgs-insecure.sublime4   # Sublime Text (needs OpenSSL 1.1, see pkgs-insecure)

    # --- Development tooling ---
    jdk                      # Java Development Kit
    uv                       # Fast Python package / project manager
    bundler                  # Ruby dependency manager
    jekyll                   # Static site generator
    commitizen               # Conventional-commit helper
    github-cli               # GitHub CLI (`gh`)
    claude-code              # Anthropic Claude Code CLI
    codex                    # OpenAI Codex CLI coding agent
    # docker CLI is provided by virtualisation.docker (see virtualisation.nix)

    # --- Web browsers & automation ---
    google-chrome            # Web browser (unfree; desktop ID google-chrome.desktop)
    puppeteer-cli            # Headless-Chrome automation CLI (bundles its own Chromium)

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
    gparted                  # Partition editor
    safeeyes                 # Break reminder to reduce eye strain

    # --- Miscellaneous (tools installed from third-party flakes/systems) ---
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default                # Terminal multiplexer for AI agents
    inputs.worksummary.packages.${pkgs.stdenv.hostPlatform.system}.default          # Self-authored work-logging CLI; bundles its own fish completion.
  ];

  # The Zotero↔LibreOffice integration is registered per-user via Home Manager
  # (home/martin/zotero.nix), not a system.userActivationScripts fragment: the
  # latter runs user activation for every session including gdm-greeter, which
  # hung switch-to-configuration on a D-Bus timeout.
}
