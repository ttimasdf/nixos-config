{ flake, lib, ... }:

final: prev:
let
  patchesDir = ./patches;
  ghidra-patches = lib.pipe patchesDir [
    builtins.readDir
    (lib.attrNames)
    (lib.filter (name: lib.hasSuffix ".patch" name))
    (lib.map (name: "${patchesDir}/${name}"))
  ];
  pkg_path = "$out/lib/ghidra";
in
{
  ghidra = prev.ghidra.overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-mod";
    patches = (oldAttrs.patches or []) ++ ghidra-patches;
    # oldAttrs.postFixup:
    # https://github.com/NixOS/nixpkgs/blob/c5ae371f1a6a7fd27823bc500d9390b38c05fa55/pkgs/tools/security/ghidra/build.nix#L179-L187
    # HiDPI Fix:
    # https://gist.github.com/nstarke/baa031e0cab64a608c9bd77d73c50fc6
    postFixup = oldAttrs.postFixup + ''
      sed -i 's|VMARGS_LINUX=-Dsun.java2d.uiScale=1|VMARGS_LINUX=-Dsun.java2d.uiScale=2|g' \
        $out/lib/ghidra/support/launch.properties
    '';
  });
}
