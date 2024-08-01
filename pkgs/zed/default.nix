pkgs:
pkgs.zed-editor.override (old: {
  rustPlatform = old.rustPlatform // {
    buildRustPackage =
      args:
      old.rustPlatform.buildRustPackage (
        args
        // {
          patches = [ ./comments-highlight.patch ];
          cargoLock = {
            lockFile = ./Cargo.lock;
            outputHashes = args.cargoLock.outputHashes // {
              "tree-sitter-comment-0.1.0" = "sha256-19jxH6YK3Rn0fOGSiWen5/eNKPKUSXVsIYB/QAPEA1I=";
            };
          };
        }
      );
  };
})
