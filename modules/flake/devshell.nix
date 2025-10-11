{
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      name = "knownrabbit-nixos-config";
      meta.description = "Shell environment for modifying this Nix configuration";
      packages = with pkgs; [
        just
        nixd
      ];
    };
  };
}
