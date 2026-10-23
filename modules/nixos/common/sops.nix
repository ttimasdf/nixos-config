# SOPS-based secret management.
#
# Secrets are stored encrypted (see `private/secrets/` + `private/.sops.yaml`)
# and decrypted at boot into /run/secrets (tmpfs) by each host's SSH host key
# (ed25519, converted to an age key). Hosts without `sops.secrets` are
# unaffected by this module.
#
# Workflow (from the devshell, which sets SOPS_AGE_KEY_FILE):
#   sops private/secrets/<host>.yaml        # edit a host's secrets
#   sops updatekeys private/secrets/<f>     # after adding a host key to .sops.yaml
#
# Enrolling a new host (run on the host itself, then fill .sops.yaml):
#   nix shell nixpkgs#ssh-to-age -c ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
{ flake, ... }:
{
  imports = [ flake.inputs.sops-nix.nixosModules.sops ];
}
