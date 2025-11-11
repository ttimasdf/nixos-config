{ flake, lib, ... }:
# Enable NLS (Native Language Support) by adding libnatspec patch from gentoo
final: prev:
{
  zip-nls = prev.zip.override { enableNLS = true; };
  unzip-nls = prev.unzip.override { enableNLS = true; };
}
