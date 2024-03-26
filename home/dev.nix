{ pkgs, ... }: {
  home.packages = with pkgs; [
    # compilers
    rustup
    gcc
    deno
    nodejs
    sassc

    # tools
    gnumake
    fontconfig
    inotify-tools
    nix-tree

    # libraries
    pkg-config
    stdenv
    zlib
    zstd
    llvmPackages.libclang
    #llvmPackages.libcxxStdenv
    protobuf
    protobufc
    zlib
    zstd
  ];

  home.sessionVariables = {
    BINDGEN_EXTRA_CLANG_ARGS =
      "-isystem ${pkgs.llvmPackages.libclang.lib}/lib/clang/16/include";
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
  };
}
