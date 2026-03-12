{
  description = "KnownRabbit's NixOS Config";

  # Principle inputs (updated by `nix run .#update`)
  inputs = {
    # 1.  Create a new GitHub Fine-grained personal access token at https://github.com/settings/personal-access-tokens
    #     with the following permissions:
    #     - repository: `ttimasdf/nixos-config-private`
    #     - permissions: content (read-only), metadata (read-only)
    #     The token should start with github_pat_xxxxx
    #
    # 2.  Set up the GitHub access token in ~/.config/nix/nix.conf
    #     access-tokens = github.com=github_pat_xxxxxxxx
    #     Reference: https://nix.dev/manual/nix/2.28/command-ref/conf-file#conf-access-tokens
    #
    # 3.  Run `nix flake update private-module` to verify that the access token has been successfully applied.
    #     If no error message appears, the setup is complete.
    private-module = {
      url = "github:ttimasdf/nixos-config-private";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixos-unified.follows = "nixos-unified";
      inputs.flake-parts.follows = "flake-parts";
    };

    # Helpers used as inputs for other flakes
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-unified.url = "github:srid/nixos-unified";
    flake-compat.url = "github:NixOS/flake-compat";
    systems.url = "github:nix-systems/default";
    flake-utils = { url = "github:numtide/flake-utils"; inputs.systems.follows = "systems"; };
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
    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-utils.follows = "flake-utils";
    };
    nix-index-database = { url = "github:nix-community/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
    # nixvim = { url = "github:nix-community/nixvim"; inputs.nixpkgs.follows = "nixpkgs"; inputs.flake-parts.follows = "flake-parts"; };
    # vertex = { url = "github:juspay/vertex"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur = { url = "github:nix-community/NUR"; inputs.nixpkgs.follows = "nixpkgs"; inputs.flake-parts.follows = "flake-parts"; };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.systems.follows = "systems";
    };
  };

  # Wired using https://nixos-unified.org/autowiring.html
  outputs = inputs:
    inputs.nixos-unified.lib.mkFlake {
      inherit inputs;
      root = ./.;
    };
}
