{ config, lib, pkgs, ... }:
# https://github.com/pbek/nixcfg/blob/bf9196dd7e3d219de5c02f1ffede64f2bf007090/modules/hokage/programs/espanso.nix
# https://github.com/pbek/nixcfg/blob/fd37b9e548c6f6cdc93b3db4bf348b89e449705b/modules/mixins/espanso.nix
let
  cfg = config.rabit.modules.gui.espanso-wayland-fix;
in {
  options.rabit.modules.gui.espanso-wayland-fix.enable = lib.mkEnableOption "Espanso Wayland fixes";
  config = lib.mkIf cfg.enable {
    # Get around: [ERROR] Error: could not open uinput device
    boot.kernelModules = [ "uinput" ];

    # Get around permission denied error on /dev/uinput
    services.udev.extraRules = ''
      KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput", GROUP="input", MODE="0660"
    '';
  };
}
