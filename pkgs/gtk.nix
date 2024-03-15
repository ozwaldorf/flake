{ lib, stdenvNoCC, fetchFromGitHub, gtk3, colloid-gtk-theme, gnome-themes-extra
, gtk-engine-murrine, python3, sassc, nix-update-script, accents ? [ "blue" ]
, size ? "standard", tweaks ? [ ], variant ? "mocha" }:
let
  validAccents = [
    "blue"
    "flamingo"
    "green"
    "lavender"
    "maroon"
    "mauve"
    "peach"
    "pink"
    "red"
    "rosewater"
    "sapphire"
    "sky"
    "teal"
    "yellow"
  ];
  validSizes = [ "standard" "compact" ];
  validTweaks = [ "black" "rimless" "normal" "float" ];
  validVariants = [ "latte" "frappe" "macchiato" "mocha" ];

  pname = "catppuccin-gtk";

in lib.checkListOfEnum "${pname}: theme accent" validAccents accents
lib.checkListOfEnum "${pname}: color variant" validVariants [ variant ]
lib.checkListOfEnum "${pname}: size variant" validSizes [ size ]
lib.checkListOfEnum "${pname}: tweaks" validTweaks tweaks

stdenvNoCC.mkDerivation rec {
  inherit pname;
  version = "0.7.1";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "gtk";
    rev = "v${version}";
    hash = "sha256-V3JasiHaATbVDQJeJPeFq5sjbkQnSMbDRWsaRzGccXU=";
  };

  nativeBuildInputs = [ gtk3 sassc ];

  buildInputs =
    [ gnome-themes-extra (python3.withPackages (ps: [ ps.catppuccin ])) ];

  propagatedUserEnvPkgs = [ gtk-engine-murrine ];

  postUnpack = ''
    rm -rf source/colloid
    cp -r ${colloid-gtk-theme.src} source/colloid
    chmod -R +w source/colloid
  '';

  postPatch = ''
    patchShebangs --build colloid/install.sh
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    	runHook preInstall

      mkdir -p $out/share/themes
      export HOME=$(mktemp -d)

      python3 install.py ${variant} \
        ${
          lib.optionalString (accents != [ ]) "--accent "
          + builtins.toString accents
        } \
        ${lib.optionalString (size != [ ]) "--size " + size} \
        ${
          lib.optionalString (tweaks != [ ]) "--tweaks "
          + builtins.toString tweaks
        } \
        --dest $out/share/themes

    	export COLORS=( 
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
      for r in "''${COLORS[@]}"; do
        ARGS+=("-e s/$r/Ig")
      done
    	echo "''${ARGS[@]}"
      find $out/share/themes -type f -exec sed -i ''${ARGS[@]} {} +

      runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Carburetor for GTK";
    homepage = "https://github.com/ozwaldorf/carburetor";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ozwaldorf ];
  };
}
