{ flake, lib, ... }:
# Enable NLS (Native Language Support) by adding libnatspec patch from gentoo
final: prev:
let
  inherit (flake.inputs.self) rabit-lib;
  zip = prev.zip.override { enableNLS = true; };
  unzip = prev.unzip.override { enableNLS = true; };
  nlsWrap = pkg:
    pkg.overrideAttrs (finalAttrs: previousAttrs: {
      pname = previousAttrs.pname + "-nls";
      nativeBuildInputs = (previousAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
      postInstall = ''
        wrapProgram $out/bin/${previousAttrs.pname} --add-flags "-O gbk"
      '';
    });
  zip-nls = nlsWrap zip;
  unzip-nls = nlsWrap unzip;
in
{
  zip-nls = zip-nls;
  unzip-nls = unzip-nls;
  kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
    ark = kprev.ark.overrideAttrs (oldAttrs: {
      buildInputs = oldAttrs.buildInputs ++ [
        zip-nls
        unzip-nls
      ];
    });
  });
}
