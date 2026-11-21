{
  description = "system config";

  inputs = {
    # --- Foundations ---

    # The package set everything else is built from. Pinned to the 26.05
    # release channel; `nix flake update nixpkgs` moves the whole system forward.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Manages the per-user environment (dotfiles, shell, GNOME settings, …) as a
    # NixOS module, so the system and user config build and switch together.
    # `follows` pins it to our nixpkgs above, keeping a single nixpkgs in the closure.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Applications packaged as flakes ---

    # Self-authored work-logging CLI (see modules/nixos/packages.nix). `follows`
    # keeps it on our nixpkgs so no second copy is fetched. Pull the latest
    # release with: nix flake update worksummary
    worksummary = {
      url = "github:MartinPaulEve/worksummary";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Third-party terminal multiplexer for AI agents. Deliberately left without
    # a nixpkgs `follows`: it carries its own nixpkgs + rust-overlay so its Rust
    # toolchain stays consistent. Update with: nix flake update herdr
    herdr.url = "github:ogulcancelik/herdr";

    # Always-up-to-date Claude Code (own fork of sadjow/claude-code-nix, which
    # repackages Anthropic's official self-contained native binary and bumps
    # hourly), replacing the lag-prone nixpkgs claude-code. Deliberately left
    # without a nixpkgs `follows`: keeping its own pin matches the derivations
    # its CI builds and caches. Pull the latest version with:
    # nix flake update claude-code
    claude-code.url = "github:MartinPaulEve/claude-code-nix";
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      # Build the machine described by ./hosts/<name>. Every host gets the
      # same shared system modules and the same Home Manager configuration;
      # its directory adds only its own hardware. `specialArgs` threads the
      # whole `inputs` set into every module, so modules can reach flake
      # inputs directly (e.g. inputs.worksummary in modules/nixos/packages.nix).
      #
      # The hostname defaults to the directory name, so naming a machine is
      # naming its directory. (A host file can still set networking.hostName
      # itself to override that.)
      mkHost = name: extraModules: lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          (./hosts + "/${name}")
          ./modules/nixos
          ./home
          { networking.hostName = lib.mkDefault name; }
        ] ++ extraModules;
      };

      # Every directory under ./hosts is a machine: `nixos` (the aarch64
      # Parallels guest), `nixos-amd64` (bare-metal AMD + NVIDIA), and any
      # added later. Nothing needs registering here — see AMD64.md.
      hostNames = builtins.attrNames
        (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./hosts));
    in
    {
      nixosConfigurations = lib.genAttrs hostNames (name: mkHost name [ ]) // {
        # The Parallels guest's system rebuilt for x86_64, so the config can
        # be test-driven in a local QEMU VM on a non-Mac host. Build and run
        # with:
        #   nix build .#nixosConfigurations.nixos-vm-x86.config.system.build.vm
        #   ./result/bin/run-nixos-vm
        # then view it with: remote-viewer spice://127.0.0.1:5930
        # (SPICE/VM settings live in modules/nixos/vm.nix.)
        nixos-vm-x86 = mkHost "nixos" [
          ({ lib, ... }: {
            nixpkgs.hostPlatform = "x86_64-linux";
            # Parallels guest tools are pointless (and unfree) under QEMU.
            hardware.parallels.enable = lib.mkForce false;
          })
        ];
      };
    };
}
