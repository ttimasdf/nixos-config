# A module that automatically imports everything else in the parent folder.
{
  imports =
    with builtins;
    map
      (fn: ./${fn})
      (filter (fn: fn != "all.nix") (attrNames (readDir ./.)));
}
