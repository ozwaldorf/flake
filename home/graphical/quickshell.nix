{
  config,
  lib,
  pkgs,
  ...
}:
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

  # The niri binds as the shortcut helper lists them: one entry per bind,
  # labelled by its overlay title or else its action, grouped by what the
  # action does. The twenty workspace binds are folded into two lines.
  keybinds =
    let
      binds = config.wayland.windowManager.niri.settings.binds;
      actionOf = bind: lib.head (lib.filter (n: !lib.hasPrefix "_" n) (lib.attrNames bind));
      humanize =
        s:
        let
          words = lib.replaceStrings [ "-" ] [ " " ] s;
        in
        lib.toUpper (lib.substring 0 1 words) + lib.substring 1 (-1) words;
      # Shell IPC is split from apps; a bare spawn here only ever runs one of
      # the compositor helper scripts, which act on windows.
      groupOf =
        bind:
        let
          action = actionOf bind;
        in
        if action == "spawn-sh" then
          (if lib.hasPrefix "qs " bind.spawn-sh then "Shell" else "Launch")
        else if action == "spawn" then
          "Windows"
        else if lib.hasPrefix "focus-" action then
          "Focus"
        else if lib.hasPrefix "move-" action then
          "Move"
        else if lib.hasPrefix "screenshot" action then
          "Capture"
        else if
          lib.elem action [
            "quit"
            "power-off-monitors"
          ]
        then
          "Session"
        else
          "Windows";
      isWorkspace = key: builtins.match "Mod\\+(Shift\\+)?[0-9]" key != null;
      entries = lib.mapAttrsToList (key: bind: {
        inherit key;
        label = bind._props.hotkey-overlay-title or (humanize (actionOf bind));
        group = groupOf bind;
      }) (lib.filterAttrs (key: _: !isWorkspace key) binds);
      groups = [
        "Launch"
        "Shell"
        "Windows"
        "Focus"
        "Move"
        "Capture"
        "Session"
      ];
    in
    pkgs.writeText "keybinds.json" (
      builtins.toJSON (
        lib.concatMap (g: lib.filter (e: e.group == g) entries) groups
        ++ [
          {
            key = "Mod+1-0";
            label = "Focus workspace";
            group = "Workspaces";
          }
          {
            key = "Mod+Shift+1-0";
            label = "Move window to workspace";
            group = "Workspaces";
          }
        ]
      )
    );
in
{
  # curl and jq drive the wallpaper fetcher, lutgen bakes its color table,
  # slurp picks the recorder's region
  home.packages = [
    pkgs.quickshell
    pkgs.curl
    pkgs.jq
    pkgs.lutgen
    pkgs.slurp
  ];

  # symlinked out of the store so quickshell's live reload sees edits to the
  # working tree; a store copy would be read only and need a rebuild per change
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/nixos/home/graphical/quickshell";

  # the clipboard drawer's history
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

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
      Environment = [
        "QUICKSHELL_SHADERS=${wallpaperShader}"
        "QUICKSHELL_KEYBINDS=${keybinds}"
      ];
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
