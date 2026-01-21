{
  lib,
  writeTextFile,
  buildPackages,
}:

/**
  An extended utility builder to create a desktop entry file with localization support.

  Extends the standard makeDesktopItem with:
  - Localized names, generic names, comments, and keywords
  - Actions with extraConfig support for vendor extensions
  - Full support for all freedesktop.org Desktop Entry Specification 1.5 features

  # Examples

  ```nix
  makeDesktopItemExtended {
    name = "spectacle";
    exec = "spectacle";
    icon = "spectacle";
    desktopName = "Spectacle";

    # Localized names
    localizedNames = {
      "zh_CN" = "Spectacle 截图工具";
      "ja" = "スクリーンショット";
    };

    genericName = "Screenshot Capture Utility";
    localizedGenericNames = {
      "zh_CN" = "屏幕截图工具";
      "ja" = "スクリーンショット撮影ユーティリティ";
    };

    # Actions with extra configuration
    actions = {
      FullScreenScreenShot = {
        name = "Capture Entire Desktop";
        localizedNames = {
          "zh_CN" = "截取整个桌面";
        };
        exec = "spectacle -f";
        extraConfig = {
          "X-KDE-Shortcuts" = "Shift+Print";
        };
      };
    };

    # Vendor extensions
    extraConfig = {
      "X-KDE-Shortcuts" = "Print,Meta+Shift+S";
      "X-DBUS-ServiceName" = "org.kde.Spectacle";
    };
  }
  ```

  # Type

  ```
  makeDesktopItemExtended :: AttrSet -> Derivation
  ```

  # Input

  `attrs`

  : An AttrSet with the following definitions. See https://specifications.freedesktop.org/desktop-entry-spec/1.5/ for definitions.

    All parameters from makeDesktopItem are supported, plus:

    - `localizedNames` (AttrSet): Mapping of locale -> localized Name value (e.g., { "zh_CN" = "中文名称"; })
    - `localizedGenericNames` (AttrSet): Mapping of locale -> localized GenericName value
    - `localizedComments` (AttrSet): Mapping of locale -> localized Comment value
    - `localizedKeywords` (AttrSet): Mapping of locale -> list of localized Keywords
    - `actions` (AttrSet): Actions with extended support for localizedNames and extraConfig
      Each action can have:
      - `name` (string): The action name
      - `localizedNames` (AttrSet): Localized action names
      - `icon` (string): The action icon
      - `exec` (string): The action exec command
      - `extraConfig` (AttrSet): Additional vendor-specific configuration for this action

  # Output

  A derivation that contains the output desktop entry file.
*/
lib.makeOverridable (
  {
    name, # The name of the desktop file
    destination ? "/share/applications",
    type ? "Application",
    # version is hardcoded
    desktopName, # The name of the application
    localizedNames ? { }, # Localized names: { "zh_CN" = "中文名称"; "ja" = "日本語名"; }
    genericName ? null,
    localizedGenericNames ? { }, # Localized generic names
    noDisplay ? null,
    comment ? null,
    localizedComments ? { }, # Localized comments
    icon ? null,
    # we don't support the Hidden key - if you don't need something, just don't install it
    onlyShowIn ? [ ],
    notShowIn ? [ ],
    dbusActivatable ? null,
    tryExec ? null,
    exec ? null,
    path ? null,
    terminal ? null,
    actions ? { }, # An attrset of [internal name] -> { name, localizedNames?, exec?, icon?, extraConfig? }
    mimeTypes ? [ ], # The spec uses "MimeType" as singular, use plural here to signify list-ness
    categories ? [ ],
    implements ? [ ],
    keywords ? [ ],
    localizedKeywords ? { }, # Localized keywords: { "zh_CN" = [ "中文"; "关键词" ]; }
    startupNotify ? null,
    startupWMClass ? null,
    url ? null,
    prefersNonDefaultGPU ? null,
    singleMainWindow ? null,
    extraConfig ? { }, # Additional values to be added literally to the final item, e.g. vendor extensions
  }:
  let
    # There are multiple places in the FDO spec that make "boolean" values actually tristate,
    # e.g. StartupNotify, where "unset" is literally defined as "do something reasonable".
    # So, handle null values separately.
    boolOrNullToString =
      value:
      if value == null then
        null
      else if builtins.isBool value then
        lib.boolToString value
      else
        throw "makeDesktopItemExtended: value must be a boolean or null!";

    # Multiple values are represented as one string, joined by semicolons.
    # Technically, it's possible to escape semicolons in values with \;, but this is currently not implemented.
    renderList =
      key: value:
      if !builtins.isList value then
        throw "makeDesktopItemExtended: value for ${key} must be a list!"
      else if builtins.any (item: lib.hasInfix ";" item) value then
        throw "makeDesktopItemExtended: values in ${key} list must not contain semicolons!"
      else if value == [ ] then
        null
      else
        builtins.concatStringsSep ";" value;

    # Render localized entries for a given key
    # Returns a list of { key, value } pairs
    renderLocalizedEntries =
      baseKey: localizedAttrs:
      lib.pipe localizedAttrs [
        (lib.mapAttrsToList (locale: value: {
          key = "${baseKey}[${locale}]";
          value = value;
        }))
      ];

    # Render localized list entries (for keywords)
    renderLocalizedListEntries =
      baseKey: localizedAttrs:
      lib.pipe localizedAttrs [
        (lib.mapAttrsToList (locale: value: {
          key = "${baseKey}[${locale}]";
          value = renderList "${baseKey}[${locale}]" value;
        }))
        (builtins.filter (item: item.value != null))
      ];

    # The [Desktop Entry] section of the desktop file, as an attribute set.
    # Please keep in spec order.
    mainSection = {
      "Type" = type;
      "Version" = "1.5";
      "Name" = desktopName;
      "GenericName" = genericName;
      "NoDisplay" = boolOrNullToString noDisplay;
      "Comment" = comment;
      "Icon" = icon;
      "OnlyShowIn" = renderList "onlyShowIn" onlyShowIn;
      "NotShowIn" = renderList "notShowIn" notShowIn;
      "DBusActivatable" = boolOrNullToString dbusActivatable;
      "TryExec" = tryExec;
      "Exec" = exec;
      "Path" = path;
      "Terminal" = boolOrNullToString terminal;
      "Actions" = renderList "actions" (builtins.attrNames actions);
      "MimeType" = renderList "mimeTypes" mimeTypes;
      "Categories" = renderList "categories" categories;
      "Implements" = renderList "implements" implements;
      "Keywords" = renderList "keywords" keywords;
      "StartupNotify" = boolOrNullToString startupNotify;
      "StartupWMClass" = startupWMClass;
      "URL" = url;
      "PrefersNonDefaultGPU" = boolOrNullToString prefersNonDefaultGPU;
      "SingleMainWindow" = boolOrNullToString singleMainWindow;
    }
    // extraConfig;

    # Generate localized entries
    localizedNameEntries = renderLocalizedEntries "Name" localizedNames;
    localizedGenericNameEntries = renderLocalizedEntries "GenericName" localizedGenericNames;
    localizedCommentEntries = renderLocalizedEntries "Comment" localizedComments;
    localizedKeywordEntries = renderLocalizedListEntries "Keywords" localizedKeywords;

    # Render a single attribute pair to a Key=Value line.
    # FIXME: this isn't entirely correct for arbitrary strings, as some characters
    # need to be escaped. There are currently none in nixpkgs though, so this is OK.
    renderLine = name: value: if value != null then "${name}=${value}" else null;

    # Render a full section of the file from an attrset.
    # Null values are intentionally left out.
    renderSection =
      sectionName: attrs: localizedEntries:
      let
        mainLines = lib.pipe attrs [
          (lib.mapAttrsToList renderLine)
          (builtins.filter (v: v != null))
        ];
        localizedLines = builtins.map (item: "${item.key}=${item.value}") localizedEntries;
        allLines = mainLines ++ localizedLines;
      in
      ''
        [${sectionName}]
        ${builtins.concatStringsSep "\n" allLines}
      '';

    allLocalizedEntries =
      localizedNameEntries
      ++ localizedGenericNameEntries
      ++ localizedCommentEntries
      ++ localizedKeywordEntries;

    mainSectionRendered = renderSection "Desktop Entry" mainSection allLocalizedEntries;

    # Convert from action attributes to desktop action format
    preprocessAction =
      {
        name,
        localizedNames ? { },
        icon ? null,
        exec ? null,
        extraConfig ? { },
      }:
      {
        attrs = {
          "Name" = name;
          "Icon" = icon;
          "Exec" = exec;
        } // extraConfig;
        localizedNames = renderLocalizedEntries "Name" localizedNames;
      };

    renderAction =
      name: actionAttrs:
      let
        processed = preprocessAction actionAttrs;
      in
      renderSection "Desktop Action ${name}" processed.attrs processed.localizedNames;

    actionsRendered = lib.mapAttrsToList renderAction actions;

    extension = if type == "Directory" then "directory" else "desktop";
    content = [ mainSectionRendered ] ++ actionsRendered;
  in
  writeTextFile {
    name = "${name}.${extension}";
    destination = "${destination}/${name}.${extension}";
    text = builtins.concatStringsSep "\n" content;
    checkPhase = ''${buildPackages.desktop-file-utils}/bin/desktop-file-validate "$target"'';
  }
)
