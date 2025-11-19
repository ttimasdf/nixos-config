/**
  based on:
  https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/tools/security/ghidra/extensions/ghidraninja-ghidra-scripts/default.nix

  remove swift package since it's only used in one single script, but adding unneccesary 1.5GiB size in package closure.
  use `swift` executable from PATH inside nix-shell if needed.
 */

{
  lib,
  fetchFromGitHub,
  buildGhidraScripts,
  binwalk,
  yara,
}:

buildGhidraScripts {
  pname = "ghidraninja-ghidra-scripts";
  version = "unstable-2020-10-07";

  src = fetchFromGitHub {
    owner = "ghidraninja";
    repo = "ghidra_scripts";
    rev = "99f2a8644a29479618f51e2d4e28f10ba5e9ac48";
    sha256 = "aElx0mp66/OHQRfXwTkqdLL0gT2T/yL00bOobYleME8=";
  };

  postPatch = ''
    # Replace subprocesses with store versions
    substituteInPlace binwalk.py --replace-fail 'subprocess.call(["binwalk"' 'subprocess.call(["${binwalk}/bin/binwalk"'
    # substituteInPlace swift_demangler.py --replace-fail '"swift"' '"$ESCAPE{swift}/bin/swift"'
    substituteInPlace yara.py --replace-fail 'subprocess.check_output(["yara"' 'subprocess.check_output(["${yara}/bin/yara"'
    substituteInPlace YaraSearch.py --replace-fail '"yara "' '"${yara}/bin/yara "'
  '';

  meta = with lib; {
    description = "Scripts for the Ghidra software reverse engineering suite";
    homepage = "https://github.com/ghidraninja/ghidra_scripts";
    license = with licenses; [
      gpl3Only
      gpl2Only
    ];
  };
}
