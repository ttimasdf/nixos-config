{
  description = "KnownRabbit's NixOS Config";

  # Principle inputs (updated by `nix run .#update`)
  inputs = {
    # Helpers
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-unified.url = "github:srid/nixos-unified";
    flake-compat.url = "github:NixOS/flake-compat";
    git-hooks-nix = { url = "github:cachix/git-hooks.nix"; inputs.nixpkgs.follows = "nixpkgs"; inputs.flake-compat.follows = "flake-compat"; };

    # NixOS system flakes
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nix-darwin = { url = "github:LnL7/nix-darwin"; inputs.nixpkgs.follows = "nixpkgs"; };
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Software inputs
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit.follows = "git-hooks-nix";
    };
    winapps = { url = "github:winapps-org/winapps"; inputs.nixpkgs.follows = "nixpkgs"; inputs.flake-compat.follows = "flake-compat"; };
    nix-index-database = { url = "github:nix-community/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
    # nixvim = { url = "github:nix-community/nixvim"; inputs.nixpkgs.follows = "nixpkgs"; inputs.flake-parts.follows = "flake-parts"; };
    # vertex = { url = "github:juspay/vertex"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur = { url = "github:nix-community/NUR"; inputs.nixpkgs.follows = "nixpkgs"; inputs.flake-parts.follows = "flake-parts"; };
    nixos-generators = { url = "github:nix-community/nixos-generators"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  # Wired using https://nixos-unified.org/autowiring.html
  outputs = inputs:
    inputs.nixos-unified.lib.mkFlake {
      inherit inputs;
      root = ./.;
    };
}
