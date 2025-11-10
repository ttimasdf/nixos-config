{ config, pkgs, lib, ... }:
{
  # Garbage collect the Nix store
  nix.gc = {
    automatic = true;
    # Change how often the garbage collector runs (default: weekly)
    # frequency = "monthly";
  };

  # To use the `nix` from `inputs.nixpkgs` on templates using the standalone `home-manager` template
  # `nix.package` is already set if on `NixOS` or `nix-darwin`.
  nix.package = lib.mkDefault pkgs.nix;
  home.packages = [
    config.nix.package
  ];
}
