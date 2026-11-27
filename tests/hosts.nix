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
  ];
  vmOnlyUserServices = [
    "mac-folder-links"
    "transcribe-client" # hotkey + paste only; the Mac host transcribes
  ];

  # Voice transcription follows the hardware (home/martin/transcribe.nix): the
  # guest is a client of the Mac, and a machine with an NVIDIA card does its
  # own transcription under a unit of its own. Both keep their settings in
  # the same transcribe.toml; a machine with neither has none.
  hasNvidia = cfg: builtins.elem "nvidia" cfg.services.xserver.videoDrivers;
  transcribeToml = "/home/martin/.local/share/mpe-transcribe/transcribe.toml";
  standaloneTranscribeFiles = [
    "/home/martin/.config/systemd/user/graphical-session.target.wants/transcribe.service"
    "/home/martin/.config/systemd/user/transcribe.service"
  ];

  # sshfs mounts a host has opted out of (sshfsMounts.exclude, set in its own
  # file) are missing there by design: their units, and the files behind them.
  excludedMountServices = cfg: map (n: "sshfs-${n}") cfg.sshfsMounts.exclude;
  excludedMountFiles = cfg: builtins.filter
    (f: builtins.any (u: lib.hasSuffix "/${u}.service" f) (excludedMountServices cfg))
    (homeFiles vm);

  # Fixes for one machine's own hardware, which no other machine should have.
  quirkServices = {
    animal = [ "usb-hub-recover" ]; # modules/hardware/usb-hub-recover.nix
  };

  # User services one machine has for its own disks, and the files behind
  # them.
  hostUserServices = {
    animal = [ "central-home-links" ]; # hosts/animal/central-home.nix
  };
  hostHomeFiles = name: lib.concatMap
    (u: [
      "/home/martin/.config/systemd/user/default.target.wants/${u}.service"
      "/home/martin/.config/systemd/user/${u}.service"
    ])
    (hostUserServices.${name} or [ ]);

  # The Unison profile (home/martin/unison.nix), as the text that lands in
  # ~/.unison/default.prf, split into the folders it synchronises (in the
  # order Unison takes them) and everything else: roots, options, ignores.
  unisonLines = cfg:
    let f = (hm cfg).home.file.".unison/default.prf"; in
    lib.splitString "\n" (if f.text != null then f.text else builtins.readFile f.source);
  isUnisonPath = lib.hasPrefix "path = ";
  unisonPaths = cfg:
    map (lib.removePrefix "path = ") (builtins.filter isUnisonPath (unisonLines cfg));
  unisonWithoutPaths = cfg: builtins.filter (l: !(isUnisonPath l)) (unisonLines cfg);

  # Machines that synchronise folders of their own choosing. Any other
  # machine synchronises the same ones as the guest.
  hostUnisonPaths = {
    animal = [
      "Documents/Work/Uni"
      "Documents/Work/Consulting"
      "Documents/Personal"
      "Documents/Work/Programming"
      "Documents/Work/Michigan"
      ".config/fish"
    ];
  };

  sorted = lib.sort builtins.lessThan;
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

  # Minus the filesystem tools, which follow each machine's own disks
  # (btrfs-progs for a btrfs root, e2fsprogs for ext4): NixOS derives them
  # from the hardware scan and lists them in system.fsPackages.
  systemPkgs = cfg:
    only (names cfg.environment.systemPackages) (names cfg.system.fsPackages);
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

  # GNOME's keyboard input sources, as dconf prints them, and the dconf
  # settings without them.
  inputSourcesKey = "org/gnome/desktop/input-sources";
  inputSources = cfg: toString (hm cfg).dconf.settings.${inputSourcesKey}.sources;
  onlyInputSource = name: "@a(ss) [@(ss) ('xkb','${name}')]";
  withoutInputSources = settings: settings // {
    ${inputSourcesKey} = removeAttrs settings.${inputSourcesKey} [ "sources" ];
  };

  enabledServices = cfg: lib.sort builtins.lessThan (builtins.attrNames
    (lib.filterAttrs (_: s: s.enable && s.wantedBy != [ ]) cfg.systemd.services));

  # --- Every machine, the guest included ----------------------------------
  # The immurok fingerprint key (modules/nixos/immurok): a daemon that talks
  # to the key over Bluetooth, an agent in the login session for its dialogs,
  # and a PAM module that asks the daemon for a fingerprint.
  everyHost = { nixos = vm; } // lib.mapAttrs (_: host: host.config) metalHosts;
  immurokChecks = cfg:
    let
      daemon = cfg.systemd.services.immurok-daemon or null;
      agent = cfg.systemd.user.services.immurok-session-agent or null;
      account = cfg.users.users.immurok or null;
      authRules = service: cfg.security.pam.services.${service}.rules.auth;
    in
    {
      immurok-installed = builtins.elem "immurok" (systemPkgs cfg);
      immurok-daemon-starts-at-boot = daemon != null && daemon.enable
        && builtins.elem "multi-user.target" daemon.wantedBy;
      # The daemon holds the pairing key, so it has an account of its own
      # that nobody logs in to.
      immurok-daemon-has-its-own-account = account != null
        && account.isSystemUser && account.group == "immurok"
        && cfg.users.groups ? immurok;
      # That account may talk to BlueZ, and there is a Bluetooth stack to
      # talk to.
      immurok-may-use-bluetooth = cfg.hardware.bluetooth.enable
        && builtins.elem "immurok" (names cfg.services.dbus.packages);
      immurok-agent-in-login-sessions = agent != null
        && builtins.elem "default.target" agent.wantedBy;
      # A fingerprint is an optional first factor for sudo and polkit: asked
      # for before the YubiKey and the password, and never required, so a
      # machine without the key to hand behaves as it did before.
      immurok-fingerprint-optional-and-first = builtins.all
        (service:
          let
            rules = authRules service;
            fingerprint = rules.immurok or null;
          in
          fingerprint != null && fingerprint.enable
          && fingerprint.control == "sufficient"
          && lib.hasSuffix "/lib/security/pam_immurok.so" fingerprint.modulePath
          && fingerprint.order < rules.u2f.order
          && rules.u2f.order < rules.unix.order)
        [ "sudo" "polkit-1" ];
      # Nowhere else: the login and lock screens are unlocked by the daemon
      # itself, not through PAM.
      immurok-only-for-sudo-and-polkit = builtins.attrNames
        (lib.filterAttrs (_: service: service.rules.auth ? immurok)
          cfg.security.pam.services)
        == [ "polkit-1" "sudo" ];
    };

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
    # The guest's own Unison folders are not disturbed by another machine's.
    vm-unison-paths = unisonPaths vm == [
      "Documents/Work/Uni"
      "Documents/Work/Programming"
      "Documents/Work/Consulting"
      "Documents/Personal"
      "Documents/Programming"
      ".config/fish"
    ];
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
      # Exactly one bootloader, installed as an EFI program: systemd-boot, or
      # GRUB for a host that imports modules/hardware/grub.nix. Both or
      # neither would leave a rebuild with no boot menu to write to.
      one-uefi-bootloader =
        metal.boot.loader.systemd-boot.enable != metal.boot.loader.grub.enable
        && (!metal.boot.loader.grub.enable
          || (metal.boot.loader.grub.efiSupport
            && metal.boot.loader.grub.device == "nodev"));
      # Each boot entry keeps a kernel and an initrd on the EFI partition.
      boot-menu-kept-short =
        (if metal.boot.loader.grub.enable
        then metal.boot.loader.grub.configurationLimit
        else metal.boot.loader.systemd-boot.configurationLimit) <= 10;
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
      home-files-vm-only = only (homeFiles vm) (homeFiles metal)
        == sorted (vmOnlyHomeFiles ++ excludedMountFiles metal
          ++ lib.optional (!hasNvidia metal) transcribeToml);
      home-files-metal-only = only (homeFiles metal) (homeFiles vm)
        == sorted (lib.optionals (hasNvidia metal) standaloneTranscribeFiles
          ++ hostHomeFiles name);
      user-services-vm-only = only (userServices vm) (userServices metal)
        == sorted (vmOnlyUserServices ++ excludedMountServices metal);
      user-services-metal-only = only (userServices metal) (userServices vm)
        == sorted (lib.optional (hasNvidia metal) "transcribe"
          ++ (hostUserServices.${name} or [ ]));
      # A machine with the card to do it transcribes for itself, and only
      # for itself: no client of anything, and no network listener.
      transcribe-standalone-on-nvidia = !(hasNvidia metal)
        || builtins.all (lib.hasSuffix " transcribe --standalone") (lib.toList
          (hm metal).systemd.user.services.transcribe.Service.ExecStart);
      # An excluded mount is gone from the system side too: no mountpoint is
      # created for it.
      excluded-mounts-have-no-mountpoint = builtins.all
        (n: !(builtins.elem "d /home/martin/mounts/${n} 0755 martin users -"
          metal.systemd.tmpfiles.rules))
        metal.sshfsMounts.exclude;
      # Compared as JSON: GVariant values carry functions, which `==` rejects.
      # Minus the keyboard layout, which follows the hardware (below).
      dconf-identical = builtins.toJSON (withoutInputSources (hm vm).dconf.settings)
        == builtins.toJSON (withoutInputSources (hm metal).dconf.settings);
      ghostty-settings-identical = ghosttySettings vm == ghosttySettings metal;
      ghostty-hardware-gl = !((hm metal).programs.ghostty.settings ? env);
      git-identical = (hm vm).programs.git.settings == (hm metal).programs.git.settings;
      beets-identical =
        (hm vm).programs.beets.settings == (hm metal).programs.beets.settings;
      # Unison talks to the same server with the same options and ignores
      # everywhere; only the folders synchronised are a machine's own choice.
      unison-profile-identical = unisonWithoutPaths vm == unisonWithoutPaths metal;
      unison-paths = unisonPaths metal == (hostUnisonPaths.${name} or (unisonPaths vm));
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
        && vm.services.xserver.xkb.options == metal.services.xserver.xkb.options;
      # The keyboard layout is the hardware's: the guest is typed on the
      # Mac's keyboard (British, Apple's arrangement), real hardware on a PC
      # keyboard in the US arrangement. Whichever it is, the desktop's input
      # source, the console and the keyd chords all agree with it.
      keyboard-layout-follows-hardware =
        [ vm.services.xserver.xkb.layout vm.services.xserver.xkb.variant ] == [ "gb" "mac" ]
        && [ metal.services.xserver.xkb.layout metal.services.xserver.xkb.variant ] == [ "us" "" ]
        && inputSources vm == onlyInputSource "gb+mac"
        && inputSources metal == onlyInputSource "us"
        && vm.console.keyMap == "uk" && metal.console.keyMap == "us";
      # Same chords everywhere (Ctrl+Shift+3 for £, Ctrl+4 for #), sent as
      # whatever each layout types that character with. The US layout has no
      # £ to send.
      keyd-chords-fit-the-layout =
        vm.services.keyd.keyboards.default.settings
          == { main = { }; "control+shift"."3" = "S-3"; control."4" = "G-3"; }
        && metal.services.keyd.keyboards.default.settings
          == { main = { }; control."4" = "S-3"; }
        && vm.services.keyd.keyboards.default.ids
          == metal.services.keyd.keyboards.default.ids;
      # Minus 127.0.0.2, which NixOS maps to each machine's own hostname.
      hosts-identical = removeAttrs vm.networking.hosts [ "127.0.0.2" ]
        == removeAttrs metal.networking.hosts [ "127.0.0.2" ];
      firewall-identical = vm.networking.firewall.allowedUDPPorts
        == metal.networking.firewall.allowedUDPPorts
        && vm.networking.firewall.trustedInterfaces
        == metal.networking.firewall.trustedInterfaces;
      u2f-identical = vm.security.pam.u2f.settings == metal.security.pam.u2f.settings;
      # espanso is the Wayland build, run as a declared user service, on
      # every machine (modules/nixos/espanso.nix).
      espanso-identical = metal.services.espanso.enable
        && vm.services.espanso.enable
        # For martin only (not the login screen's session), and seeded with
        # a starter configuration, without which it cannot start.
        && builtins.all
          (cfg: cfg.systemd.user.services.espanso.unitConfig.ConditionGroup == "uinput"
            && cfg.systemd.user.services.espanso.serviceConfig ? ExecStartPre)
          [ vm metal ]
        && (metal.services.espanso.package.waylandSupport or false)
        && (vm.services.espanso.package.waylandSupport or false);
      # (system.stateVersion is deliberately not compared: it records the
      # release each machine was first installed with, which may differ.)
      plymouth-identical = vm.boot.plymouth.theme == metal.boot.plymouth.theme;
      system-services-vm-only =
        only (enabledServices vm) (enabledServices metal) == vmOnlyServices;
      system-services-metal-only =
        withoutGpuDriver (only (enabledServices metal) (enabledServices vm))
        == sorted (metalOnlyServices ++ (quirkServices.${name} or [ ]));
      dns-per-host = lib.hasPrefix "45.90.28.0#${metal.networking.hostName}-"
        (builtins.head metal.services.resolved.settings.Resolve.DNS);
    }
    # The first bare-metal machine: AMD CPU, NVIDIA card.
    // lib.optionalAttrs (name == "nixos-amd64") {
      amd-microcode = metal.hardware.cpu.amd.updateMicrocode;
      kvm = builtins.elem "kvm-amd" metal.boot.kernelModules;
      nvidia-driver = builtins.elem "nvidia" metal.services.xserver.videoDrivers;
      systemd-boot = metal.boot.loader.systemd-boot.enable;
    }
    # A dual-boot machine whose firmware starts GRUB. If this host went back
    # to systemd-boot, rebuilds would stop reaching the menu it boots from and
    # every reboot would land in a stale generation.
    // lib.optionalAttrs (name == "animal") {
      boots-with-grub =
        metal.boot.loader.grub.enable && !metal.boot.loader.systemd-boot.enable;
      # The same firmware boot entry the base install registered.
      grub-on-the-efi-partition = metal.boot.loader.efi.efiSysMountPoint == "/boot"
        && metal.boot.loader.efi.canTouchEfiVariables;
      other-systems-in-boot-menu = metal.boot.loader.grub.useOSProber;
      nvidia-open-module = metal.hardware.nvidia.open;
      # waldorf is the other Linux on this machine's own disks: it can never
      # be mounted from here, and trying held up every login.
      no-waldorf-mount = metal.sshfsMounts.exclude == [ "waldorf" ]
        && !(builtins.elem "sshfs-waldorf" (userServices metal));
      # The older home partition is mounted at boot, without
      # holding the boot up if the drive is missing — and nothing may create
      # or adjust its mountpoint, which once mounted is the volume's own root
      # directory (hosts/animal/central-home.nix has the story).
      central-home-mounted =
        let fs = metal.fileSystems."/home/martin/mounts/central_home"; in
        fs.fsType == "ext4"
        && lib.hasPrefix "/dev/disk/by-uuid/" fs.device
        && builtins.elem "nofail" fs.options
        && !(builtins.any (lib.hasInfix "/home/martin/mounts/central_home")
          metal.systemd.tmpfiles.rules);
      # ~/Documents, ~/Music and ~/Pictures are linked onto it, and only when
      # it is actually mounted.
      central-home-folders-linked =
        let unit = (hm metal).systemd.user.services.central-home-links; in
        unit.Unit.ConditionPathIsMountPoint == "/home/martin/mounts/central_home"
        && unit.Install.WantedBy == [ "default.target" ];
      # PCIe link power saving stays off, as on this machine's Ubuntu install
      # (hosts/animal/default.nix has the story).
      pcie-links-stay-awake =
        builtins.elem "pcie_aspm.policy=performance" metal.boot.kernelParams;
      # Nor do the NVMe drives put themselves into their own idle states: the
      # root drive vanished on a boot where the links were already held awake.
      nvme-drives-stay-awake =
        builtins.elem "nvme_core.default_ps_max_latency_us=0" metal.boot.kernelParams;
      # The login screen is told which of the three monitors is primary.
      login-screen-monitor-layout = metal.environment.etc ? "xdg/monitors.xml";
    };
in
vmChecks
// lib.concatMapAttrs
  (name: cfg: lib.mapAttrs' (check: lib.nameValuePair "${name}: ${check}")
    (immurokChecks cfg))
  everyHost
// lib.concatMapAttrs
  (name: host: lib.mapAttrs' (check: lib.nameValuePair "${name}: ${check}")
    (metalChecks name host))
  metalHosts
