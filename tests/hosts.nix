# Cross-host checks: the Parallels guest (`nixos`) and every bare-metal
# machine under hosts/ must come out as the same system and the same home
# directory, differing only where the hardware genuinely differs.
#
# Pure evaluation — nothing is built, so x86_64 hosts can be checked from the
# aarch64 guest and vice versa. Run with scripts/check_hosts.sh, which prints
# every check and exits non-zero if any is false.
#
# Each check compares what the configurations *evaluate to* (package names,
# managed files, units, settings), never how the modules are written, so the
# modules can be reorganised freely as long as the result holds.
#
# A host added under hosts/ is picked up here automatically and held to the
# same checks; nothing in this file names it.
let
  flake = builtins.getFlake (toString ./..);
  lib = flake.inputs.nixpkgs.lib;

  # The reference machine, and everything compared against it. nixos-vm-x86
  # is the guest's own config rebuilt for QEMU, not a machine of its own.
  vm = flake.nixosConfigurations.nixos.config;
  metalHosts = removeAttrs flake.nixosConfigurations [ "nixos" "nixos-vm-x86" ];

  hm = cfg: cfg.home-manager.users.martin;

  names = pkgs: lib.unique (lib.sort builtins.lessThan (map lib.getName pkgs));

  # only: what is in `a` but not in `b`.
  only = a: b: lib.subtractLists b a;

  # GPU driver pieces are the one open-ended hardware difference: which
  # packages and units a driver brings is the driver's business.
  # (acpid is one of them: the NVIDIA module enables it for power events.)
  isGpuDriver = n: lib.hasPrefix "nvidia" n || n == "acpid";
  withoutGpuDriver = builtins.filter (n: !(isGpuDriver n));

  # Things that legitimately exist on one side only. Anything else that
  # differs is a parity bug. Lists are sorted, as `only` returns them.
  vmOnlySystemPackages = [
    "prl-tools" # Parallels guest tools
  ];
  metalOnlySystemPackages = [
    # Firmware updates for real hardware (modules/hardware/amd.nix).
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
  vmOnlyServices = [ "powertop" "prltoolsd" ];
  metalOnlyServices = [
    # The Parallels module turns timesyncd off (the Mac host keeps the guest's
    # clock); real hardware needs its own NTP client.
    "systemd-timesyncd"
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

  # --- The Parallels guest keeps its hardware-specific pieces -------------
  vmChecks = {
    vm-is-aarch64 = vm.nixpkgs.hostPlatform.system == "aarch64-linux";
    vm-has-parallels = vm.hardware.parallels.enable;
    vm-hostname-unchanged = vm.networking.hostName == "nixos";
    vm-virtio-gpu-initrd = builtins.elem "virtio_gpu" vm.boot.initrd.kernelModules;
    vm-monitors-pinned =
      builtins.elem "/home/martin/.config/monitors.xml" (homeFiles vm);
    vm-no-amd-microcode = !vm.hardware.cpu.amd.updateMicrocode;
    vm-no-nvidia = !(builtins.elem "nvidia" vm.services.xserver.videoDrivers);
    # The x86 test VM is the guest's config, so it keeps the guest's name.
    test-vm-hostname =
      flake.nixosConfigurations.nixos-vm-x86.config.networking.hostName == "nixos";
    at-least-one-metal-host = metalHosts != { };
    # Every directory under hosts/ is a machine, with nothing to register.
    every-host-directory-is-an-output =
      builtins.all (n: flake.nixosConfigurations ? ${n})
        (builtins.attrNames (lib.filterAttrs (_: t: t == "directory")
          (builtins.readDir ../hosts)));
  };

  # --- Every bare-metal host -----------------------------------------------
  metalChecks = name: host:
    let
      metal = host.config;
    in
    {
      # It is what it claims to be.
      is-x86_64 = metal.nixpkgs.hostPlatform.system == "x86_64-linux";
      no-parallels = !metal.hardware.parallels.enable;
      # The hostname is the host's directory name, so a new machine only
      # needs a new directory.
      hostname-is-directory-name =
        metal.networking.hostName == name && builtins.pathExists (../hosts + "/${name}");
      firmware = metal.hardware.enableRedistributableFirmware;
      no-virtio-gpu-initrd =
        !(builtins.elem "virtio_gpu" metal.boot.initrd.kernelModules);
      root-not-the-vm-disk =
        metal.fileSystems."/".device != vm.fileSystems."/".device;
      boot-is-efi-vfat = metal.fileSystems."/boot".fsType == "vfat";
      uefi-systemd-boot = metal.boot.loader.systemd-boot.enable;
      same-kernel-series =
        metal.boot.kernelPackages.kernel.version == vm.boot.kernelPackages.kernel.version;
      # A host that asks for the NVIDIA driver gets all of it: the driver
      # under the display server, kernel modesetting (Wayland needs it), and
      # the module in the initrd so the boot splash draws on it.
      nvidia-complete =
        !(builtins.elem "nvidia" metal.services.xserver.videoDrivers)
        || (metal.hardware.nvidia.modesetting.enable
          && metal.hardware.graphics.enable
          && builtins.elem "nvidia_drm" metal.boot.initrd.kernelModules
          && lib.hasPrefix "nvidia" (lib.getName metal.hardware.nvidia.package));

      # Same packages.
      system-packages-vm-only =
        only (systemPkgs vm) (systemPkgs metal) == vmOnlySystemPackages;
      system-packages-metal-only =
        withoutGpuDriver (only (systemPkgs metal) (systemPkgs vm))
        == metalOnlySystemPackages;
      user-packages-identical = userPkgs vm == userPkgs metal;
      home-packages-identical = homePkgs vm == homePkgs metal;
      fonts-identical = fonts vm == fonts metal;

      # Same home directory.
      home-files-vm-only = only (homeFiles vm) (homeFiles metal) == vmOnlyHomeFiles;
      home-files-metal-only = only (homeFiles metal) (homeFiles vm) == [ ];
      user-services-vm-only =
        only (userServices vm) (userServices metal) == vmOnlyUserServices;
      user-services-metal-only = only (userServices metal) (userServices vm) == [ ];
      # Compared as JSON: GVariant values carry functions, which `==` rejects.
      dconf-identical = builtins.toJSON (hm vm).dconf.settings
        == builtins.toJSON (hm metal).dconf.settings;
      ghostty-settings-identical = ghosttySettings vm == ghosttySettings metal;
      ghostty-hardware-gl = !((hm metal).programs.ghostty.settings ? env);
      git-identical = (hm vm).programs.git.settings == (hm metal).programs.git.settings;
      beets-identical =
        (hm vm).programs.beets.settings == (hm metal).programs.beets.settings;
      home-activation-identical =
        builtins.attrNames (hm vm).home.activation
        == builtins.attrNames (hm metal).home.activation;
      home-state-version-identical =
        (hm vm).home.stateVersion == (hm metal).home.stateVersion;

      # Same system behaviour.
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
        only (enabledServices vm) (enabledServices metal) == vmOnlyServices;
      system-services-metal-only =
        withoutGpuDriver (only (enabledServices metal) (enabledServices vm))
        == metalOnlyServices;
      dns-per-host = lib.hasPrefix "45.90.28.0#${metal.networking.hostName}-"
        (builtins.head metal.services.resolved.settings.Resolve.DNS);
    }
    # The first bare-metal machine: AMD CPU, NVIDIA card.
    // lib.optionalAttrs (name == "nixos-amd64") {
      amd-microcode = metal.hardware.cpu.amd.updateMicrocode;
      kvm = builtins.elem "kvm-amd" metal.boot.kernelModules;
      nvidia-driver = builtins.elem "nvidia" metal.services.xserver.videoDrivers;
    };
in
vmChecks
// lib.concatMapAttrs
  (name: host: lib.mapAttrs' (check: lib.nameValuePair "${name}: ${check}")
    (metalChecks name host))
  metalHosts
