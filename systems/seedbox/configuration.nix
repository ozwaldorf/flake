# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  inputs,
  config,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../blocky.nix
  ];
  disabledModules = [ "hardware/facter/system.nix" ];

  nix = {
    registry = {
      nixpkgs.flake = inputs.nixpkgs;
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      extra-substituters = [ "https://cache.garnix.io" ];
      extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
    };
    trustedUsers = [
      "root"
      "@wheel"
    ];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking.hostName = "seedbox";

  # networking.wireless.enable = true;
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.getty.autologinUser = "oz";

  users.users.oz = {
    isNormalUser = true;
    description = "oz";
    extraGroups = [
      "networkmanager"
      "wheel"
      "plex"
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [ ];
  };

  users.users.media = {
    isSystemUser = true;
    group = "media";
  };
  users.groups.media = { };

  environment.systemPackages = with pkgs; [
    vim
  ];

  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  programs = {
    zsh = {
      enable = true;
      enableCompletion = false;
    };
  };

  # remote access
  services.openssh.enable = true;

  # media server
  services.plex = {
    enable = true;
    openFirewall = true;
    user = "media";
    group = "media";
  };

  # torrent client
  services.rtorrent = {
    enable = true;
    user = "media";
    group = "media";
    configText = ''
      method.redirect=load.throw,load.normal
      method.redirect=load.start_throw,load.start
      method.insert=d.down.sequential,value|const,0
      method.insert=d.down.sequential.set,value|const,0
    '';
    openFirewall = true;
  };

  # torrent web ui
  services.flood = {
    enable = true;
    port = 8080;
    extraArgs = [ "--rtsocket=${config.services.rtorrent.rpcSocket}" ];
  };
  systemd.services.flood.serviceConfig = {
    User = "media";
    SupplementaryGroups = [ "media" ];
  };

  # proxy flood ui
  services.caddy = {
    enable = true;
    virtualHosts."http://seedbox".extraConfig = ''
      reverse_proxy localhost:8080
    '';
  };

  # beammp
  security.pki.certificateFiles = [
    (pkgs.stdenvNoCC.mkDerivation {
      name = "beammp-cert";
      nativeBuildInputs = [ pkgs.curl ];
      builder = (
        pkgs.writeScript "beammp-cert-builder" "curl -w %{certs} https://auth.beammp.com/userlogin -k > $out"
      );
      outputHash = "sha256-8qyV7wLQBcpNUKasJFRb5BuPD87Orbpy3E5KFeWAkr0=";
    })
  ];
  systemd.services.beammp = {
    enable = true;
    description = "BeamMP server";
    serviceConfig = {
      User = "oz";
      ExecStart = "${pkgs.beammp-server}/bin/BeamMP-Server --working-directory=/home/oz/beammp";
      Restart = "on-failure";
    };
    wantedBy = [ "multi-user.target" ];
  };

  networking.firewall.allowedTCPPorts = [
    53 # blocky
    4000 # blocky api
    80 # caddy
    30814 # beammp
  ];
  networking.nameservers = [ "127.0.0.1" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
