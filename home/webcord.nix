{ pkgs, ... }: {
  # enable discord ipc server
  services.arrpc.enable = true;

  # install patched webcord
  home.packages = with pkgs; [ webcord ];
}
