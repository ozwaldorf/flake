{ config, pkgs, ... }:
let
  # Qt6 will not take GLSL source at runtime: ShaderEffect wants a .qsb, which
  # is the shader pre baked for every backend the RHI might pick. Built here so
  # a shader edit is caught by the rebuild rather than silently falling back to
  # an unshaded window at runtime.
  #
  # The GLES targets are the ones that matter; without them the shader loads and
  # then fails to build a pipeline on this hardware.
  wallpaperShader =
    pkgs.runCommand "quickshell-wallpaper-shader"
      {
        nativeBuildInputs = [ pkgs.qt6.qtshadertools ];
      }
      ''
        mkdir -p "$out"
        qsb --glsl "300es,320es,150" \
          -o "$out/wallpaper.frag.qsb" \
          ${./quickshell/shaders/wallpaper.frag}
      '';
in
{
  # socat reads hyprcapture's recording status socket for the recorder tile,
  # curl and jq drive the wallpaper fetcher, lutgen bakes its color table
  home.packages = [
    pkgs.quickshell
    pkgs.socat
    pkgs.curl
    pkgs.jq
    pkgs.lutgen
  ];

  # symlinked out of the store so quickshell's live reload sees edits to the
  # working tree; a store copy would be read only and need a rebuild per change
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/nixos/home/graphical/quickshell";

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      # The compiled shader is a build product, so it is read from the store
      # rather than the config directory: that directory is a symlink to the
      # working tree, and home-manager will not install into a path that
      # resolves outside $HOME.
      Environment = [ "QUICKSHELL_SHADERS=${wallpaperShader}" ];
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
