/**
  NLS (Native Language Support) for the zip family, backed by libnatspec.

  `_7zz-nls` carries the patch from the AUR `7zip-natspec` package:
  https://raw.githubusercontent.com/archlinux/aur/7zip-natspec/natspec.patch
  It is vendored in ./patches instead of being fetched, because the upstream
  copy is CRLF while 7-Zip >= 26.00 ships LF sources, and GNU patch refuses to
  apply hunks whose line endings differ from the target file
  ("Hunk #1 FAILED at 162 (different line endings)"). The vendored copy is the
  same patch converted to LF.
*/
{ flake, ... }:

final: prev:
let
  inherit (flake.inputs.self) rabit-lib;

  nlsWrap = pkg:
    pkg.overrideAttrs (finalAttrs: previousAttrs: {
      pname = previousAttrs.pname + "-nls";
      nativeBuildInputs = (previousAttrs.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
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
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ prev.libnatspec ];

    # NLS patch, vendored in ./patches (see the header comment above)
    patches = (oldAttrs.patches or [ ]) ++ (rabit-lib.findPatches ./patches);

    # KDE Ark only search for "7z" instead of "7zz"
    postInstall = ''
      ln -s 7zz $out/bin/7z
    '';
  });
}
