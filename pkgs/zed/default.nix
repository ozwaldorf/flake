pkgs:

# Patch with todo comment highlighting
pkgs.zed-editor.overrideAttrs (old: {
  patches = old.patches ++ [ ./comments-highlight.patch ];
  postPatch = ''cp ${./Cargo.lock} Cargo.lock'';
  cargoDeps = pkgs.rustPlatform.importCargoLock {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "alacritty_terminal-0.24.1-dev" = "sha256-aVB1CNOLjNh6AtvdbomODNrk00Md8yz8QzldzvDo1LI=";
      "async-pipe-0.1.3" = "sha256-g120X88HGT8P6GNCrzpS5SutALx5H+45Sf4iSSxzctE=";
      "blade-graphics-0.4.0" = "sha256-c0KhzG/FCpAyiafGZTbxDMz1ktCTURNDxO3fkB16nUw=";
      "cosmic-text-0.11.2" = "sha256-TLPDnqixuW+aPAhiBhSvuZIa69vgV3xLcw32OlkdCcM=";
      "font-kit-0.11.0" = "sha256-+4zMzjFyMS60HfLMEXGfXqKn6P+pOngLA45udV09DM8=";
      "lsp-types-0.95.1" = "sha256-N4MKoU9j1p/Xeowki/+XiNQPwIcTm9DgmfM/Eieq4js=";
      "naga-0.20.0" = "sha256-07lLKQLfWYyOwWmvzFQ0vMeuC5pxmclz6Ub72ooSmwk=";
      "nvim-rs-0.6.0-pre" = "sha256-bdWWuCsBv01mnPA5e5zRpq48BgOqaqIcAu+b7y1NnM8=";
      "pathfinder_simd-0.5.3" = "sha256-94/qS5d0UKYXAdx+Lswj6clOTuuK2yxqWuhpYZ8x1nI=";
      "tree-sitter-0.20.100" = "sha256-xZDWAjNIhWC2n39H7jJdKDgyE/J6+MAVSa8dHtZ6CLE=";
      "tree-sitter-go-0.20.0" = "sha256-/mE21JSa3LWEiOgYPJcq0FYzTbBuNwp9JdZTZqmDIUU=";
      "tree-sitter-gowork-0.0.1" = "sha256-lM4L4Ap/c8uCr4xUw9+l/vaGb3FxxnuZI0+xKYFDPVg=";
      "tree-sitter-heex-0.0.1" = "sha256-6LREyZhdTDt3YHVRPDyqCaDXqcsPlHOoMFDb2B3+3xM=";
      "tree-sitter-jsdoc-0.20.0" = "sha256-fKscFhgZ/BQnYnE5EwurFZgiE//O0WagRIHVtDyes/Y=";
      "tree-sitter-markdown-0.0.1" = "sha256-F8VVd7yYa4nCrj/HEC13BTC7lkV3XSb2Z3BNi/VfSbs=";
      "tree-sitter-proto-0.0.2" = "sha256-W0diP2ByAXYrc7Mu/sbqST6lgVIyHeSBmH7/y/X3NhU=";
      "xim-0.4.0" = "sha256-vxu3tjkzGeoRUj7vyP0vDGI7fweX8Drgy9hwOUOEQIA=";
      "xkbcommon-0.7.0" = "sha256-2RjZWiAaz8apYTrZ82qqH4Gv20WyCtPT+ldOzm0GWMo=";

      "tree-sitter-comment-0.1.0" = "sha256-19jxH6YK3Rn0fOGSiWen5/eNKPKUSXVsIYB/QAPEA1I=";
    };
  };
})
