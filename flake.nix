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
  };

  outputs = inputs@{ self, nixpkgs, ... }: {
    # The `nixos` host. `specialArgs` threads the whole `inputs` set into every
    # module, so modules can reach flake inputs directly (e.g. inputs.worksummary
    # in modules/nixos/packages.nix). Host + hardware entry point: ./hosts/nixos.
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/nixos
      ];
    };
  };
}
