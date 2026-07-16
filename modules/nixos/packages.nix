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
    # docker CLI is provided by virtualisation.docker (see virtualisation.nix)

    # --- Web browsers & automation ---
    chromium                 # Web browser
    puppeteer-cli            # Headless-Chrome automation CLI

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

    # --- Communication ---
    # Proton Mail bridge + Thunderbird are configured in email.nix.
    signal-desktop           # Signal messenger
    telegram-desktop         # Telegram messenger

    # --- System & disk utilities ---
    gparted                  # Partition editor
    safeeyes                 # Break reminder to reduce eye strain

    # --- Miscellaneous ---
    # herdr — https://github.com/ogulcancelik/herdr
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Register the Zotero LibreOffice integration extension into LibreOffice.
  system.userActivationScripts.installZoteroLibreOfficeExtension = {
    text = ''
      libreoffice_program="${pkgs.libreoffice}/lib/libreoffice/program"
      zotero_oxt="${pkgs.zotero}/lib/integration/libreoffice/Zotero_LibreOffice_Integration.oxt"

      if [ -x "$libreoffice_program/unopkg" ] && [ -f "$zotero_oxt" ]; then
        (
          cd "$libreoffice_program"
          ./unopkg add --force "$zotero_oxt"
        )
      else
        echo "Could not locate LibreOffice unopkg or Zotero LibreOffice extension" >&2
      fi
    '';
  };
}
