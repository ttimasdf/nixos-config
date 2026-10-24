# edge-01 services — the services file.
#
# Planned (each lands here when its turn comes; see homelab-overhaul/progress/WORKING.md):
#   - Technitium DNS (podman; authoritative lab.domain.invalid, split-horizon with Spaceship)
#   - Caddy reverse proxy (consumes the *.lab.domain.invalid wildcard via useACMEHost)
#   - security.acme wildcard (dnsProvider spaceship, secrets via sops-nix)
#   - EasyTier peer (10.66.40.0/24 mesh, new network name/password)
#   - dnsmasq DHCP-only for the zones (port=0; Technitium owns :53)
#   - mihomo listener-only (egress chain endpoint for sandbox-01)
{ }

