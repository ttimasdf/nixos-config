{
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      name = "knownrabbit-nixos-config";
      meta.description = "Shell environment for modifying this Nix configuration";
      packages = with pkgs; [
        nh
        just
        xc
        git-filter-repo
        git-crypt
      ];

      # Set NH_FLAKE environment variable to the current flake's path
      shellHook = ''
        export NH_FLAKE=$(pwd)
      '';
    };
  };
}
