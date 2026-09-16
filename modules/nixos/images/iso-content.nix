{ pkgs, lib, liveUser, baked, manual }:
let
  inherit (baked) offlineFlakeStoreContents nixosRabitInstall;
  inherit (manual) mkInstallManualMd mkInstallManualHtml;

  # Everything an installer-capable ISO carries: the install manual (rendered
  # and raw), the preconfigured installer, the store contents to preload, and
  # the copy of the manual dropped on the live desktop.
  mkCfgISOContent =
    { packedHost ? null, hostToplevel ? null }:
    let
      installManualMd = mkInstallManualMd packedHost;
      installManualHtml = mkInstallManualHtml installManualMd;
    in
    {
      # The baked flake + inputs, the preloaded host's runtime closure, and
      # stdenv, so the few NixOS system derivations that still differ on install
      # can be rebuilt from the ISO store alone. (The host's full build closure
      # is far too large: it is ~200 GiB unpacked.) Merges with the default,
      # which is this system's own toplevel.
      isoImage.storeContents = offlineFlakeStoreContents
        ++ lib.optionals (hostToplevel != null) [ hostToplevel pkgs.stdenv ];

      environment.systemPackages = [ nixosRabitInstall ];
      environment.etc."nixos-install-manual.md".source = installManualMd;
      environment.etc."nixos-install-manual.html".source = installManualHtml;

      # Drop the rendered manual onto the live user's desktop.
      system.activationScripts.nixos-install-manual = {
        deps = [ "users" ];
        text = ''
          liveUser=${lib.escapeShellArg liveUser}
          if ${pkgs.coreutils}/bin/id "$liveUser" >/dev/null 2>&1; then
            liveGroup="$(${pkgs.coreutils}/bin/id -gn "$liveUser")"
            liveDesktop="/home/$liveUser/Desktop"
            ${pkgs.coreutils}/bin/install -D -m 0644 -o "$liveUser" -g "$liveGroup" \
              ${installManualHtml} "$liveDesktop/INSTALL.html"
            ${pkgs.coreutils}/bin/install -D -m 0644 -o "$liveUser" -g "$liveGroup" \
              ${installManualMd} "$liveDesktop/INSTALL.md"
          fi
        '';
      };
    };
in
{
  inherit mkCfgISOContent;
}
