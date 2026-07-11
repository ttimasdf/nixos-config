{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pnpm,
  pnpmConfigHook,
  fetchPnpmDeps,
  nodejs,
  cargo,
  rustc,
  pkg-config,
  wrapGAppsHook3,
  at-spi2-atk,
  atkmm,
  cairo,
  gdk-pixbuf,
  glib,
  gtk3,
  harfbuzz,
  librsvg,
  libsoup_3,
  pango,
  webkitgtk_4_1,
  openssl,
  libayatana-appindicator,
}:

# cc-switch —— Tauri 2 + pnpm + Rust 的桌面应用。
#
# 为什么这样打：
#   - Tauri 的 `tauri build` 会在最后一步尝试从 GitHub 拉 AppRun 等 bundler 资源，
#     Nix 沙盒里没网会失败；所以这里分两步：先 `pnpm build:renderer` 产出 dist/，
#     再直接 `cargo build --release` 产出二进制（Tauri crate 的 build.rs 会嵌入 dist）。
#   - 运行期 `libayatana-appindicator` 是 dlopen 的，需要塞进 LD_LIBRARY_PATH；
#     这里统一走 `wrapGAppsHook3` 的 gappsWrapperArgs，顺手把 KDE Wayland 白屏
#     兜底用的 `GDK_BACKEND=x11` 和 WebKit DMABUF 关闭也定死。
#
# 更新时：
#   1. 改 version 与 src.rev / hash。
#   2. 第一次 `nix-build` 会因 pnpmDeps 的 fake hash 报错，把错误里 got: 的
#      sha256 贴回 pnpmDeps.hash 即可。
#   3. Cargo 依赖走 importCargoLock，不需要 hash。

stdenv.mkDerivation (finalAttrs: {
  pname = "cc-switch";
  version = "3.16.5";

  src = fetchFromGitHub {
    owner = "farion1231";
    repo = "cc-switch";
    rev = "v${finalAttrs.version}";
    # 第一次 build 会报错并给出真实 hash，粘回来即可。
    hash = "sha256-CrUoTfGAy+gi3gdcSlNyjwM2Rm4nahqDWdM6I9OQgPc=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    hash = "sha256-4S00JM93MR5ARL2eginyNh/0dIrzU5rJQYS1x1PYoig=";
  };

  cargoDeps = rustPlatform.importCargoLock {
    lockFile = "${finalAttrs.src}/src-tauri/Cargo.lock";
  };

  cargoRoot = "src-tauri";

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    rustPlatform.cargoSetupHook
    cargo
    rustc
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    at-spi2-atk
    atkmm
    cairo
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    librsvg
    libsoup_3
    pango
    webkitgtk_4_1
    openssl
    libayatana-appindicator
  ];

  # Tauri 会把 frontend dist 嵌到二进制里；必须先 build:renderer 再 cargo build。
  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)

    # 抹掉 devUrl，强制 tauri 走 frontendDist；否则 release 二进制仍会去连 localhost:3000
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"devUrl": "http://localhost:3000",' ""

    pnpm run build:renderer

    ( cd src-tauri && cargo build --release --frozen )

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 src-tauri/target/release/cc-switch $out/bin/cc-switch

    # 图标
    for size in 32x32 128x128; do
      install -Dm644 src-tauri/icons/''${size}.png \
        $out/share/icons/hicolor/''${size}/apps/cc-switch.png
    done
    install -Dm644 src-tauri/icons/128x128@2x.png \
      $out/share/icons/hicolor/256x256/apps/cc-switch.png

    # .desktop —— 顺便把 ccswitch:// deep link 协议也登记上
    install -Dm644 /dev/stdin $out/share/applications/cc-switch.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=CC Switch
    GenericName=Claude Code / Codex / Gemini CLI Switcher
    Comment=All-in-One Assistant for Claude Code, Codex & Gemini CLI
    Exec=cc-switch %U
    Icon=cc-switch
    Terminal=false
    Categories=Development;Utility;
    MimeType=x-scheme-handler/ccswitch;
    StartupWMClass=CC Switch
    EOF

    runHook postInstall
  '';

  # 这里把运行期 env 注入到 wrapGAppsHook3 生成的 wrapper 里：
  #   - libayatana-appindicator 是 dlopen 加载的，必须上 LD_LIBRARY_PATH
  #   - GDK_BACKEND=x11 / WEBKIT_* 是 KDE Wayland 下白屏 & 比例错乱的兜底
  #     （可 override 掉：`GDK_BACKEND=wayland cc-switch`）
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}"
      --set-default GDK_BACKEND x11
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
      --set-default WEBKIT_DISABLE_COMPOSITING_MODE 1
    )
  '';

  meta = with lib; {
    description = "All-in-One Assistant for Claude Code, Codex & Gemini CLI";
    homepage = "https://github.com/farion1231/cc-switch";
    license = licenses.mit;
    mainProgram = "cc-switch";
    platforms = platforms.linux;
  };
})
