{
  lib,
  fetchFromGitHub,
  stdenv,

  cmake,
  pkg-config,
  boost,
  httplib,
  curl,
  doctest,
  fmt,
  libzip,
  lua5_3,
  nlohmann_json,
  openssl,
  rapidjson,
  zlib,
  ...
}:
let
  # Use a newer version of sol2 that's compatible with C++20
  sol2-new = fetchFromGitHub {
    owner = "ThePhD";
    repo = "sol2";
    rev = "v3.3.1"; # Later version with better C++20 support
    hash = "sha256-7QHZRudxq3hdsfEAYKKJydc4rv6lyN6UIt/2Zmaejx8=";
  };
in

stdenv.mkDerivation rec {
  pname = "beammp-server";
  version = "3.9.0";

  src = fetchFromGitHub {
    owner = "BeamMP";
    repo = "BeamMP-Server";
    rev = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-wb4019KZ3A6B9z64jt7ojwW0Jvh/hx/11jmR1FFOZYg=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    boost
    httplib
    curl
    doctest
    fmt
    libzip
    lua5_3
    nlohmann_json
    openssl
    rapidjson
    zlib
    # sol2  # Don't use the nixpkgs version, we'll use our custom one
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    # Use system dependencies instead of vcpkg
    "-DVCPKG_MANIFEST_MODE=OFF"
    # Disable unit tests to avoid test-related build issues
    "-DBeamMP-Server_ENABLE_UNIT_TESTING=OFF"
    # Add custom sol2 include directory and disable specific warnings that are treated as errors
    # Also explicitly link zlib
    "-DCMAKE_CXX_FLAGS=-I${sol2-new}/include -Wno-error -Wno-error=ctor-dtor-privacy"
    "-DCMAKE_EXE_LINKER_FLAGS=-lz"
  ];

  # Disable treating warnings as errors to work around sol2/C++20 compatibility issues
  NIX_CFLAGS_COMPILE = "-Wno-error";

  # The project doesn't have an install target, so we install manually
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp BeamMP-Server $out/bin/
    runHook postInstall
  '';

  # The project uses vcpkg by default, but we want to use Nix dependencies
  # We need to patch the CMakeLists.txt to skip vcpkg initialization
  postPatch = ''
    # Comment out vcpkg include
    sed -i 's|include(cmake/Vcpkg.cmake)|# include(cmake/Vcpkg.cmake)|' CMakeLists.txt

    # Ensure Lua is found correctly
    substituteInPlace CMakeLists.txt \
      --replace 'find_package(Lua REQUIRED)' \
                'find_package(Lua 5.3 REQUIRED)'

    # Replace CURL CONFIG find with PkgConfig
    substituteInPlace CMakeLists.txt \
      --replace 'find_package(CURL CONFIG REQUIRED)' \
                'find_package(CURL REQUIRED)'

    # Suppress git check error (submodules already fetched by Nix)
    substituteInPlace cmake/Git.cmake \
      --replace 'message(SEND_ERROR' \
                'message(STATUS'

    # Use our custom sol2 version by overriding the find_package
    substituteInPlace CMakeLists.txt \
      --replace 'find_package(sol2 CONFIG REQUIRED)' \
                '# find_package(sol2 CONFIG REQUIRED) # Using custom sol2'

    # Remove -Werror flags that cause build failures with sol2 3.3.1
    substituteInPlace cmake/CompilerWarnings.cmake \
      --replace '-Werror=ctor-dtor-privacy' \
                '# -Werror=ctor-dtor-privacy' \
      --replace '-Werror=float-equal' \
                '# -Werror=float-equal'

    # Remove sol2 from libraries list (it's header-only, doesn't need linking)
    substituteInPlace CMakeLists.txt \
      --replace 'sol2' \
                '# sol2 # header-only'
  '';

  meta = with lib; {
    description = "Server for the multiplayer mod BeamMP for BeamNG.drive";
    homepage = "https://github.com/BeamMP/BeamMP-Server";
    license = licenses.agpl3Only;
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "BeamMP-Server";
  };
}
