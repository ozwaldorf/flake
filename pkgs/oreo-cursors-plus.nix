{
  oreo-cursors-plus,
  fetchFromGitHub,
  ruby,
  imagemagick,
  inkscape,
  xcursorgen,
}:

oreo-cursors-plus.overrideAttrs (old: {
  version = "0-unstable-2026-10-09";
  src = fetchFromGitHub {
    owner = "ozwaldorf";
    repo = "animated-oreo-cursors";
    rev = "b703a3e148a12fef31719630782b880a4fd5fb16";
    hash = "sha256-9A/1U+dgiTSZe07SDaquMzga+pkprVqOQKjIN6NdQkM=";
  };

  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
    (ruby.withPackages (ps: [
      ps.rexml
      ps.minitest
    ]))
    imagemagick
    inkscape
    xcursorgen
  ];

  postBuild = (old.postBuild or "") + ''
    export INKSCAPE_PROFILE_DIR="$TMPDIR/inkscape"
    ruby generator/transitions.rb \
      --base-theme dist/oreo_spark_black_bordered_cursors \
      --output build/animated_oreo_spark_black_bordered_cursors
    cp -P build/animated_oreo_spark_black_bordered_cursors/cursors/* \
      dist/oreo_spark_black_bordered_cursors/cursors/
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ruby tests/test_transitions.rb
    runHook postCheck
  '';

  meta = old.meta // {
    homepage = "https://github.com/ozwaldorf/animated-oreo-cursors";
  };
})
