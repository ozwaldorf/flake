{ ... }:
{
  carburetor.themes.foot.enable = true;
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "Berkeley Mono:size=10";
        dpi-aware = "yes";
        term = "xterm-256color";
      };
      colors.alpha = "0.8";
      mouse.hide-when-typing = "no";
    };
  };
}