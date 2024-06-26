{
  pkgs,
  lib,
  stdenv,
  autoconf-archive,
  autoreconfHook,
  aws-sdk-cpp,
  # If the patched version of Boehm isn't passed, then patch it based off of
  # pkgs.boehmgc. This allows `callPackage`ing this file without needing to
  # to implement behavior that this package flat out doesn't build without
  # anyway, but also allows easily overriding the patch logic.
  boehmgc-nix ? __forDefaults.boehmgc-nix,
  boehmgc,
  nlohmann_json,
  bison,
  build-release-notes,
  boost,
  brotli,
  bzip2,
  cmake,
  curl,
  doxygen,
  editline,
  fetchurl,
  flex,
  git,
  gtest,
  jq,
  libarchive,
  libcpuid,
  libseccomp-nix ? __forDefaults.libseccomp-nix,
  libseccomp,
  libsodium,
  lsof,
  lowdown,
  mdbook,
  mdbook-linkcheck,
  mercurial,
  meson,
  ninja,
  openssl,
  pkg-config,
  python3,
  rapidcheck,
  sqlite,
  toml11,
  util-linuxMinimal ? utillinuxMinimal,
  utillinuxMinimal ? null,
  xz,

  busybox-sandbox-shell,

  # internal fork of nix-doc providing :doc in the repl
  lix-doc ? __forDefaults.lix-doc,

  pname ? "nix",
  versionSuffix ? "",
  officialRelease ? true,
  # Set to true to build the release notes for the next release.
  buildUnreleasedNotes ? false,
  internalApiDocs ? false,
  # Avoid setting things that would interfere with a functioning devShell
  forDevShell ? false,

  # FIXME(Qyriad): build Lix using Meson instead of autoconf and make.
  # This flag will be removed when the migration to Meson is complete.
  buildWithMeson ? true,

  # Not a real argument, just the only way to approximate let-binding some
  # stuff for argument defaults.
  __forDefaults ? {
    canRunInstalled = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

    boehmgc-nix = (boehmgc.override { enableLargeConfig = true; }).overrideAttrs {
      patches = [
        # We do *not* include prev.patches (which doesn't exist in normal pkgs.boehmgc anyway)
        # because if the caller of this package passed a patched boehm as `boehmgc` instead of
        # `boehmgc-nix` then this will almost certainly have duplicate patches, which means
        # the patches won't apply and we'll get a build failure.
        ./boehmgc-coroutine-sp-fallback.diff
        # https://github.com/ivmai/bdwgc/pull/586
        ./boehmgc-traceable_allocator-public.diff
      ];
    };

    lix-doc = pkgs.callPackage ./lix-doc/package.nix { };

    # FIXME remove when we have libsecomp 2.5.5 (currently in staging-23.11)
    libseccomp-nix = libseccomp.overrideAttrs (_: rec {
      version = "2.5.5";
      src = fetchurl {
        url = "https://github.com/seccomp/libseccomp/releases/download/v${version}/libseccomp-${version}.tar.gz";
        hash = "sha256-JIosik2bmFiqa69ScSw0r+/PnJ6Ut23OAsHJqiX7M3U=";
      };
    });
  },
}:
let
  inherit (__forDefaults) canRunInstalled;
  inherit (lib) fileset;

  version = lib.fileContents ./.version + versionSuffix;

  aws-sdk-cpp-nix = aws-sdk-cpp.override {
    apis = [
      "s3"
      "transfer"
    ];
    customMemoryManagement = false;
  };

  testConfigureFlags = [ "RAPIDCHECK_HEADERS=${lib.getDev rapidcheck}/extras/gtest/include" ];

  # Reimplementation of Nixpkgs' Meson cross file, with some additions to make
  # it actually work.
  mesonCrossFile =
    let
      cpuFamily =
        platform:
        with platform;
        if isAarch32 then
          "arm"
        else if isx86_32 then
          "x86"
        else
          platform.uname.processor;
    in
    builtins.toFile "lix-cross-file.conf" ''
      [properties]
      # Meson is convinced that if !buildPlatform.canExecute hostPlatform then we cannot
      # build anything at all, which is not at all correct. If we can't execute the host
      # platform, we'll just disable tests and doc gen.
      needs_exe_wrapper = false

      [binaries]
      # Meson refuses to consider any CMake binary during cross compilation if it's
      # not explicitly specified here, in the cross file.
      # https://github.com/mesonbuild/meson/blob/0ed78cf6fa6d87c0738f67ae43525e661b50a8a2/mesonbuild/cmake/executor.py#L72
      cmake = 'cmake'
    '';

  # The internal API docs need these for the build, but if we're not building
  # Nix itself, then these don't need to be propagated.
  maybePropagatedInputs = [
    boehmgc-nix
    nlohmann_json
  ];

  # .gitignore has already been processed, so any changes in it are irrelevant
  # at this point. It is not represented verbatim for test purposes because
  # that would interfere with repo semantics.
  baseFiles = fileset.fileFilter (f: f.name != ".gitignore") ./.;

  configureFiles = fileset.unions [
    ./.version
    ./configure.ac
    ./m4
    # TODO: do we really need README.md? It doesn't seem used in the build.
    ./README.md
  ];

  topLevelBuildFiles = fileset.unions (
    [
      ./local.mk
      ./Makefile
      ./Makefile.config.in
      ./mk
    ]
    ++ lib.optionals buildWithMeson [
      ./meson.build
      ./meson.options
      ./meson
      ./scripts/meson.build
    ]
  );

  functionalTestFiles = fileset.unions [
    ./tests/functional
    ./tests/unit
    (fileset.fileFilter (f: lib.strings.hasPrefix "nix-profile" f.name) ./scripts)
  ];
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fileset.toSource {
    root = ./.;
    fileset = fileset.intersection baseFiles (
      fileset.unions (
        [
          configureFiles
          topLevelBuildFiles
          functionalTestFiles
        ]
        ++ lib.optionals (!finalAttrs.dontBuild || internalApiDocs) [
          ./boehmgc-coroutine-sp-fallback.diff
          ./doc
          ./misc
          ./precompiled-headers.h
          ./src
          ./COPYING
          ./scripts/local.mk
        ]
      )
    );
  };

  VERSION_SUFFIX = versionSuffix;

  outputs =
    [ "out" ]
    ++ lib.optionals (!finalAttrs.dontBuild) [
      "dev"
      "doc"
    ];

  dontBuild = false;

  # FIXME(Qyriad): see if this is still needed once the migration to Meson is completed.
  mesonFlags =
    lib.optionals (buildWithMeson && stdenv.hostPlatform.isLinux) [
      "-Dsandbox-shell=${lib.getBin busybox-sandbox-shell}/bin/busybox"
    ]
    ++ lib.optional stdenv.hostPlatform.isStatic "-Denable-embedded-sandbox-shell=true"
    ++ lib.optional (finalAttrs.dontBuild) "-Denable-build=false"
    ++ [
      # mesonConfigurePhase automatically passes -Dauto_features=enabled,
      # so we must explicitly enable or disable features that we are not passing
      # dependencies for.
      (lib.mesonEnable "internal-api-docs" internalApiDocs)
      (lib.mesonBool "enable-tests" finalAttrs.doCheck)
      (lib.mesonBool "enable-docs" canRunInstalled)
    ]
    ++ lib.optional (stdenv.hostPlatform != stdenv.buildPlatform) "--cross-file=${mesonCrossFile}";

  # We only include CMake so that Meson can locate toml11, which only ships CMake dependency metadata.
  dontUseCmakeConfigure = true;

  nativeBuildInputs =
    [
      bison
      flex
      python3
    ]
    ++ [
      (lib.getBin lowdown)
      mdbook
      mdbook-linkcheck
      autoconf-archive
    ]
    ++ lib.optional (!buildWithMeson) autoreconfHook
    ++ [
      pkg-config

      # Tests
      git
      mercurial
      jq
      lsof
    ]
    ++ lib.optional stdenv.hostPlatform.isLinux util-linuxMinimal
    ++ lib.optional (!officialRelease && buildUnreleasedNotes) build-release-notes
    ++ lib.optional (internalApiDocs || forDevShell) doxygen
    ++ lib.optionals buildWithMeson [
      meson
      ninja
      cmake
    ];

  buildInputs =
    [
      curl
      bzip2
      xz
      brotli
      editline
      openssl
      sqlite
      libarchive
      boost
      lowdown
      libsodium
      toml11
      lix-doc
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      libseccomp-nix
      busybox-sandbox-shell
    ]
    ++ lib.optional internalApiDocs rapidcheck
    ++ lib.optional stdenv.hostPlatform.isx86_64 libcpuid
    # There have been issues building these dependencies
    ++ lib.optional (stdenv.hostPlatform == stdenv.buildPlatform) aws-sdk-cpp-nix
    ++ lib.optionals (finalAttrs.dontBuild) maybePropagatedInputs;

  checkInputs = [
    gtest
    rapidcheck
  ];

  propagatedBuildInputs = lib.optionals (!finalAttrs.dontBuild) maybePropagatedInputs;

  disallowedReferences = [ boost ];

  # Needed for Meson to find Boost.
  # https://github.com/NixOS/nixpkgs/issues/86131.
  env = lib.optionalAttrs (buildWithMeson || forDevShell) {
    BOOST_INCLUDEDIR = "${lib.getDev boost}/include";
    BOOST_LIBRARYDIR = "${lib.getLib boost}/lib";
  };

  preConfigure =
    lib.optionalString (!finalAttrs.dontBuild && !stdenv.hostPlatform.isStatic) ''
      # Copy libboost_context so we don't get all of Boost in our closure.
      # https://github.com/NixOS/nixpkgs/issues/45462
      mkdir -p $out/lib
      cp -pd ${boost}/lib/{libboost_context*,libboost_thread*,libboost_system*} $out/lib
      rm -f $out/lib/*.a
    ''
    + lib.optionalString (!finalAttrs.dontBuild && stdenv.hostPlatform.isLinux) ''
      chmod u+w $out/lib/*.so.*
      patchelf --set-rpath $out/lib:${stdenv.cc.cc.lib}/lib $out/lib/libboost_thread.so.*
    ''
    + lib.optionalString (!finalAttrs.dontBuild && stdenv.hostPlatform.isDarwin) ''
      for LIB in $out/lib/*.dylib; do
        chmod u+w $LIB
        install_name_tool -id $LIB $LIB
        install_name_tool -delete_rpath ${boost}/lib/ $LIB || true
      done
      install_name_tool -change ${boost}/lib/libboost_system.dylib $out/lib/libboost_system.dylib $out/lib/libboost_thread.dylib
    ''
    + ''
      # Workaround https://github.com/NixOS/nixpkgs/issues/294890.
      if [[ -n "''${doCheck:-}" ]]; then
        appendToVar configureFlags "--enable-tests"
      else
        appendToVar configureFlags "--disable-tests"
      fi
    '';

  configureFlags =
    [ "--with-boost=${boost}/lib" ]
    ++ lib.optionals stdenv.isLinux [ "--with-sandbox-shell=${busybox-sandbox-shell}/bin/busybox" ]
    ++ lib.optionals (
      stdenv.isLinux && !(stdenv.hostPlatform.isStatic && stdenv.system == "aarch64-linux")
    ) [ "LDFLAGS=-fuse-ld=gold" ]
    ++ lib.optional stdenv.hostPlatform.isStatic "--enable-embedded-sandbox-shell"
    ++ lib.optionals (finalAttrs.doCheck || internalApiDocs) testConfigureFlags
    ++ lib.optional (!canRunInstalled) "--disable-doc-gen"
    ++ [ (lib.enableFeature internalApiDocs "internal-api-docs") ]
    ++ lib.optional (!forDevShell) "--sysconfdir=/etc"
    ++ [ "TOML11_HEADERS=${lib.getDev toml11}/include" ];

  mesonBuildType = lib.optional (buildWithMeson || forDevShell) "debugoptimized";

  installTargets = lib.optional internalApiDocs "internal-api-html";

  enableParallelBuilding = true;

  makeFlags = "profiledir=$(out)/etc/profile.d PRECOMPILE_HEADERS=1";

  doCheck = canRunInstalled;

  mesonCheckFlags = lib.optionals (buildWithMeson || forDevShell) [ "--suite=check" ];

  installFlags = "sysconfdir=$(out)/etc";

  # Make sure the internal API docs are already built, because mesonInstallPhase
  # won't let us build them there. They would normally be built in buildPhase,
  # but the internal API docs are conventionally built with doBuild = false.
  preInstall = lib.optional (buildWithMeson && internalApiDocs) ''
    meson ''${mesonBuildFlags:-} compile "$installTargets"
  '';

  postInstall =
    lib.optionalString (!finalAttrs.dontBuild) ''
      mkdir -p $doc/nix-support
      echo "doc manual $doc/share/doc/nix/manual" >> $doc/nix-support/hydra-build-products
    ''
    + lib.optionalString stdenv.hostPlatform.isStatic ''
      mkdir -p $out/nix-support
      echo "file binary-dist $out/bin/nix" >> $out/nix-support/hydra-build-products
    ''
    + lib.optionalString stdenv.isDarwin ''
      for lib in libnixutil.dylib libnixexpr.dylib; do
        install_name_tool \
          -change "${lib.getLib boost}/lib/libboost_context.dylib" \
          "$out/lib/libboost_context.dylib" \
          "$out/lib/$lib"
      done
    ''
    + lib.optionalString internalApiDocs ''
      mkdir -p $out/nix-support
      echo "doc internal-api-docs $out/share/doc/nix/internal-api/html" >> "$out/nix-support/hydra-build-products"
    '';

  doInstallCheck = finalAttrs.doCheck;
  installCheckFlags = "sysconfdir=$(out)/etc";
  installCheckTarget = "installcheck"; # work around buggy detection in stdenv

  mesonInstallCheckFlags = [ "--suite=installcheck" ];

  preInstallCheck = lib.optionalString stdenv.hostPlatform.isDarwin ''
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
  '';

  installCheckPhase = lib.optionalString buildWithMeson ''
    runHook preInstallCheck
    flagsArray=($mesonInstallCheckFlags "''${mesonInstallCheckFlagsArray[@]}")
    meson test --no-rebuild "''${flagsArray[@]}"
    runHook postInstallCheck
  '';

  separateDebugInfo = !stdenv.hostPlatform.isStatic && !finalAttrs.dontBuild;

  strictDeps = true;

  # strictoverflow is disabled because we trap on signed overflow instead
  hardeningDisable = [ "strictoverflow" ] ++ lib.optional stdenv.hostPlatform.isStatic "pie";

  meta.platforms = lib.platforms.unix;

  passthru.perl-bindings = pkgs.callPackage ./perl { inherit fileset stdenv buildWithMeson; };

  # Export the patched version of boehmgc & libseccomp.
  # flake.nix exports that into its overlay.
  passthru = {
    inherit (__forDefaults) boehmgc-nix libseccomp-nix;
  };
})
