pkgs:

# Use my fork with toml and QoL features
pkgs.xq.overrideAttrs (old: rec {
  version = "0-unstable-2024-10-22";
  src = pkgs.fetchFromGitHub {
    owner = "ozwaldorf";
    repo = "xq";
    rev = "266ff0a80f1d5dd1a8f03c3cb70e84984d9a8664";
    hash = "sha256-iUxb0j6eZ/WdiwOCVS4sn4VXQrwJDQVzFjaxqPza+10=";
  };
  cargoDeps = old.cargoDeps.overrideAttrs (_: {
    inherit src;
    outputHash = "sha256-eHJDtr3sy3WQUYaVEkrssVtEOGZCAX9/VwxP16RtglU=";
  });
})
