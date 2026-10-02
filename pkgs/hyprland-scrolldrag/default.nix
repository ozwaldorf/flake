{ lib, hyprlandPlugins }:
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "hyprland-scrolldrag";
  version = "0.1.0";
  src = ./.;

  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    $CXX -shared -fPIC --no-gnu-unique -std=c++2b -O2 \
      $(pkg-config --cflags hyprland pixman-1 libdrm) \
      $src/main.cpp -o libhyprland-scrolldrag.so
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 libhyprland-scrolldrag.so -t $out/lib
    runHook postInstall
  '';

  meta = {
    description = "Drag the Hyprland scrolling layout with the pointer";
    license = lib.licenses.mit;
  };
}
