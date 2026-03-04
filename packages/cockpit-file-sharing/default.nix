{
  # Standard Nixpkgs inputs
  fetchFromGitHub,
  lib,
  stdenv,

  # Build dependencies
  makeWrapper,
  nodejs,
  python3Packages,
  yarn-berry_4,

  # Runtime dependencies (in cockpitPath)
  attr,
  coreutils,
  findutils,
  getent,
  hostname,
  iproute2,
  nfs-utils,
  samba,
  systemd,
}:

let
  yarn-berry = yarn-berry_4;

  findPatches = patchesDir:
    lib.pipe patchesDir [
      builtins.readDir
      (lib.attrNames)
      (lib.filter (name: lib.hasSuffix ".patch" name))
      (lib.map (name: "${patchesDir}/${name}"))
    ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "cockpit-file-sharing";
  version = "4.5.3-4";

  src = fetchFromGitHub {
    owner = "45Drives";
    repo = "cockpit-file-sharing";
    tag = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-C4+sKASapTSab87IMZ5Pse4z63PYdPCxPvbmwB+6CDs=";
  };

  missingHashes = ./missing-hashes.json;

  offlineCache = yarn-berry.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes;
    hash = "sha256-EoPakV7FVMOxA6yNhteS3s1+aeAF72etpZ4qM7/Dpgo=";
  };

  patches =
    (findPatches ./patches)
    # with cockpit-zfs de-branding patch
    ++ [ ../../overlays/cockpit-zfs/patches/houston-common-0001-feat-remove-45Drives-logo-from-header.patch ];

  nativeBuildInputs = [
    yarn-berry
    yarn-berry.yarnBerryConfigHook
  ];

  passthru.cockpitPath = [
    python3Packages.botocore

    # Dependencies from cockpit-file-sharing/system_dependencies.txt
    systemd      # systemctl
    nfs-utils    # exportfs
    samba        # net (from samba-common-bin)

    # Dependencies from houston-common/system_dependencies.txt
    coreutils    # test, mkdir, touch, df, realpath, stat, chmod, chown, mv, rm, cat, dd, mktemp, rmdir, env, true, groups
    attr         # getfattr, setfattr
    findutils    # find
    hostname     # hostname
    iproute2     # ip
    getent       # getent
  ];

  env = {
    # Disable post-install scripts that try to access network (electron, plantuml-pipe)
    YARN_ENABLE_SCRIPTS = "0";
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  };

  buildPhase = ''
    runHook preBuild

    yarn workspaces foreach -Rpt --from 'file-sharing' run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/cockpit/file-sharing
    cp -r file-sharing/dist/* $out/share/cockpit/file-sharing/

    runHook postInstall
  '';

  meta = {
    description = "Cockpit plugin for file sharing with Samba and NFS by 45Drives";
    homepage = "https://github.com/45Drives/cockpit-file-sharing";
    changelog = "https://github.com/45Drives/cockpit-file-sharing/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.eymeric ];
  };
})
