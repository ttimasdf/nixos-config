{ flake, config, lib, pkgs, ... }:
# https://github.com/pbek/nixcfg/blob/bf9196dd7e3d219de5c02f1ffede64f2bf007090/modules/hokage/programs/espanso.nix
# https://github.com/pbek/nixcfg/blob/fd37b9e548c6f6cdc93b3db4bf348b89e449705b/modules/mixins/espanso.nix
let
  homeConfigs = config.home-manager.users;
  systemEnabled = lib.traceIf
    config.services.espanso.enable
    "Espanso Wayland fix is enabled for system service"
    config.services.espanso.enable;
  userEnabled = lib.any
  (u: lib.traceIf
    u.services.espanso.enable
    "Espanso Wayland fix is enabled for user service '${u.home.username}'"
    u.services.espanso.enable or false)
  (lib.attrValues (lib.filterAttrs (name: _: lib.elem name config.rabit.nixos.myusers) homeConfigs));
in
{
  config = lib.mkIf (systemEnabled || userEnabled) {
    # Workaround: [ERROR] Error: could not open uinput device
    boot.kernelModules = [ "uinput" ];

    # Workaround permission denied error on /dev/uinput
    services.udev.extraRules = ''
      KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput", GROUP="input", MODE="0660"
    '';
  };
}
