# Cross-host checks: the Parallels guest (`nixos`) and the bare-metal AMD
# machine (`nixos-amd64`) must come out as the same system and the same home
# directory, differing only where the hardware genuinely differs.
#
# Pure evaluation — nothing is built, so the x86_64 host can be checked from
# the aarch64 guest and vice versa. Run with scripts/check_hosts.sh, which
# prints every check and exits non-zero if any is false.
#
# Each check compares what the two configurations *evaluate to* (package
# names, managed files, units, settings), never how the modules are written,
# so the modules can be reorganised freely as long as the result holds.
let
  flake = builtins.getFlake (toString ./..);
  lib = flake.inputs.nixpkgs.lib;

  vm = flake.nixosConfigurations.nixos.config;
  metal = flake.nixosConfigurations.nixos-amd64.config;

  hm = cfg: cfg.home-manager.users.martin;

  names = pkgs: lib.unique (lib.sort builtins.lessThan (map lib.getName pkgs));

  # only: what is in `a` but not in `b`.
  only = a: b: lib.subtractLists b a;

  # Things that legitimately exist on one host only. Anything else that
  # differs is a parity bug.
  vmOnlySystemPackages = [
    "prl-tools" # Parallels guest tools
  ];
  metalOnlySystemPackages = [ # sorted, as `only` returns them
    # Firmware updates for real hardware (hosts/nixos-amd64).
    "fwupd"
    # GNOME's file indexer: switched off on the guest (power.nix) because the
    # XDG folders there are fuse-mounted Mac shares; on local disks it is the
    # stock GNOME behaviour.
    "localsearch"
  ];
  vmOnlyHomeFiles = [
    "/home/martin/.config/monitors.xml" # pins the virtual display
    "/home/martin/.config/systemd/user/default.target.wants/mac-folder-links.service"
    "/home/martin/.config/systemd/user/graphical-session.target.wants/transcribe-client.service"
    "/home/martin/.config/systemd/user/mac-folder-links.service"
    "/home/martin/.config/systemd/user/transcribe-client.service"
    "/home/martin/.local/share/mpe-transcribe/transcribe.toml" # Mac-host client
  ];
  vmOnlyUserServices = [
    "mac-folder-links"
    "transcribe-client"
  ];

  homeFiles = cfg: lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: f: "${(hm cfg).home.homeDirectory}/${f.target}")
      (lib.filterAttrs (_: f: f.enable) (hm cfg).home.file));

  userServices = cfg: builtins.attrNames (hm cfg).systemd.user.services;

  systemPkgs = cfg: names cfg.environment.systemPackages;
  userPkgs = cfg: names cfg.users.users.martin.packages;
  # ghostty is the same program on both; the guest wraps it for software GL
  # (home/martin/ghostty.nix), which only changes the derivation name.
  homePkgs = cfg: names (map
    (p: if lib.getName p == "ghostty-softgl" then { pname = "ghostty"; } else p)
    (hm cfg).home.packages);
  fonts = cfg: names cfg.fonts.packages;

  # The ghostty software-GL override is the one intended settings difference.
  ghosttySettings = cfg: removeAttrs (hm cfg).programs.ghostty.settings [ "env" ];

  groups = cfg: lib.sort builtins.lessThan cfg.users.users.martin.extraGroups;

  enabledServices = cfg: lib.sort builtins.lessThan (builtins.attrNames
    (lib.filterAttrs (_: s: s.enable && s.wantedBy != [ ]) cfg.systemd.services));
  # System services that only make sense on one side.
  vmOnlyServices = [ "prltoolsd" "powertop" ];
  metalOnlyServices = [
    # The Parallels module turns timesyncd off (the Mac host keeps the guest's
    # clock); real hardware needs its own NTP client.
    "systemd-timesyncd"
  ];
