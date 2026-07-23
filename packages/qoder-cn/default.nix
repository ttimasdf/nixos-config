{ lib
, buildVscode
, fetchurl
, runCommand
, dpkg
, bash
, ripgrep
, commandLineArgs ? ""
,
}:

let
  pname = "qoder-cn";
  version = "1.8.0";
  vscodeVersion = "1.106.3";

  deb = fetchurl {
    url = "https://ide.qoder.com.cn/qoder/release/${version}/qoder-cn_amd64.deb";
    hash = "sha256-Rw/e8nx7IfgxXnn3ZIoDgbn8czZ/4CcquedjxVWoBC0=";
  };

  src = runCommand "${pname}-${version}-extracted" { nativeBuildInputs = [ dpkg ]; } ''
    mkdir -p "$out"
    dpkg-deb --fsys-tarfile ${deb} \
      | tar --extract --directory "$out" --no-same-owner --no-same-permissions
  '';
in
(buildVscode {
  inherit
    commandLineArgs
    pname
    src
    version
    vscodeVersion
    ;

  executableName = "qoder-cn";
  longName = "Qoder CN";
  shortName = "QoderCN";
  libraryName = "qoder-cn";
  iconName = "qoder-cn";

  sourceRoot = "${pname}-${version}-extracted/usr/share/qoder-cn";

  # The upstream launcher resolves VSCODE_PATH correctly through its symlink.
  patchVSCodePath = false;

  tests = { };
  updateScript = null;

  meta = {
    description = "Agentic coding platform designed for real software development";
    homepage = "https://qoder.cn";
    downloadPage = "https://qoder.cn/download";
    license = lib.licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "qoder-cn";
  };
}).overrideAttrs (oldAttrs: {
  # Qoder 1.106 backports the ripgrep-universal layout that upstream VS Code
  # only uses from 1.122, so the generic builder's version heuristic does not
  # apply. Keep the other relevant VS Code patches while selecting the actual
  # path shipped by Qoder.
  postPatch = ''
    tmpProductJson="$(mktemp)"
    jq 'del(.updateUrl, .backupUpdateUrl)' resources/app/product.json > "$tmpProductJson"
    mv "$tmpProductJson" resources/app/product.json

    substituteInPlace resources/app/node_modules/@vscode/sudo-prompt/index.js \
      --replace-fail "/usr/bin/pkexec" "/run/wrappers/bin/pkexec" \
      --replace-fail "/bin/bash" "${bash}/bin/bash"

    rm resources/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64/rg
    ln -s ${ripgrep}/bin/rg \
      resources/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64/rg

    rm resources/app/node_modules.asar
    ln -rs resources/app/node_modules resources/app/node_modules.asar
  '';

  postInstall = (oldAttrs.postInstall or "") + ''
    ln -s "$out/lib/qoder-cn/bin/qoder-cn-tunnel" "$out/bin/qoder-cn-tunnel"
    ln -s \
      "$out/lib/qoder-cn/resources/app/resources/bin/x86_64_linux/QoderCN" \
      "$out/bin/qoder-cn-cli"
  '';

  preFixup = (oldAttrs.preFixup or "") + ''
    sed -i '/^Keywords=/a MimeType=application/x-qoder-cn-workspace;' \
      "$out/share/applications/qoder-cn.desktop"
    grep -q '^MimeType=application/x-qoder-cn-workspace;$' \
      "$out/share/applications/qoder-cn.desktop"
  '';
})
