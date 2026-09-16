{ pkgs, lib }:
# The first-install manual, in raw Markdown and rendered HTML.
let
  # Placeholder the manual uses for the host name.
  manualHostPattern = "\${HOST}";
  installManualSrc = ../../../docs/install.md;

  # Fill the manual's host placeholder with the host packed into this ISO, so
  # the on-ISO instructions match what the ISO actually carries.
  mkInstallManualMd = packedHost:
    if packedHost == null then
      installManualSrc
    else
      pkgs.runCommand "nixos-install-manual.md" { } ''
        substitute ${installManualSrc} $out \
          --replace-fail ${lib.escapeShellArg manualHostPattern} ${lib.escapeShellArg packedHost}
      '';

  mkInstallManualHtml = md: pkgs.runCommand "nixos-install-manual.html"
    {
      nativeBuildInputs = [ pkgs.pandoc ];
    } ''
    cat > manual-header.html <<'HTML'
    <style>
      body { max-width: 54rem; margin: 2.5rem auto; padding: 0 1.25rem;
             font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
             line-height: 1.55; color: #1a1a1a; }
      h1, h2, h3 { line-height: 1.25; }
      code { background: #f2f2f2; padding: .1em .3em; border-radius: 4px; }
      pre { background: #f2f2f2; padding: .8rem 1rem; border-radius: 6px;
            overflow-x: auto; }
      pre code { background: none; padding: 0; }
      table { border-collapse: collapse; }
      th, td { border: 1px solid #ccc; padding: .35rem .6rem; text-align: left; }
      blockquote { border-left: 4px solid #ccc; margin-left: 0; padding-left: 1rem;
                   color: #444; }
    </style>
    HTML
    pandoc \
      --from gfm \
      --to html5 \
      --standalone \
      --include-in-header manual-header.html \
      --metadata title="KnownRabbit NixOS - first install" \
      --metadata lang=en \
      ${md} > $out
  '';
in
{
  inherit mkInstallManualMd mkInstallManualHtml;
}
