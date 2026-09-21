{ pkgs, lib, liveUser, baked, manual }:
let
  inherit (baked) offlineFlakeStoreContents nixosRabitInstall;
  inherit (manual) mkInstallManualMd mkInstallManualHtml;

  # What a packed variant preloads on top of the baked flake: the host's runtime
  # closure (the packages its regenerated system derivations reference),
  # stdenv (the compiler) and the store paths needed to *rebuild* those
  # derivations -- stdenv's builder scripts, lndir and friends are in no
  # runtime closure. delta-probe.nix computes the last part by pure evaluation
  # over the derivations' ATerms; carrying an already-carried path is free, so
  # its list lands in storeContents unfiltered.
  mkHostStoreContents = { hostToplevel, deltaRoots }:
    [ hostToplevel pkgs.stdenv ]
    ++ lib.optionals (deltaRoots != [ ]) (import ./delta-probe.nix {
      inherit lib deltaRoots;
    });

  # Everything an installer-capable ISO carries: the install manual (rendered
  # and raw), the preconfigured installer, the store contents to preload, and
  # the copy of the manual dropped on the live desktop.
  mkCfgISOContent =
    { packedHost ? null, hostToplevel ? null, deltaRoots ? [ ] }:
    let
      installManualMd = mkInstallManualMd packedHost;
      installManualHtml = mkInstallManualHtml installManualMd;
    in
    {
      # The baked flake + inputs, the preloaded host's runtime closure, and the
      # build closure of the delta: the derivations that depend on
      # hardware-configuration.nix are regenerated on the target, so the ISO has
      # to be able to build them. (The host's *full* build closure is far too
      # large: ~40 GiB of outputs, and ~200 GiB unpacked.) Merges with the
      # default, which is this system's own toplevel.
      isoImage.storeContents = offlineFlakeStoreContents
        ++ lib.optionals (hostToplevel != null) (mkHostStoreContents { inherit hostToplevel deltaRoots; });

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
