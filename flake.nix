{
  description = "system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"; # match your channel
    herdr.url = "github:ogulcancelik/herdr";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Self-authored work-logging CLI. `follows` keeps it on our nixpkgs so no
    # second copy is fetched. Pull the latest with: nix flake update worksummary
    worksummary = {
      url = "github:MartinPaulEve/worksummary";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/nixos
      ];
    };
  };
}