in
{
  # --- The bare-metal host is what it claims to be -----------------------
  metal-is-x86_64 = metal.nixpkgs.hostPlatform.system == "x86_64-linux";
  metal-has-no-parallels = !metal.hardware.parallels.enable;
  metal-has-own-hostname = metal.networking.hostName != vm.networking.hostName;
  metal-amd-microcode = metal.hardware.cpu.amd.updateMicrocode;
  metal-firmware = metal.hardware.enableRedistributableFirmware;
  metal-kvm = builtins.elem "kvm-amd" metal.boot.kernelModules;
  metal-no-virtio-gpu-initrd =
    !(builtins.elem "virtio_gpu" metal.boot.initrd.kernelModules);
  metal-nvme-in-initrd =
    builtins.elem "nvme" metal.boot.initrd.availableKernelModules;
  metal-root-not-the-vm-disk =
    metal.fileSystems."/".device != vm.fileSystems."/".device;
  metal-boot-is-efi-vfat = metal.fileSystems."/boot".fsType == "vfat";
  metal-uefi-systemd-boot = metal.boot.loader.systemd-boot.enable;
  metal-same-kernel-series =
    metal.boot.kernelPackages.kernel.version == vm.boot.kernelPackages.kernel.version;

  # --- The Parallels guest keeps its hardware-specific pieces -------------
  vm-is-aarch64 = vm.nixpkgs.hostPlatform.system == "aarch64-linux";
  vm-has-parallels = vm.hardware.parallels.enable;
  vm-hostname-unchanged = vm.networking.hostName == "nixos";
  vm-virtio-gpu-initrd = builtins.elem "virtio_gpu" vm.boot.initrd.kernelModules;
  vm-monitors-pinned =
    builtins.elem "/home/martin/.config/monitors.xml" (homeFiles vm);
  vm-no-amd-microcode = !vm.hardware.cpu.amd.updateMicrocode;

  # --- Same packages -------------------------------------------------------
  system-packages-vm-only =
    only (systemPkgs vm) (systemPkgs metal) == vmOnlySystemPackages;
  system-packages-metal-only =
    only (systemPkgs metal) (systemPkgs vm) == metalOnlySystemPackages;
  user-packages-identical = userPkgs vm == userPkgs metal;
  home-packages-identical = homePkgs vm == homePkgs metal;
  fonts-identical = fonts vm == fonts metal;

  # --- Same home directory -------------------------------------------------
  home-files-vm-only = only (homeFiles vm) (homeFiles metal) == vmOnlyHomeFiles;
  home-files-metal-only = only (homeFiles metal) (homeFiles vm) == [ ];
  user-services-vm-only =
    only (userServices vm) (userServices metal) == vmOnlyUserServices;
  user-services-metal-only = only (userServices metal) (userServices vm) == [ ];
  # Compared as JSON: GVariant values carry functions, which `==` rejects.
  dconf-identical = builtins.toJSON (hm vm).dconf.settings
    == builtins.toJSON (hm metal).dconf.settings;
  ghostty-settings-identical = ghosttySettings vm == ghosttySettings metal;
  ghostty-hardware-gl-on-metal = !((hm metal).programs.ghostty.settings ? env);
  git-identical = (hm vm).programs.git.settings == (hm metal).programs.git.settings;
  beets-identical = (hm vm).programs.beets.settings == (hm metal).programs.beets.settings;
  home-activation-identical =
    builtins.attrNames (hm vm).home.activation
    == builtins.attrNames (hm metal).home.activation;
  home-state-version-identical =
    (hm vm).home.stateVersion == (hm metal).home.stateVersion;

  # --- Same system behaviour -----------------------------------------------
  groups-identical = groups vm == groups metal;
  shell-identical = lib.getName vm.users.users.martin.shell
    == lib.getName metal.users.users.martin.shell;
  locale-identical = vm.i18n.defaultLocale == metal.i18n.defaultLocale
    && vm.time.timeZone == metal.time.timeZone
    && vm.console.keyMap == metal.console.keyMap
    && vm.services.xserver.xkb.layout == metal.services.xserver.xkb.layout
    && vm.services.xserver.xkb.variant == metal.services.xserver.xkb.variant;
  keyd-identical = vm.services.keyd.keyboards == metal.services.keyd.keyboards;
  # Minus 127.0.0.2, which NixOS maps to each machine's own hostname.
  hosts-identical = removeAttrs vm.networking.hosts [ "127.0.0.2" ]
    == removeAttrs metal.networking.hosts [ "127.0.0.2" ];
  firewall-identical = vm.networking.firewall.allowedUDPPorts
    == metal.networking.firewall.allowedUDPPorts
    && vm.networking.firewall.trustedInterfaces
    == metal.networking.firewall.trustedInterfaces;
  u2f-identical = vm.security.pam.u2f.settings == metal.security.pam.u2f.settings;
  state-version-identical = vm.system.stateVersion == metal.system.stateVersion;
  plymouth-identical = vm.boot.plymouth.theme == metal.boot.plymouth.theme;
  system-services-vm-only =
    only (enabledServices vm) (enabledServices metal) == vmOnlyServices
    || only (enabledServices vm) (enabledServices metal) == lib.reverseList vmOnlyServices;
  system-services-metal-only =
    only (enabledServices metal) (enabledServices vm) == metalOnlyServices;
  dns-per-host = lib.hasPrefix "45.90.28.0#${metal.networking.hostName}-"
    (builtins.head metal.services.resolved.settings.Resolve.DNS);
}
