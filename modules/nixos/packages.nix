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
    wget
    curl
    nano
    _1password-gui
    _1password-cli
    jetbrains.pycharm
    jetbrains.phpstorm
    jetbrains.webstorm
    chromium
    stow
    gimp-with-plugins
    jekyll
    bundler
    tailscale
    tailscale-systray
    pdftk
    net-tools
    openvpn3
    yubikey-manager
    yubikey-personalization
    eza
    btop
    zellij
    unison
    rsync
    pkgs-insecure.sublime4
    libreoffice-fresh
    zotero
    jdk
    gparted
    uv
    commitizen
    # docker CLI is provided by virtualisation.docker (see virtualisation.nix)
    github-cli
    fastfetch
    claude-code
    # herdr — https://github.com/ogulcancelik/herdr
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
    ymuse
    puppeteer-cli
    vlc
    protonmail-bridge-gui
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
