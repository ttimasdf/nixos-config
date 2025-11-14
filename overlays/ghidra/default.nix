{ flake, lib, ... }:

final: prev:
let
  ghidra-ida = prev.fetchFromGitHub {
    owner = "NyaMisty";
    repo = "GhidraIDA";
    rev = "c30ea714e3baaf0b4b1124795e08d283a48d6a92";
    sha256 = "sha256-pJtY3QeS9rK/L9zVlHr23wfq93aeJXLMvQTkkov94t0=";
  };
  ghidra-ida-til = prev.fetchFromGitHub {
    owner = "NyaMisty";
    repo = "ghidra_ida_til";
    rev = "85ac9c9bf1f03e5c82d7f38627eb332a43ee0d68";
    sha256 = "sha256-FmwEJquJZhb/EJvzxgwVpQd/Nfy/pmI+4wlP0zn6dL4=";
  };
  patchesDir = ./patches;
  ghidra-patches = lib.pipe patchesDir [
    builtins.readDir
    (lib.attrNames)
    (lib.filter (name: lib.hasSuffix ".patch" name))
    (lib.map (name: "${patchesDir}/${name}"))
  ];
in
{
  ghidra = prev.ghidra.overrideAttrs (oldAttrs: {
    pname = oldAttrs.pname + "-mod";
    patches = (oldAttrs.patches or []) ++ ghidra-patches;
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ ghidra-ida ghidra-ida-til ];
    preBuildPhases = (oldAttrs.preBuildPhases or []) ++ [ "addGhidraIDAPhase" ];
    preFixupPhases = (oldAttrs.preFixupPhases or []) ++ [ "addIdaTilPhase" "fixHiDPIPhase" ];

    addGhidraIDAPhase = ''
      defaultToolsDir="./Ghidra/Configurations/Public_Release/src/main/resources/defaultTools"
      mv $defaultToolsDir/CodeBrowser.tool $defaultToolsDir/CodeBrowserClassic.tool
      sed -i -e 's@TOOL_NAME="CodeBrowser"@TOOL_NAME="CodeBrowserClassic"@' $defaultToolsDir/CodeBrowserClassic.tool
      cp ${ghidra-ida}/mistyGhIDA.tool $defaultToolsDir/CodeBrowser.tool
      # Add new file to certification.manifest
      echo 'src/main/resources/defaultTools/CodeBrowserClassic.tool||GHIDRA||||END|' >> ./Ghidra/Configurations/Public_Release/certification.manifest
    '';
    addIdaTilPhase = ''
      cp -R ${ghidra-ida-til}/release $out/lib/ghidra/Ghidra/Features/Base/data/typeinfo/ida
    '';
    # HiDPI Fix:
    # https://gist.github.com/nstarke/baa031e0cab64a608c9bd77d73c50fc6
    fixHiDPIPhase = ''
      sed -i 's|VMARGS_LINUX=-Dsun.java2d.uiScale=1|VMARGS_LINUX=-Dsun.java2d.uiScale=2|g' \
        $out/lib/ghidra/support/launch.properties
    '';
  });
}
