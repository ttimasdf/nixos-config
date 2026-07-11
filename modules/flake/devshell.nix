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
        nix-update
        (writeShellScriptBin "nixos-eval-config" ''
          if [ "$#" -lt 2 ]; then
            echo "usage: nixos-eval-config <host> <option> [nix-eval-options]..." >&2
            exit 1
          fi

          host="$1"
          shift
          option="$1"
          shift
          nix eval "$NH_FLAKE#nixosConfigurations.$host.config.$option" "$@"
        '')
      ];

      # Set NH_FLAKE environment variable to the current flake's path
      shellHook = ''
        export NH_FLAKE=$(pwd)
        # Force override SSH_AUTH_SOCK for nixos-rebuild (nix-copy-closure)
        export NIX_SSHOPTS="-o IdentityAgent=$SSH_AUTH_SOCK"

        # Allow unfree packages for this devshell.
        export NIXPKGS_ALLOW_UNFREE=1

        # Allow insecure packages for this devshell (e.g., qt5.webengine).
        # Use with `nix build --impure`
        export NIXPKGS_ALLOW_INSECURE=1
      '';
    };
  };
}
