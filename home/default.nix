# Wire Home Manager into NixOS and attach per-user configurations.
{ inputs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    # Use the system's nixpkgs and install packages into the user profile.
    useGlobalPkgs = true;
    useUserPackages = true;

    # If a file Home Manager wants to manage already exists (e.g. an old
    # stow symlink), move it aside to <name>.backup rather than failing.
    backupFileExtension = "backup";

    extraSpecialArgs = { inherit inputs; };

    users.martin = import ./martin;
  };
}
