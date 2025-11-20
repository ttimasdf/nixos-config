{
  lib,
  maven,
  fetchFromGitHub,
  unzip,
  python3,
}:
maven.buildMavenPackage rec {
  pname = "ghydra-mcp";
  version = "2-unstable-2025-11-15";

  src = fetchFromGitHub {
    owner = "starsong-consulting";
    repo = "GhydraMCP";
    rev = "662e202482a74867dcfbaf4a3f592d80d38234d6";
    hash = "sha256-wrid+NmfUhvAVkVN94PscKeywWGJatxX5dsrpKzNwac=";
    # .git is necessary for git-commit-id-maven-plugin
    leaveDotGit = true;
  };

  # Nix hash for <pname>-maven-deps derivation
  mvnHash = "sha256-k2KOvTEguHankbvOPhyl50XFQfnqc5nVxE24FJAhHkw=";

  nativeBuildInputs = [ unzip ];

  postBuild = ''
    rm target/GhydraMCP-Complete-*.zip
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/ghidra/Ghidra/Extensions
    unzip -d $out/lib/ghidra/Ghidra/Extensions target/GhydraMCP-*.zip

    # Prevent attempted creation of plugin lock files in the Nix store.
    for i in $out/lib/ghidra/Ghidra/Extensions/*; do
      touch "$i/.dbDirLock"
    done

    runHook postInstall
  '';

  meta = {
    description = "Multi-headed MCP Server for Ghidra";
    homepage = "https://github.com/starsong-consulting/GhydraMCP";
    downloadPage = "https://github.com/starsong-consulting/GhydraMCP/releases/";
    license = lib.licenses.apsl20;
    # maintainers = with lib.maintainers; [ timschumi ];
  };

  passthru.client = python3.pkgs.buildPythonApplication {
    pname = "${pname}-client";
    inherit src version;

    pyproject = true;
    build-system = [ python3.pkgs.hatchling ];
    dependencies = with python3.pkgs; [
      # https://github.com/modelcontextprotocol/python-sdk/pull/1198#issuecomment-3141372008
      (mcp.overrideAttrs (old: rec {
        version = "1.12.2";
        src = fetchFromGitHub {
          owner = "modelcontextprotocol";
          repo = "python-sdk";
          tag = "v${version}";
          hash = "sha256-K3S+2Z4yuo8eAOo8gDhrI8OOfV6ADH4dAb1h8PqYntc=";
        };
      }))
      requests
    ];

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace '==' '>='
    '';
  };
}
