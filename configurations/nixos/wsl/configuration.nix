{ lib, ... }:

{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking.hostName = "wsl";

  wsl = {
    enable = true;
    defaultUser = "nixos";
    interop.includePath = false;
  };

  # enable for vscode server
  programs.nix-ld.enable = true;

  rabit.nixos.myusers = [ "nixos" ];
  rabit.nixos.http_proxy = "http://127.0.0.1:28888";

  system.stateVersion = "26.05";
}
