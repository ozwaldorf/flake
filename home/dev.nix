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

    # libraries
    pkg-config
    stdenv
    zlib
    zstd
    openssl
    (openssl.dev.overrideAttrs
    {
      withCryptodev = true;
      withZlib = true;
      enableSSL2 = true;
      enableSSL3 = true;
      enableKTLS = true;
			static = true;
    })
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
    OPENSSL_NO_VENDOR = 1;
    OPENSSL_DIR = pkgs.openssl.dev;
  };
}
