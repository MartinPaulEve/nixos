{
  description = "system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";  # match your channel
    herdr.url = "github:ogulcancelik/herdr";
  };

  outputs = inputs@{ self, nixpkgs, herdr, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "arm64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ({ pkgs, ... }: {
          environment.systemPackages = [
            herdr.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
