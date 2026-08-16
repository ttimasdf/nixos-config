{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, wrapGAppsHook3
, cairo
, dbus
, fontconfig
, gdk-pixbuf
, glib
, glib-networking
, gtk3
, libayatana-appindicator
, libsoup_3
, webkitgtk_4_1
, gsettings-desktop-schemas
, libX11
, libXi
}:

# DBX —— 基于 WebKitGTK 4.1 的跨平台数据库客户端。
#
# 用官方 .deb 而不是 AppImage：
#   - AppImage 自包含了一整套旧的 GTK/WebKit/wayland 库，其中旧 libwayland-client
#     缺少 mesa 26 所需的 wl_fixes_interface 符号，导致 EGL display 创建失败 → 白屏，
#     需要 buildFHSEnv + 一堆 LD_LIBRARY_PATH/CD 覆盖才能跑。
#   - .deb 只打包 63MB 的 dbx 二进制 + 图标 + .desktop，依赖声明为
#     libappindicator3-1 / libwebkit2gtk-4.1-0 / libgtk-3-0。二进制本身 NEEDED 仅
#     12 个系统库，没有捆绑任何旧库，因此不存在版本冲突。
#     autoPatchelfHook 补 rpath + wrapGAppsHook3 注入 GIO/XDG_DATA_DIRS 等即可，
#     干净得多，闭包也小（~0.9GB vs FHS 的 ~2.4GB）。
#
# 更新时运行 `packages/dbx/update.sh`：读取 GitHub latest release，回写 version
# 与 .deb 的 SRI hash。

let
  pname = "dbx";
  version = "0.5.85";

  runtimeDependencies = [
    cairo
    dbus
    fontconfig
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libayatana-appindicator
    libsoup_3
    webkitgtk_4_1
    gsettings-desktop-schemas
    stdenv.cc.cc.lib
    libX11
    libXi
  ];
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/t8y2/dbx/releases/download/v${version}/DBX_${version}_amd64.deb";
    hash = "sha256-ehw6LkfT4fjlmUNIU55SVVTIzWZACJJ7yXIQO12RD+0=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = runtimeDependencies;

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb --fsys-tarfile $src | tar --extract --no-same-owner --no-same-permissions

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 usr/bin/dbx $out/bin/dbx

    # 图标（deb 自带三层）
    install -Dm644 usr/share/icons/hicolor/32x32/apps/dbx.png \
      $out/share/icons/hicolor/32x32/apps/dbx.png
    install -Dm644 usr/share/icons/hicolor/128x128/apps/dbx.png \
      $out/share/icons/hicolor/128x128/apps/dbx.png
    install -Dm644 usr/share/icons/hicolor/256x256@2/apps/dbx.png \
      $out/share/icons/hicolor/512x512/apps/dbx.png

    # .desktop —— 登记 deep link 协议，Exec 指向 wrapper
    install -Dm644 usr/share/applications/DBX.desktop \
      $out/share/applications/dbx.desktop
    substituteInPlace $out/share/applications/dbx.desktop \
      --replace-fail 'Exec=dbx' 'Exec=dbx %U' \
      --replace-fail 'Categories=' 'Categories=Development;Database;'

    runHook postInstall
  '';

  # WebKitGTK 在部分环境（含 NixOS 的 DMABUF/compositing 路径）仍可能白屏，
  # 保留这两个开关作为保险。仅未设置时赋值，允许用户覆盖。
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeDependencies}"
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
      --set-default WEBKIT_DISABLE_COMPOSITING_MODE 1
    )
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "A lightweight cross-platform database client for 70+ databases (MySQL, PostgreSQL, SQLite, Redis, MongoDB, DuckDB, SQL Server, etc.)";
    homepage = "https://dbxio.com";
    downloadPage = "https://github.com/t8y2/dbx/releases";
    license = licenses.asl20;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
})
