{ pkgs, ... }:
pkgs.xq.overrideAttrs (old: rec {
  version = "0-unstable-2024-05-23";
  src = pkgs.fetchFromGitHub {
    owner = "ozwaldorf";
    repo = "xq";
    rev = "bf3f07bf7d142a556604d56101f91b24681d782b";
    hash = "sha256-sCm9Ru0VI/c/RuLmWtK/aht1rwWUfbaFevaIzZVOH5c=";
  };
  cargoDeps = old.cargoDeps.overrideAttrs (_: {
    inherit src;
    outputHash = "sha256-kQ02XmdEtWFpXP0l4nJUHIB5cy9/Fqdcwz2IaMhnems=";
  });
})
