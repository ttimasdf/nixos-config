{
  description = "KnownRabbit's NixOS Config";

  # Principle inputs (updated by `nix run .#update`)
  inputs = {
    # Public shim: the committed input is the public module template, so the
    # repository evaluates without access to the private repository.
    # Real deployments override it with the local private checkout, e.g.
    #   --override-input private-module path:./private
    # (the `xc` build/switch tasks in README.md do this automatically).
    private-module = {
      url = "github:ttimasdf/nixos-config-module";
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
    # nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };
    nix-darwin = { url = "github:LnL7/nix-darwin"; inputs.nixpkgs.follows = "nixpkgs"; };
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware = { url = "github:NixOS/nixos-hardware/master"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Software inputs
    known-rabbit-packages = {
      url = "github:ttimasdf/nix-packages/main";
      inputs.nixpkgs.follows = "nixpkgs";
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
    # llm-agents = {
    #   url = "github:numtide/llm-agents.nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.flake-parts.follows = "flake-parts";
    #   inputs.systems.follows = "systems";
    # };
  };

  # Wired using https://nixos-unified.org/autowiring.html
  outputs = inputs:
    inputs.nixos-unified.lib.mkFlake {
      inherit inputs;
      root = ./.;
    };
}
