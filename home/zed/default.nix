{
  pkgs,
  config,
  flakeDirectory,
  ...
}:
{
  home.packages = with pkgs; [
    zed-editor
    nixd
  ];

  carburetor.themes.zed.enable = true;

  xdg.configFile."zed/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink flakeDirectory + "/home/zed/settings.json";
}
