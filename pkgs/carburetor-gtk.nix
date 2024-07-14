{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "carburetor-gtk";
  src =
    (pkgs.catppuccin-gtk.override {
      variant = "mocha";
      accents = [ "blue" ];
    }).out;
  nativeBuildInputs = [ ];
  installPhase = ''
    export MOCHA_COLORS=(
      "#f5e0dc/#ffd7d9"
      "#f2cdcd/#ffb3b8"
      "#f5c2e7/#ff7eb6"
      "#cba6f7/#d4bbff"
      "#f38ba8/#fa4d56"
      "#eba0ac/#ff8389"
      "#fab387/#ff832b"
      "#f9e2af/#fddc69"
      "#a6e3a1/#42be65"
      "#94e2d5/#3ddbd9"
      "#89dceb/#82cfff"
      "#74c7ec/#78a9ff"
      "#89b4fa/#4589ff"
      "#b4befe/#be95ff"
      "#cdd6f4/#f4f4f4"
      "#bac2de/#e0e0e0"
      "#a6adc8/#c6c6c6"
      "#9399b2/#a8a8a8"
      "#7f849c/#8d8d8d"
      "#6c7086/rgba(111,111,111,0.8)"
      "#585b70/rgba(82,82,82,0.8)"
      "#45475a/rgba(57,57,57,0.8)"
      "#313244/rgba(38,38,38,0.8)"
      "#1e1e2e/rgba(22,22,22,0.8)"
      "#181825/rgba(11,11,11,0.8)"
      "#11111b/rgba(0,0,0,0.8)"
    )
    ARGS=()
    for r in "''${MOCHA_COLORS[@]}"; do
      ARGS+=("-e s/$r/Ig")
    done
    ls share/themes
    find . -type f -exec sed -i ''${ARGS[@]} {} +
    mkdir -p $out/share/themes
    cp -R share/themes/catppuccin-mocha-*-standard $out/share/themes/carburetor
    cp -R share/themes/catppuccin-mocha-*-standard-hdpi $out/share/themes/carburetor-hdpi
    cp -R share/themes/catppuccin-mocha-*-standard-xhdpi $out/share/themes/carburetor-xhdpi
  '';
}
