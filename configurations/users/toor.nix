{ flake, pkgs, lib, config, ... }:

{
  # set users.users.<name> options here
  # https://search.nixos.org/options?channel=unstable&query=users.users

  extraGroups = [
    "wheel"       # Enable ‘sudo’ for the user.
    "wireshark"   # for programs.wireshark
    "input"       # for services.espanso
    "kvm"         # to make /dev/kvm work with podman. 
    "libvirtd"    # for virtualisation.libvirtd
    "dialout"     # for serial ports
    "tss"         # tss group has access to TPM devices
    "uhid"        # uhid is essencial for tpm-fido & linux-id
  ];
} // lib.optionalAttrs config.programs.zsh.enable {
  shell = pkgs.zsh;
}
