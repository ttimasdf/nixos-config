{
  inputs = {
    # This is pointing to an unstable release.
    # If you prefer a stable release instead, you can this to the latest number shown here: https://nixos.org/download
    # i.e. nixos-24.11
    # Use `nix flake update` to update the flake to the latest revision of the chosen release channel.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, lanzaboote, ... }: {
    # NOTE: 'nixos' is the default hostname
    nixosConfigurations."Nokia-N97" = nixpkgs.lib.nixosSystem {
      modules = [
        lanzaboote.nixosModules.lanzaboote
        ./configuration.nix
      ];
    };
  };
}

