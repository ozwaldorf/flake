{ pkgs, inputs, ... }:
{
  imports = [ inputs.carburetor.homeManagerModules.webcord ];

  # enable discord ipc server
  services.arrpc.enable = true;

  # install patched webcord
  home.packages = with pkgs; [ webcord ];

  # enable carburetor theme
  programs.webcord.carburetor.enable = true;
}
