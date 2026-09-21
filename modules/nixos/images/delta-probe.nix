# The store paths an ISO has to carry on top of the host's runtime closure so
# that the system derivations regenerated from `hardware-configuration.nix` can
# still be built offline.
#
# Pure evaluation, and no `.drv` file ever crosses a derivation boundary:
# a `.drv` path threaded through a derivation attribute (linkFarm paths,
# passAsFile) makes Nix expand it to the root's entire recursive build closure
# *with every output* -- debug, doc, man, the kernel's dev output, tens of
# gigabytes. Reading `.drv` files at evaluation time is pure-mode-forbidden, so
# the input set is reconstructed from what the ATerm itself was built from: the
# string contexts of the root's fully-computed attrs (`.drvAttrs` is what the
# `derivation` builtin received; its contexts are exactly the ATerm's input
# sources and input derivations with their *used* outputs). Derivation values
# seen along the way map output names to store paths; derivations that only
# appear interpolated fall back to the store paths mentioned in their strings,
# matched by the conventional `-<output>` suffix. Every harvested path is
# returned with its natural context -- the same context `"${pkg.dev}"` carries
# -- so the ISO's closureInfo schedules exactly those outputs and nothing else.
#
# The list is not filtered against what the ISO already carries: paths inside
# the host's runtime closure are free (closureInfo unions and dedups the
# closures of all roots). The roots' own outputs are dropped: they are
# regenerated on the target, where nothing references their old outputs.
{ lib, deltaRoots }:
let
  inherit (builtins)
    appendContext
    attrNames
    elemAt
    getContext
    ;

  bare = p: builtins.unsafeDiscardStringContext p;

  matchGroups = re: s: builtins.filter (lib.isList) (builtins.split re s);

  # A store path prefix as it can appear inside a string.
  storePathRE = ''(/nix/store/[0-9a-z]+-[0-9A-Za-z._+=?*-]*)'';

  # -- harvest the root's direct input set from its computed attrs ----------

  # acc: { values = [derivation]; srcs = [path];
  #        needs = [{drv, names}]; texts = [{paths, drvs}] }
  #
  # Derivation values contribute a need for the output they stand for: the
  # string `derivation` generates from them (with that output selection) is
  # not visible in `drvAttrs`.
  harvest =
    acc: v:
    if lib.isDerivation v then
      acc
      // {
        values = acc.values ++ [ v ];
        needs = acc.needs ++ [
          {
            drv = bare v.drvPath;
            names = [ v.outputName or "out" ];
          }
        ];
      }
    else if builtins.isString v then
      let
        ctx = getContext v;
        keys = attrNames ctx;
        pathKeys = builtins.filter (k: ctx.${k} ? path) keys;
        drvKeys = builtins.filter (k: (ctx.${k} ? outputs) && ctx.${k}.outputs != [ ]) keys;
        drvNeeds = map (k: { drv = k; names = ctx.${k}.outputs; }) drvKeys;
        paths = map (g: elemAt g 0) (matchGroups storePathRE v);
        texts = lib.optionals (paths != [ ]) [ { inherit paths; drvs = drvKeys; } ];
      in
      acc // {
        srcs = acc.srcs ++ pathKeys;
        needs = acc.needs ++ drvNeeds;
        texts = acc.texts ++ texts;
      }
    else if builtins.isList v then builtins.foldl' harvest acc v
    else if builtins.isAttrs v then lib.foldl' harvest acc (lib.attrValues v)
    else acc;

  harvested = builtins.foldl'
    (acc: root: harvest acc root.drvAttrs)
    {
      values = [ ];
      srcs = [ ];
      needs = [ ];
      texts = [ ];
    }
    deltaRoots;

  # -- output name -> store path over the collected derivation values --------

  # The outputs of a derivation value: attrs that are derivations sharing its
  # .drvPath (`jq.dev` etc.).
  outputsOf =
    v:
    let
      sameDrv =
        a:
        let
          w = builtins.tryEval (v.${a});
        in
        w.success && lib.isDerivation w.value && w.value ? outPath && bare w.value.drvPath == bare v.drvPath;
    in
    builtins.filter sameDrv (attrNames v);

  pathOf = v: n: bare (if n == "out" then v.outPath else v.${n}.outPath);

  valuesByDrv = builtins.listToAttrs (
    map (v: lib.nameValuePair (bare v.drvPath) v) (lib.unique harvested.values)
  );

  needsByDrv = lib.foldl'
    (m: need: m // { ${need.drv} = lib.unique ((m.${need.drv} or [ ]) ++ need.names); })
    { }
    harvested.needs;

  # The exact (derivation, output) pairs Nix requires valid to build the
  # roots; `out` needs no explicit attr on the value.
  resolved =
    lib.concatMap
      (
        drv:
        let
          v = valuesByDrv.${drv} or null;
          names = needsByDrv.${drv};
        in
        if v != null then
          lib.filter (r: r != null) (
            map (
              n:
              let
                w = builtins.tryEval (v.${n});
              in
              if n == "out" then { path = bare v.outPath; inherit drv; n = "out"; }
              else if w.success && lib.isDerivation w.value && bare w.value.drvPath == drv then { path = bare w.value.outPath; inherit drv n; }
              else null
            ) names
          )
        else
          # Interpolation fallback: store paths mentioned by strings whose
          # context names this derivation. Output paths share the derivation's
          # name (`…-name.drv` -> `…-name` for out, `…-name-dev` for dev), so
          # candidates are matched by name; an ambiguous name yields nothing.
          let
            drvName =
              let
                s = lib.removeSuffix ".drv" (lib.removePrefix "/nix/store/" drv);
              in
              builtins.substring 33 (builtins.stringLength s - 33) s;
            candidates = lib.subtractLists harvested.srcs (
              lib.unique (lib.concatMap (t: t.paths) (builtins.filter (t: builtins.elem drv t.drvs) harvested.texts))
            );
            nameOf = p: builtins.substring 44 (builtins.stringLength p - 44) p;
            pick =
              n:
              let
                want = drvName + lib.optionalString (n != "out") "-${n}";
                matches = builtins.filter (c: nameOf c == want) candidates;
              in
              if builtins.length matches == 1 then builtins.head matches else null;
          in
          lib.filter (r: r != null) (
            map (n: let p = pick n; in if p == null then null else { path = p; inherit drv n; }) names
          )
      )
      (attrNames needsByDrv);

  # -- assemble --------------------------------------------------------------

  # The roots are regenerated on the target; their old outputs are ballast.
  rootOutPaths = builtins.listToAttrs (
    lib.concatMap (v: [ (lib.nameValuePair (bare v.outPath) true) ] ++ map (o: lib.nameValuePair (pathOf v o) true) (outputsOf v)) deltaRoots
  );

  srcEntries = map (p: appendContext p { ${p} = { path = true; }; }) (
    builtins.filter (p: p != "" && !rootOutPaths ? ${p}) (lib.unique harvested.srcs)
  );

  outputEntries = map (r: appendContext r.path { ${r.drv} = { outputs = [ r.n ]; }; }) (
    builtins.filter (r: !rootOutPaths ? ${r.path}) (lib.unique resolved)
  );
in
lib.sort (a: b: bare a < bare b) (srcEntries ++ outputEntries)
