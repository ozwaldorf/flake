{ pkgs }:
pkgs.callPackage (
  {
    stdenv,
    lib,
    aalib,
    alsa-lib,
    appstream,
    appstream-glib,
    babl,
    bashInteractive,
    cairo,
    desktop-file-utils,
    fetchurl,
    findutils,
    gdk-pixbuf,
    gegl,
    gexiv2,
    ghostscript,
    gi-docgen,
    gjs,
    glib,
    glib-networking,
    gobject-introspection,
    gtk3,
    isocodes,
    lcms,
    libarchive,
    libgudev,
    libheif,
    libjxl,
    libmng,
    libmypaint,
    librsvg,
    libwebp,
    libwmf,
    libxslt,
    luajit,
    meson,
    qoi,
    cfitsio,
    mypaint-brushes1,
    ninja,
    openexr,
    perl538,
    pkg-config,
    poppler,
    poppler_data,
    python3,
    shared-mime-info,
    vala,
    wrapGAppsHook,
    xorg,
    xvfb-run,

  }:
  let
    python = python3.withPackages (pp: [ pp.pygobject3 ]);
    lua = luajit.withPackages (ps: [ ps.lgi ]);
  in
  stdenv.mkDerivation (finalAttrs: {
    pname = "gimp";
    version = "2.99.18";

    outputs = [
      "out"
      "dev"
    ];

    src = fetchurl {
      url = "http://download.gimp.org/pub/gimp/v${lib.versions.majorMinor finalAttrs.version}/gimp-${finalAttrs.version}.tar.xz";
      hash = "sha256-jBu3qUrA1NDN5NcB2LNWOHwuzYervTW799Ii1A9t224=";
    };

    patches = [
      ./meson-gtls.diff
      ./pygimp-interp.diff
    ];

    nativeBuildInputs = [
      pkg-config
      libxslt
      ghostscript
      libarchive
      bashInteractive
      libheif
      libwebp
      libmng
      aalib
      libjxl
      isocodes
      perl538
      appstream
      meson
      xvfb-run
      gi-docgen
      findutils
      vala
      alsa-lib
      ninja
      wrapGAppsHook
    ];

    buildInputs = [
      gjs
      lua
      qoi
      babl
      appstream-glib
      gegl
      gtk3
      glib
      gdk-pixbuf
      cairo
      gexiv2
      lcms
      libjxl
      cfitsio
      poppler
      poppler_data
      openexr
      libmng
      librsvg
      desktop-file-utils
      libwmf
      ghostscript
      aalib
      shared-mime-info
      libwebp
      libheif
      xorg.libXpm
      xorg.libXmu
      glib-networking
      libmypaint
      mypaint-brushes1
      gobject-introspection
      python
      libgudev
    ];

    preConfigure = "patchShebangs tools/gimp-mkenums app/tests/create_test_env.sh plug-ins/script-fu/scripts/ts-helloworld.scm";

    mesonFlags = [ "-Dilbm=disabled" ];

    enableParallelBuilding = true;

    doCheck = false;

    meta = with lib; {
      description = "The GNU Image Manipulation Program: Development Edition";
      homepage = "https://www.gimp.org/";
      license = licenses.gpl3Plus;
      platforms = platforms.unix;
      mainProgram = "gimp";
    };
  })
) { }
