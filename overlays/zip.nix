{ flake, lib, ... }:
# Enable NLS (Native Language Support) by adding libnatspec patch from gentoo
final: prev:
let
  nlsWrap = pkg:
    pkg.overrideAttrs (finalAttrs: previousAttrs: {
      pname = previousAttrs.pname + "-nls";
      nativeBuildInputs = (previousAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
      postInstall = ''
        for bin in $out/bin/*; do
          wrapProgram "$bin" --add-flags "-O gbk"
        done
      '';
    });
  zip-nls = nlsWrap (prev.zip.override { enableNLS = true; });
  unzip-nls = nlsWrap (prev.unzip.override { enableNLS = true; });
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
