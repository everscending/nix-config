# ccstatusline is not in nixpkgs, so package it here from the published npm
# tarball. That tarball already contains the built, dependency-free
# dist/ccstatusline.js, so there is nothing to compile and no node_modules to
# pin - just a hash-checked download wrapped in the same node the rest of this
# config installs.
#
# To update: bump version, then take `hash` verbatim from the `integrity` field
# of https://registry.npmjs.org/ccstatusline/<version> (npm publishes an SRI
# hash, which is the format Nix wants).
{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, nodejs
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ccstatusline";
  version = "2.2.30";

  src = fetchurl {
    url = "https://registry.npmjs.org/ccstatusline/-/ccstatusline-${finalAttrs.version}.tgz";
    hash = "sha512-5pzYEFjag+oRAI8udChxiN3lKFtzcHhu8KAsEP3T/wU6u3DsT0QJ3fAL2J4Cr+eo9AqRalqvP4sYpDguzn/1HQ==";
  };

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/ccstatusline" "$out/bin"
    cp -R . "$out/lib/ccstatusline"
    makeWrapper ${lib.getExe nodejs} "$out/bin/ccstatusline" \
      --add-flags "$out/lib/ccstatusline/dist/ccstatusline.js"
    runHook postInstall
  '';

  meta = {
    description = "Customizable status line formatter for Claude Code";
    homepage = "https://github.com/sirmalloc/ccstatusline";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "ccstatusline";
  };
})
