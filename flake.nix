# https://nixos.wiki/wiki/flakes
{
  inputs = {
    # This is pointing to an unstable release.
    # If you prefer a stable release instead, you can this to the latest number shown here: https://nixos.org/download
    # i.e. nixos-24.11
    # Use `nix flake update` to update the flake to the latest revision of the chosen release channel.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    lanzaboote = { url = "github:nix-community/lanzaboote/v0.4.2"; inputs.nixpkgs.follows = "nixpkgs"; };
    winapps = { url = "github:winapps-org/winapps"; inputs.nixpkgs.follows = "nixpkgs"; };
    home-manager = { url = "github:nix-community/home-manager/release-25.05"; inputs.nixpkgs.follows = "nixpkgs"; };

  };
  outputs = inputs@{ self, nixpkgs, nixos-hardware, lanzaboote, winapps, home-manager, ... }: {
    # Used with `nixos-rebuild switch --flake .#<hostname>`
    nixosConfigurations."Nokia-N97" = nixpkgs.lib.nixosSystem {
      modules = [
        lanzaboote.nixosModules.lanzaboote
        nixos-hardware.nixosModules.lenovo-legion-16irx9h
        ./configuration.nix
        # WinApps config
        ({ pkgs, ... }: {
          environment.systemPackages = [
            winapps.packages."${pkgs.system}".winapps
            winapps.packages."${pkgs.system}".winapps-launcher # optional
          ];
        })
        ./revision.nix
      ];
    };
    homeConfigurations."u" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages."${nixpkgs.system}";
      modules = [ ./home.nix ];
    };
  };
}

