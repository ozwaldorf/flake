{
  src,
  callPackage,
  buildFHSEnv,
  asar,
}:
let
  claude-desktop = callPackage "${src}/pkgs/claude-desktop.nix" {
    patchy-cnb = callPackage "${src}/pkgs/patchy-cnb.nix" { };
    # nodePackages was removed from nixpkgs
    nodePackages = { inherit asar; };
  };
in
# FHS env so MCP servers can be launched through npx, uvx, or docker
buildFHSEnv {
  name = "claude-desktop";
  targetPkgs =
    pkgs: with pkgs; [
      docker
      glibc
      openssl
      nodejs
      uv
    ];
  runScript = "${claude-desktop}/bin/claude-desktop";
  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/icons
    cp ${claude-desktop}/share/applications/claude.desktop $out/share/applications/
    cp -r ${claude-desktop}/share/icons/* $out/share/icons/
  '';
  passthru.unwrapped = claude-desktop;
}
