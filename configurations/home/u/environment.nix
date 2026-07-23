{ flake, osConfig, lib, pkgs, isDarwin, ... }:
{
  home.sessionVariables = {
    DO_NOT_TRACK = "1";
  };

  # Prefer NVIDIA (card1) over Intel (card2) for KWin compositing/scan-out.
  # Workaround for external-monitor bug when compositor and scan-out are split across GPUs.
  # Converts NVIDIA-style PCI bus IDs (e.g. "PCI:01:00:0") to /dev/dri/by-path symlinks.
  #xdg.configFile."systemd/user/plasma-kwin_wayland.service.d/nvidia-fix.conf".text =
  #  let
  #    # PCI:DD:FF:F → /dev/dri/by-path/pci-0000:DD:FF.F-card
  #    driCardPath =
  #      busId:
  #      let
  #        lowered = lib.toLower busId; # "pci:01:00:0"
  #        stripped = builtins.substring 4 (-1) lowered; # "01:00:0"
  #        parts = lib.splitString ":" stripped; # ["01" "00" "0"]
  #        addr = "pci-0000:${lib.head parts}:${lib.elemAt parts 1}.${lib.elemAt parts 2}";
  #      in
  #      "/dev/dri/by-path/${addr}-card";
  #    nvidia = driCardPath osConfig.hardware.nvidia.prime.nvidiaBusId;
  #    intel = driCardPath osConfig.hardware.nvidia.prime.intelBusId;
  #  in ''
  #    [Service]
  #    #Environment="KWIN_DRM_DEVICES=${nvidia}:${intel}";
  #  '';
}

