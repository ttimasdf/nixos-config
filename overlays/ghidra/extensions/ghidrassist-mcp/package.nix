{
  lib,
  fetchFromGitHub,
  buildGhidraExtension,
  gradle,
}:
buildGhidraExtension (finalAttrs: {
  pname = "ghidrassist-mcp";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "jtang613";
    repo = "GhidrAssistMCP";
    rev = "${finalAttrs.version}";
    hash = "sha256-ZjoRAWk3goKXERJonWKdAQUUFS8EK395hauxevFLCR4=";
  };

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
  };

  meta = {
    description = "An MCP extension for Ghidra";
    homepage = "https://github.com/jtang613/GhidrAssistMCP";
    downloadPage = "https://github.com/jtang613/GhidrAssistMCP/releases/tag/${finalAttrs.version}";
    changelog = "https://github.com/jtang613/GhidrAssistMCP/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    # maintainers = [ "jtang613" ];
  };
})
