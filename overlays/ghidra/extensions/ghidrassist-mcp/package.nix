{
  lib,
  fetchFromGitHub,
  buildGhidraExtension,
  gradle,
}:
buildGhidraExtension (finalAttrs: {
  pname = "ghidrassist-mcp";
  version = "0-unstable-2025-11-20";

  src = fetchFromGitHub {
    # owner = "jtang613";
    owner = "ttimasdf";
    repo = "GhidrAssistMCP";
    # https://github.com/ttimasdf/GhidrAssistMCP/tree/feat-tool-structure-field
    rev = "d694c051e3f9d30ee6fc9cd19515d4abf4200dd5";
    hash = "sha256-IeJvGoJRKlJMF5EAdyhd5ORCRHb2ZDsOs10CkjrSLAE=";
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
