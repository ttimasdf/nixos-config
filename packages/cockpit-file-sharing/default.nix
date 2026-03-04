{
  attr,
  bash,
  coreutils,
  fetchFromGitHub,
  findutils,
  getent,
  glibc,
  hostname,
  iproute2,
  jq,
  lib,
  makeWrapper,
  nfs-utils,
  nodejs,
  python3,
  samba,
  stdenv,
  systemd,
  yarn-berry_4,
}:

let
  python = python3.withPackages (ps: [
    ps.botocore
  ]);
  yarn-berry = yarn-berry_4;
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

  nativeBuildInputs = [
    makeWrapper
    nodejs
    jq
    yarn-berry
    yarn-berry.yarnBerryConfigHook
  ];

  passthru.cockpitPath = [
    attr
    bash
    coreutils
    findutils
    getent
    glibc
    hostname
    iproute2
    nfs-utils
    nodejs
    python
    samba
    systemd
  ];

  env = {
    # Disable post-install scripts that try to access network (electron, plantuml-pipe)
    YARN_ENABLE_SCRIPTS = "0";
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  };

  preConfigurePhases = [ "patchHoustonPhase" ];

  patchHoustonPhase =
    let
      # houston-common-lib has @types/electron which pulls in electron.
      # Electron's postinstall downloads binaries, which fails in sandbox.
      # Since this is a Cockpit plugin (not an Electron app), we don't need electron.
      houstonLibDir = "houston-common/houston-common-lib";
      houstonUiDir = "houston-common/houston-common-ui";
    in
    ''
      # Remove electron type dependency
      substituteInPlace ${houstonLibDir}/package.json \
        --replace-fail '"@types/electron": "^1.6.12",' ""
      substituteInPlace ${houstonLibDir}/tsconfig.json \
        --replace-fail '"types": ["electron"]' '"types": []'

      # Skip TypeScript type checking (fails without electron types)
      substituteInPlace ${houstonLibDir}/package.json \
        --replace-fail '"build": "tsc --noEmit && vite build"' '"build": "vite build"'
      substituteInPlace ${houstonUiDir}/package.json \
        --replace-fail '"build": "run-p type-check \"build-only {@}\" --"' '"build": "vite build"'

      # Externalize vue and electron in houston-common-lib (peer dependencies)
      substituteInPlace ${houstonLibDir}/vite.config.ts \
        --replace-fail 'external: (id) => {' 'external: (id) => {
        if (id === "vue" || id.startsWith("vue/") || id === "electron" || id.startsWith("electron/")) return true;'
    '';

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
