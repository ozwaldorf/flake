{ pkgs, ... }:
let
  # Fluent's Kvantum theme, the Qt counterpart of the gtk theme. Its dark
  # variant shares the gtk palette's hex values, so it moves onto carburetor's
  # the same way: lighter menus and window, darker views and titlebar, with
  # its accent, status and link colours. The translucent window and menu
  # surfaces keep fluent's 0.8 opacity, which already matches the terminal.
  fluent-kvantum = pkgs.stdenvNoCC.mkDerivation {
    pname = "fluent-kvantum";
    version = "0-unstable-2025-11-10";

    src = pkgs.fetchFromGitHub {
      owner = "vinceliuice";
      repo = "Fluent-kde";
      rev = "44794f29c89de994b0179aebabd2f5776c90d236";
      hash = "sha256-Ejr2wDs3tr36YN2mWSd9ZKp5e6gH/whcuhauN/2Y15I=";
    };

    postPatch = ''
      sed -i \
        -e 's/#333333/#161616/gI' \
        -e 's/#3C3C3C/#262626/gI' \
        -e 's/#2B2B2B/#121212/gI' \
        -e 's/#303030/#141414/gI' \
        -e 's/#202020/#0B0B0B/gI' \
        -e 's/#2C2C2C/#161616/gI' \
        -e 's/#0078D4/#4589ff/gI' \
        -e 's/#F04A50/#fa4d56/gI' \
        -e 's/#B74AFF/#d4bbff/gI' \
        -e 's/#E040FB/#d4bbff/gI' \
        -e 's/#0057AE/#78a9ff/gI' \
        Kvantum/Fluent/FluentDark.{kvconfig,svg}
    '';

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/share/Kvantum
      cp -r Kvantum/Fluent $out/share/Kvantum/
    '';
  };
in
{
  qt = {
    enable = true;
    style.name = "kvantum";
    kvantum = {
      enable = true;
      themes = [ fluent-kvantum ];
      settings.General.theme = "FluentDark";
    };
  };
}
