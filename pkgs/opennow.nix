{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  cargo,
  rustc,
  llvmPackages,
  cmake,
  ninja,
  pkg-config,
  nasm,
  makeWrapper,
  qt6,
  sdl3,
  SDL2,
  ffmpeg,
  libva,
  libdrm,
  udev,
  vulkan-loader,
  vulkan-headers,
  openssl,
  zlib,
  alsa-lib,
  libpulseaudio,
  libopus,
  openh264,
  dbus,
  libsecret,
  wayland,
  wayland-protocols,
  libxkbcommon,
  libX11,
  libXcursor,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libxrender,
  libxscrnsaver,
  ...
}:
let
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "OpenCloudGaming";
    repo = "OpenNOW";
    rev = "f7c3ecbd730c56bec9736d43892b2c1016e510e4";
    hash = "sha256-uo+SmDwRNBNN20ZL/BmnxZQTCoKEHdnyuEf7cAUTWzA=";
  };

  # The two Rust trees are independent workspaces with their own lockfiles, so
  # each needs its own vendor directory.
  coreVendor = rustPlatform.fetchCargoVendor {
    inherit src;
    sourceRoot = "source/native/opennow-core";
    hash = "sha256-QWyE1PnzIoeF8NvHBP6V1N+b5G/wEbm20OpGLaPQb4s=";
  };

  streamerVendor = rustPlatform.fetchCargoVendor {
    inherit src;
    sourceRoot = "source/native/opennow-streamer";
    hash = "sha256-iVq+2xo0ojvITh61UHr4ts57a8Dko7DaxzB8N8J/MF8=";
  };

in
stdenv.mkDerivation {
  pname = "opennow";
  inherit version src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    nasm
    makeWrapper
    cargo
    rustc
    qt6.wrapQtAppsHook
    qt6.qtshadertools
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtsvg
    sdl3
    SDL2
    ffmpeg
    libva
    libdrm
    udev
    vulkan-loader
    vulkan-headers
    openssl
    zlib
    alsa-lib
    libpulseaudio
    libopus
    openh264
    dbus
    libsecret
    wayland
    wayland-protocols
    libxkbcommon
    libX11
    libXcursor
    libXext
    libXfixes
    libXi
    libXrandr
    libxrender
    libxscrnsaver
  ];

  # cmake/NativeRuntime.cmake drives cargo itself, so the vendored registries
  # have to be in place before CMake configures rather than through the usual
  # cargoSetupHook.
  postPatch = ''
        installVendorConfig() {
          mkdir -p "$1/.cargo"
          substitute "$2/.cargo/config.toml" "$1/.cargo/config.toml" \
            --subst-var-by vendor "$2"
        }
        installVendorConfig native/opennow-core ${coreVendor}
        installVendorConfig native/opennow-streamer ${streamerVendor}

        # opennow-license-notices regenerates the notices file that upstream already
        # ships by running cargo metadata over both workspaces from the repository
        # root, where no single vendored registry can satisfy them. Copy the
        # checked-in file instead of rebuilding it.
        sed -i \
          '/^add_custom_target(opennow-license-notices ALL$/,/^)$/c\
    add_custom_target(opennow-license-notices ALL\
        COMMAND "''${CMAKE_COMMAND}" -E copy_if_different\
                "''${CMAKE_CURRENT_SOURCE_DIR}/../THIRD_PARTY_NOTICES"\
                "''${OPENNOW_GENERATED_NOTICES}"\
        BYPRODUCTS "''${OPENNOW_GENERATED_NOTICES}"\
        VERBATIM\
    )' opennow-qt/cmake/NativeRuntime.cmake

        # ffmpeg 8.1 types AVVkFrame.access as a signed int; the field is a Vulkan
        # access bitmask, so reinterpret rather than sign-extend it.
        substituteInPlace \
          native/opennow-streamer/crates/opennow-streamer-platform-linux/src/video/ffmpeg.rs \
          --replace-fail "access: unsafe { (*vulkan_frame).access[index] }," \
                         "access: unsafe { (*vulkan_frame).access[index] } as u32 as u64,"

        # ffmpeg-sys-next's build-portable feature git-clones FFmpeg during the
        # build, which the sandbox forbids. Link the nixpkgs ffmpeg through
        # FFMPEG_DIR instead and drop the source-build features.
        substituteInPlace opennow-qt/cmake/NativeRuntime.cmake \
          --replace-fail "--features linux-ffmpeg-bundled,linux-vaapi" \
                         "--features linux-ffmpeg,linux-vaapi"
  '';

  cmakeDir = "../opennow-qt";

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
    (lib.cmakeFeature "OPENNOW_BUILD_VERSION" version)
  ];

  env = {
    FFMPEG_DIR = "${lib.getDev ffmpeg}";
    # sdl2-sys, ffmpeg-sys-next and mtu run bindgen, which dlopens libclang and
    # otherwise resolves neither the clang builtins nor the libc headers.
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = toString [
      "-I${llvmPackages.libclang.lib}/lib/clang/${lib.versions.major llvmPackages.libclang.version}/include"
      "-I${lib.getDev stdenv.cc.libc}/include"
    ];
    # sdl2-sys would otherwise compile its bundled SDL2 copy.
    SDL2_NO_BUNDLED = "1";
    # Vendored builds are offline; cargo must not reach the network.
    CARGO_NET_OFFLINE = "true";
  };

  # CMake installs the streamer library into bin/ with install(PROGRAMS), so it
  # lands executable and wrapQtAppsHook would wrap it as if it were an app.
  # Move it to lib/ before wrapping and drop the $ORIGIN rpath the fixup strips.
  preFixup = ''
    mkdir -p $out/lib
    mv $out/bin/libopennow_streamer_ffi.so $out/lib/
    chmod 0644 $out/lib/libopennow_streamer_ffi.so
  '';

  qtWrapperArgs = [
    "--prefix LD_LIBRARY_PATH : ${placeholder "out"}/lib:${lib.makeLibraryPath [ vulkan-loader ]}"
  ];

  meta = {
    description = "Open source desktop client for GeForce NOW";
    homepage = "https://github.com/OpenCloudGaming/OpenNOW";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "opennow-qt";
  };
}
