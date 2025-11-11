{ flake, lib, ... }:
# Enable NLS (Native Language Support) by adding libnatspec patch from gentoo
final: prev:
{
  zip = prev.zip.override { enableNLS = true; };
  unzip = prev.unzip.override { enableNLS = true; };
}
