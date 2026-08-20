{ flake, ... }:
# Decode legacy Chinese archive names with libnatspec.
final: prev:
let
  inherit (flake.inputs.nixpkgs) lib;
in
{
  zip-nls = (prev.zip.override { enableNLS = true; }).overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-nls";

    # The hosts use English locales, but these packages are intended to handle
    # archives whose unmarked filenames use the Chinese DOS code page.
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace unix/unix.c zipnote.c \
        --replace-fail \
          'natspec_get_charset_by_locale(NATSPEC_DOSCS, "")' \
          '"CP936"'
    '';
  });

  unzip-nls = (prev.unzip.override { enableNLS = true; }).overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-nls";

    postPatch = (oldAttrs.postPatch or "") + ''
      oldOem=$'inline void oem_intern(char *string)\n{'
      newOem=$'inline void oem_intern(char *string)\n{\n    if (G.pInfo->GPFIsUTF8)\n        return;'
      oldIso=$'inline void iso_intern(char *string)\n{'
      newIso=$'inline void iso_intern(char *string)\n{\n    if (G.pInfo->GPFIsUTF8)\n        return;'

      substituteInPlace unix/unix.c \
        --replace-fail \
          'natspec_get_charset_by_locale(NATSPEC_DOSCS, "")' \
          '"CP936"' \
        --replace-fail \
          'natspec_get_charset_by_locale(NATSPEC_WINCS, "")' \
          '"CP936"' \
        --replace-fail "$oldOem" "$newOem" \
        --replace-fail "$oldIso" "$newIso"
    '';
  });

  _7zz-nls = prev._7zz-rar.overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-nls";
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ final.libnatspec ];

    # AUR's 7zip-natspec patch, pinned to the package repository commit.
    patches = (oldAttrs.patches or [ ]) ++ [
      (prev.fetchpatch {
        url = "https://aur.archlinux.org/cgit/aur.git/plain/natspec.patch?h=7zip-natspec&id=39b3c4a1975d91c698b076e98bdc6e0a92a83b46";
        hash = "sha256-n3bELiCTRT33loiJsgns3N1x5fLlRkhjzknsN1r2PFE=";
      })
    ];

    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace CPP/7zip/Archive/Zip/ZipItem.cpp \
        --replace-fail \
          'natspec_get_charset_by_locale(NATSPEC_DOSCS, "")' \
          '"CP936"'
    '';

    # KDE Ark searches for "7z" rather than "7zz".
    postInstall = (oldAttrs.postInstall or "") + ''
      ln -s 7zz "$out/bin/7z"
    '';

    meta = lib.recursiveUpdate oldAttrs.meta {
      description = oldAttrs.meta.description + " with CP936 filename decoding";
      longDescription = ''
        ${oldAttrs.meta.longDescription or oldAttrs.meta.description}

        This variant uses libnatspec to decode unmarked ZIP filenames as CP936.
      '';
    };
  });
}
