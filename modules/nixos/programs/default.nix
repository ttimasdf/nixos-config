# Collect custom program modules defined alongside this file.
let
  entries = builtins.readDir ./.;
  isModule =
    name:
    name != "default.nix"
    && (
      entries.${name} == "directory"
      || (entries.${name} == "regular" && builtins.match ".*\\.nix" name != null)
    );
in
{
  imports = map (name: ./. + "/${name}") (builtins.filter isModule (builtins.attrNames entries));
}
