{
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      name = "knownrabbit-nixos-config";
      meta.description = "Shell environment for modifying this Nix configuration";
      packages = with pkgs; [
        nh
        xc
        git-filter-repo
        git-crypt
        nixfmt
      ];

      # Set NH_FLAKE environment variable to the current flake's path
      shellHook = ''
        export NH_FLAKE=$(pwd)

        # FIXME: need to run `nix develop` manually for this function to work.
        # due to direnv bug:
        # https://github.com/direnv/direnv/issues/73

        # Function to get nixosConfigurations value from a specific host.
        function nixos-eval-config() {
          [ "$#" -lt 2 ] && echo "usage: nixos-eval-config <host> <option> [nix-eval-options]..." && return 1
          host="$1"
          shift
          option="$1"
          shift
          nix eval "''${NH_FLAKE}#nixosConfigurations.$host.config.$option" $@
        }
        export -f nixos-eval-config
      '';
    };
  };
}
