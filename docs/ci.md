# Continuous integration

`.github/workflows/ci.yml` builds every host, local package, and public package
this flake provides, plus the packages of the `public-packages` submodule. It
also explains how the licensed sources of packages such as `ida-pro` reach the
runner.

## What runs

| Job | Runs on | Builds |
| --- | --- | --- |
| `discover` | every event | evaluates every host target, all package sets, checks that `public-packages` and `flake.lock` agree; produces the build matrices |
| `hosts` | every event | one job per host, built with `--override-input known-rabbit-packages path:./public-packages` |
| `packages` | every event | `.#packages.x86_64-linux.*` (`activate`, `nixos-rabit-install`, `update`) |
| `public-packages` | every event | `path:./public-packages#packages.x86_64-linux.*`, minus the attributes listed below |
| `ci` | every event | aggregated status check for branch protection |

Host targets are not all `system.build.toplevel`:

| Host | Target | Why |
| --- | --- | --- |
| `MNIX`, `basenji`, `viscacha`, `wsl` | `config.system.build.toplevel` | ordinary systems |
| `brisling` | `config.system.build.images.proxmox-lxc` | the host only exists as a container image |
| `savior` | `config.system.build.images.iso-xfce` | the host only exists as an ISO |

Add new hosts to `target_for` in `discover` if they need anything other than
`toplevel`; hosts missing from the matrix still get evaluated, so a wrong
target is reported instead of silently skipped.

## Which module CI uses

- **Pull requests** evaluate the committed `private-module` input, i.e. the
  public shim in `ttimasdf/nixos-config-module`. No secrets are involved, so
  fork pull requests work.
- **Pushes and the weekly run** check out `ttimasdf/nixos-config-private` with a
  deploy key and pass `--override-input private-module path:./private`, so the
  real hosts, private overlays, and cacert modules are built.

## Licensed and unfetchable package sources

`ida-pro`, `binaryninja`, `jumpserver-client-3`, and `wuying-cloud-desktop` have
`requireFile` sources: proprietary installers that Nix cannot download. In
current Nixpkgs `requireFile` is a *fixed-output derivation* whose builder only
prints an error. That has two consequences:

- evaluation always succeeds, so `discover` covers these packages too;
- the output is a content-addressed store path
  (`/nix/store/…-ida-pro_92_x64linux.run`) that any binary cache can serve.

