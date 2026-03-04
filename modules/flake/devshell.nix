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
        gh
        nixfmt
      ];

      # Set NH_FLAKE environment variable to the current flake's path
      shellHook = ''
        export NH_FLAKE=$(pwd)
        # Force override SSH_AUTH_SOCK for nixos-rebuild (nix-copy-closure)
        export NIX_SSHOPTS="-o IdentityAgent=$SSH_AUTH_SOCK"

        # FIXME: need to run `nix develop` manually for this function to work.
        # due to direnv bug:
        # https://github.com/direnv/direnv/issues/73
        if [ "$DIRENV_IN_ENVRC" != "1" ]; then
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
        else
          echo "[!] nixos-eval-config not available in direnv, run "nix develop" manually" >&2
        fi
      '';
    };
  };
}
