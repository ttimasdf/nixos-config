{ flake, ... }:
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
in
{
  zip-nls = nlsWrap (prev.zip.override { enableNLS = true; });
  unzip-nls = nlsWrap (prev.unzip.override { enableNLS = true; });
  _7zz-nls = prev._7zz-rar.overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-nls";

    # Add libnatspec as a build input
    buildInputs = (oldAttrs.buildInputs or []) ++ [
      prev.libnatspec
    ];

    # Fetch the natspec patch from GitHub
    patches = (oldAttrs.patches or []) ++ [
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/archlinux/aur/7zip-natspec/natspec.patch";
        hash = "sha256-n3bELiCTRT33loiJsgns3N1x5fLlRkhjzknsN1r2PFE=";
      })
    ];

    # KDE Ark only search for "7z" instead of "7zz"
    postInstall = ''
      ln -s 7zz $out/bin/7z
    '';
  });
}