CI gets the content in one of two ways, both described in
[Publishing the licensed sources](#publishing-the-licensed-sources):

- **substitute it** from the private Attic cache, filled by pushing a closure
  that already contains the artifact (nothing but the cache ever holds it);
- **fetch it** from a private release or HTTPS directory and register it with
  `nix-store --add-fixed`, so the fixed-output derivation is already valid.

```bash
# Filling the cache from a machine that has the artifacts, e.g. this workstation:
xc build && xc push-cache          # the whole closure, ida-pro included

# Or a single package:
nix build path:./public-packages#packages.x86_64-linux.ida-pro
xc push-cache "$(readlink -f result)"
```

If the derivation changes (a Nixpkgs bump usually changes it), the cache misses
and the `public-packages` job for that package fails until the artifact is
pushed again. That failure means "the license holder must rebuild", not "the
repository is broken".

Two lists in `ci.yml` decide what the `public-packages` matrix leaves out:

- `PRIVATE_SOURCE_PACKAGES` (`ida-pro`, `jumpserver-client-3`,
  `wuying-cloud-desktop`) is skipped while CI has neither cache credentials nor
  an asset source, so the matrix stays green before the first push and in fork
  pull requests.
- `STANDALONE_UNBUILDABLE_PACKAGES` (`binaryninja`) is always skipped: it
  requires a `binaryNinjaArchive` argument that only the host override in
  `configurations/home/u/packages/pentest.nix` supplies. The `hosts` matrix
  still builds it through `viscacha`.

## Required GitHub configuration

Repository **variables** (`Settings → Secrets and variables → Actions → Variables`):

| Variable | Example | Purpose |
| --- | --- | --- |
| `ATTIC_CACHE` | `nixos-config` | cache name used for `attic push` |
| `ATTIC_ENDPOINT` | `https://attic.example.com/` | Attic API endpoint |
| `ATTIC_CACHE_URL` | `https://attic.example.com/nixos-config` | substituter URL |
| `ATTIC_PUBLIC_KEY` | `nixos-config:1:AbCd…` | cache signing key (public half) |
| `ASSETS_REPO` | `ttimasdf/nixos-config-assets` | private repository whose latest release holds the licensed files |
| `ASSETS_URL` | `https://assets.example.com/licensed` | alternative to `ASSETS_REPO`: a directory served over HTTPS |

Repository **secrets**:

| Secret | Purpose |
| --- | --- |
| `ATTIC_TOKEN` | Attic JWT with read and write access to the cache; also used to authenticate substitutions via `netrc` |
| `ASSETS_TOKEN` | fine-grained PAT with `Contents: read` on `ASSETS_REPO`, or a bearer token for `ASSETS_URL` |
| `PRIVATE_MODULE_DEPLOY_KEY` | SSH deploy key with read access to `ttimasdf/nixos-config-private` |

Everything is optional: without the Attic variables the build jobs never see a
private cache (substitution and push are both skipped, and the licensed-source
packages are excluded), and without the deploy key CI validates the public shim
only.

## What the GitHub Actions cache is good for

The setup action caches `~/.cache/nix` (the evaluation cache and the fetcher
cache) with `actions/cache`, keyed by both lockfiles. That is free, needs no
secrets, and shortens `discover`, which re-evaluates the whole configuration on
every run.

It is **not** a substitute for a binary cache:

- GitHub keeps **10 GB per repository**, evicts least recently used entries, and
  drops anything unused for 7 days. A `savior` ISO is several GB and a `viscacha`
  closure is comparable, so one or two hosts exhaust the budget.
- Entries are **immutable**: a key is written once. Growing a Nix store under a
  fixed key needs a helper such as `nix-community/cache-nix-action@v7`, which
  tars up `/nix` and garbage-collects it to fit.
- Caches are **restorable from the base branch by pull requests, forks
  included** — a feature the Nix-on-Actions caches advertise. Anything stored
  there is not private, which is exactly why the licensed installers must never
  enter it.
- They work only inside GitHub Actions, not from your own machines.

If you still want store caching from the GitHub cache, add
`nix-community/cache-nix-action@v7` (store tarballs) or
`DeterminateSystems/magic-nix-cache-action@v15` (a local substituter backed by
the same cache, zero config) to the `hosts` and `packages` jobs. Both inherit
the limits above. Attic is better on every axis that matters here: size,
privacy, and reuse outside CI.

## Publishing the licensed sources

Two supported places, both fetched by the runner before the build.

### A private release in another repository (simplest)

Upload once from the workstation (`gh` is already authenticated):

```bash
gh repo create ttimasdf/nixos-config-assets --private
gh release create licensed-v1 --repo ttimasdf/nixos-config-assets \
  --title "Licensed installers" --notes "IDA Pro, Binary Ninja, JumpServer, Wuying"
gh release upload licensed-v1 \
  ida-pro_92_x64linux.run \
  JumpServer-Client-Installer-linux-v3.0.4-amd64.deb \
  binaryninja_linux_commercial.6.1.10544-dev.7z \
  wuying-cloud-desktop-7.11.0-wuying.deb \
  --repo ttimasdf/nixos-config-assets
```

Then set the `ASSETS_REPO` variable to `ttimasdf/nixos-config-assets` and the
`ASSETS_TOKEN` secret to a fine-grained PAT with `Contents: read` on that
repository. The workflow's own `GITHUB_TOKEN` cannot read another repository.

GitHub caps a release asset at 2 GB, which fits every current installer; update
`LICENSED_ASSET_FILES` in `ci.yml` when a package bumps its version.

### Any HTTPS directory (no size limit)

Serve the files from the VPS, an S3 bucket, or Cloudflare R2 (`rclone copy
./licensed r2:nixos-assets/licensed`). Set `ASSETS_URL` to the base URL and, if
the directory is not public, `ASSETS_TOKEN` to a bearer token. R2 and B2 are the
cheap choice for images and installers, and R2 also works as Attic's storage
backend.

### Encryption

Encrypting before upload (`age -r <key> -o ida.run.age ida.run`, decrypting in
CI with `AGE_SECRET_KEY`) only protects against the storage leaking; it does not
change redistribution, because the key lives in the same GitHub account. Use it
when the bucket is shared or questionably protected, not as a license
workaround.

### How the runner consumes them

`nix-store --add-fixed sha256 <file>` registers the download under the content
address the package's `requireFile` expects. Nix then treats the fixed-output
derivation as already built and never runs its failing builder; a wrong or
outdated file is caught by the derivation's own check:

```
hash mismatch in fixed-output derivation '…-ida-pro_92_x64linux.run.drv'
  specified: sha256-…
  got:       sha256-…
```

The file must keep its exact name, because the fixed-output path is derived from
the name as well as the hash — `LICENSED_ASSET_FILES` in `ci.yml` lists the four
current names. `install-nix-action` adds the runner user to `trusted-users`, so
no `sudo` is needed.

## Self-hosting Attic

The cache is not deployed yet. On the VPS (`vps1.fr.local`):

```bash
nix shell nixpkgs#attic-server nixpkgs#attic-client -c bash

# 1. Server config, roughly:
#    storage: local + signed URLs, or S3/MinIO
#    api_endpoint and a JWT signing token
atticd --config /etc/atticd.toml

# 2. Create the cache and a token
attic login local https://attic.example.com/ "$ADMIN_TOKEN"
attic cache create nixos-config
attic cache configure nixos-config --public-keys "$(attic cache generate-key nixos-config)"
attic token create nixos-config --scope 'write:nixos-config'   # → ATTIC_TOKEN

# 3. Fill it from a machine that has the artifacts
attic login ci https://attic.example.com/ "$ATTIC_TOKEN"
attic push nixos-config "$(readlink -f result)"
```

Keep the cache private: it contains the licensed installers and the generated
IDA license blobs, and publishing the signing key would let anyone read them.

## Known gaps

- Standalone `legacyPackages.x86_64-linux.homeConfigurations.*` are not built:
  they do not receive the package overlays and fail to evaluate independently of
  the hosts. Home Manager configurations are covered through the host builds.
- Image targets (`savior`, `brisling`) are the largest artifacts and dominate
  runner minutes; they are the first thing to drop if the matrix gets too slow.
- Every job pushes its closure, including the `savior` ISO and the `brisling`
  container image. Give Attic a garbage-collection policy, otherwise image
  artifacts from past Nixpkgs revisions accumulate.
- `nix flake check` is not used as the evaluation gate because it evaluates
  every host, including image hosts that legitimately have no `toplevel`;
  `discover` instead evaluates the exact targets it is going to build.
