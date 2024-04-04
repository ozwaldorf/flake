{ pkgs, ... }:
let
  src = (pkgs.catppuccin-gtk.override { variant = "mocha"; }).out;
in
pkgs.stdenv.mkDerivation {
  inherit src;
  name = "carburetor-gtk";
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
      "#6c7086/#6f6f6f"
      "#585b70/#525252"
      "#45475a/#393939"
      "#313244/#262626"
      "#1e1e2e/#161616"
      "#181825/#0b0b0b"
      "#11111b/#000000"
    )
    ARGS=()
    for r in "''${MOCHA_COLORS[@]}"; do
      ARGS+=("-e s/$r/Ig")
    done
    find . -type f -exec sed -i ''${ARGS[@]} {} +
    mkdir -p $out
    cp -R share $out/
  '';
}
