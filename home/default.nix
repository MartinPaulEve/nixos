# Wire Home Manager into NixOS and attach per-user configurations.
{ inputs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    # Use the system's nixpkgs and install packages into the user profile.
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    users.martin = import ./martin;
  };
}
