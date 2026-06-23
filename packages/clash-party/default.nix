{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  gtk3,
  glib,
  libdrm,
  libgbm,
  libnotify,
  libsecret,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  vulkan-loader,
  xdg-utils,
  libpulseaudio,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libXtst,
  libxcb,
}:

# clash-party (mihomo-party) —— Electron + electron-builder 的代理客户端。
#
# 为什么解官方 .deb 而不是像 cc-switch 那样从源码 build：
#   - 它是 Electron 应用，构建脚本 scripts/prepare.mjs 在 build 前会从一堆
#     GitHub release 在线拉 sidecar（mihomo / mihomo-alpha / mihomo-smart 内核、
#     geoip/geosite 数据库、sysproxy 的 native .node）。Nix 沙盒没网，从源码
#     复刻这些 fixed-output fetch 既脆弱又巨大。
#   - 官方 .deb 里已经把 Electron 运行时 + 所有 sidecar 内核 + 数据库都打好了，
#     直接 dpkg 解包 + autoPatchelfHook 修 rpath 即可，最稳。
#
# 运行期注意：
#   - chrome-sandbox 需要 setuid 才能用，Nix store 给不了 setuid；统一加
#     --no-sandbox（和 qoder-cn 一样）。
#   - 主程序与各 sidecar 内核都要走 autoPatchelf，buildInputs 覆盖 Electron
#     + mihomo 的运行期依赖。
#
# 更新时运行 `packages/clash-party/update.sh`，脚本读取 GitHub latest release，
# 自动回写 version 与两个架构的 deb hash。

let
  pname = "clash-party";
  version = "1.9.6";

  selectSystem =
    attrs:
    attrs.${stdenv.hostPlatform.system}
      or (throw "clash-party: ${stdenv.hostPlatform.system} is not supported");

  src = selectSystem {
    x86_64-linux = fetchurl {
      url = "https://github.com/mihomo-party-org/clash-party/releases/download/v${version}/clash-party-linux-${version}-amd64.deb";
      # 第一次 build 会报错并给出真实 hash，粘回来即可。
      hash = "sha256-n8FUF0Mur6UdrSEhf1V8XEsCkvgU52/9xqRTpFH1geo=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/mihomo-party-org/clash-party/releases/download/v${version}/clash-party-linux-${version}-arm64.deb";
      hash = "sha256-6xAawxd4KA/jjpSr78kZyJmmAtzQQvlulX3W2rzdgK4=";
    };
  };

  runtimeDependencies = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    gtk3
    glib
    libdrm
    libgbm
    libnotify
    libsecret
    libxkbcommon
    libpulseaudio
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    vulkan-loader
    xdg-utils
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libXtst
    libxcb
  ];
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version src;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = runtimeDependencies;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar --extract --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share

    # Electron 运行时 + 各 mihomo sidecar 内核 + geoip 数据库整体搬进 $out/share。
    cp -r opt/clash-party $out/share/clash-party

    # chrome-sandbox 在 Nix store 里拿不到 setuid，留着也没用，删掉避免误用。
    rm -f $out/share/clash-party/chrome-sandbox

    # 图标（官方 deb 只带一个 512x512）。
    install -Dm644 usr/share/icons/hicolor/512x512/apps/mihomo-party.png \
      $out/share/icons/hicolor/512x512/apps/clash-party.png

    # --no-sandbox：Nix store 无 setuid 的 chrome-sandbox，否则 Electron 直接拒启。
    makeWrapper $out/share/clash-party/mihomo-party $out/bin/clash-party \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeDependencies} \
      --add-flags "--no-sandbox"

    # .desktop —— 登记 clash:// 与 mihomo:// deep link 协议，Exec 指向 wrapper。
    install -Dm644 /dev/stdin $out/share/applications/clash-party.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Clash Party
    GenericName=Proxy Client
    Comment=A Mihomo-based proxy client
    Exec=clash-party %U
    Icon=clash-party
    Terminal=false
    Categories=Network;
    MimeType=x-scheme-handler/clash;x-scheme-handler/mihomo;
    Keywords=proxy;clash;mihomo;vpn;
    StartupWMClass=mihomo-party
    EOF

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Clash Party (mihomo-party) — a Mihomo-based proxy client";
    homepage = "https://github.com/mihomo-party-org/clash-party";
    license = lib.licenses.gpl3Only;
    mainProgram = "clash-party";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
