{
  inputs,
  config,
  lib,
  pkgs,
  username,
  hostname,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # ../blocky.nix

    inputs.zoom-sync.nixosModules.default
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
      eval-cores = 0;
    };
    settings.trusted-users = [
      "root"
      "@wheel"
    ];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "dialout"
      "scanner"
      "lp"
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      firefox
      chromium
      expressvpn
      qmk
    ];
  };

  networking = {
    hostName = hostname;
    networkmanager = {
      enable = true;
      # dns = "none";
    };
    nameservers = [
      # "127.0.0.1"
      # "::1"
      "8.8.8.8"
      "9.9.9.9"
    ];
  };

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

  boot = rec {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    plymouth = {
      enable = true;
    };
    consoleLogLevel = 0;
    initrd.verbose = false;

    # kernel config
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_level=0"
      # "video=eDP-1:2650x1600@60"
    ];
    kernelPackages = pkgs.linuxPackages_6_12;
    extraModulePackages = [
      # patch sound driver with razer blade 16 fixup
      (pkgs.snd-hda-intel.override {
        inherit (kernelPackages) kernel;
        patches = [ ./snd-hda-intel-razer.patch ];
      })

      # Registers DDC/CI monitors as ordinary /sys/class/backlight devices, so
      # external displays are driven exactly like the internal panel rather
      # than needing a separate path through ddcutil.
      kernelPackages.ddcci-driver
    ];

    kernelModules = [
      # ddcci talks to monitors over the display's i2c bus, which is only
      # reachable once i2c-dev is up. ddcci alone is just the bus layer; the
      # backlight half is what registers the /sys/class/backlight entries.
      "i2c-dev"
      "ddcci"
      "ddcci-backlight"
    ];
  };

  # CPU and GPU stuff
  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  # enable keyboard management
  hardware.keyboard.qmk.enable = true;
  services.udev.packages = [ pkgs.via ];

  # Bind ddcci to every display i2c bus as it appears. The module cannot
  # auto-probe on 6.8 and later, so each bus has to be attached by hand, and
  # bus numbering is not stable across reboots or a GPU reset: match the
  # adapter by name instead of by number. Buses with nothing listening simply
  # fail to attach, which is why this can be blanket rather than targeted.
  services.udev.extraRules = ''
    SUBSYSTEM=="i2c-dev", ATTR{name}=="NVIDIA i2c adapter*", TAG+="ddcci", \
      RUN+="${pkgs.bash}/bin/sh -c 'echo ddcci 0x37 > /sys/bus/i2c/devices/%k/new_device'"
  '';

  # printer scanning services
  hardware.sane = {
    enable = true;
    extraBackends = [
      pkgs.sane-airscan
      pkgs.pantum-driver
    ];
  };
  environment.systemPackages = with pkgs; [
    sane-frontends
  ];

  # No blueman: it autostarts an applet whose only visible part is a tray icon,
  # and the shell's own tile drives BlueZ directly. The stack itself is here.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.desktopManager.xterm.enable = false;

  services.getty.autologinUser = username;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "uwsm start hyprland-uwsm.desktop";
        user = username;
      };
    };
  };
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

  # services.xserver.desktopManager.gnome.enable = true;
  # Manually enable some services gnome used to
  services.devmon.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.gnome.localsearch.enable = true;

  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [
          "hyprland"
          "gtk"
        ];
        # GTK portal handles file choosers well
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
      };
    };
  };

  services.printing.enable = true;
  services.printing.drivers = [ pkgs.pantum-driver ];

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber = {
      enable = true;
      extraConfig = {
        # for some reason, improves battery life
        "10-disable-camera" = {
          "wireplumber.profiles" = {
            main."monitor.libcamera" = "disabled";
          };
        };
        # Larger USB buffers + no suspend; fixes crackling on UA Volt 176
        "11-usb-audio-quantum" = {
          "monitor.alsa.rules" = [
            {
              matches = [ { "node.name" = "~alsa_output.usb-.*"; } ];
              actions.update-props = {
                "api.alsa.period-size" = 1024;
                "api.alsa.headroom" = 1024;
                "session.suspend-timeout-seconds" = 0;
              };
            }
          ];
        };
      };
    };
  };
  hardware.enableAllFirmware = true;

  services.expressvpn.enable = true;
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
  };
  services.sshd.enable = true;

  # services.dnscrypt-proxy2 = {
  #   enable = false;
  #   settings = {
  #     ipv6_servers = true;
  #     require_dnssec = true;
  #     sources.public-resolvers = {
  #       urls = [
  #         "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
  #         "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
  #       ];
  #       cache_file = "/var/lib/dnscrypt-proxy2/public-resolvers.md";
  #       minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
  #     };
  #     server_names = [
  #       "cloudflare"
  #       "cloudflare-ipv6"
  #       "google"
  #       "google-ipv6"
  #     ];
  #   };
  # };

  security.rtkit.enable = true;
  security.polkit.enable = true;
  security.pam.services.gdm.enableGnomeKeyring = true;

  systemd = {
    services = {
      dnscrypt-proxy2.serviceConfig = {
        StateDirectory = "dnscrypt-proxy";
      };
    };
    user.services = {
      polkit-gnome-authentication-agent-1 = {
        description = "polkit-gnome-authentication-agent-1";
        wantedBy = [ "graphical-session.target" ];
        wants = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };
      };
    };
  };

  services.zoom-sync = {
    enable = true;
    user = username;
  };

  # environment.etc = {
  #   "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
  #     bluez_monitor.properties = {
  #       ["bluez5.enable-sbc-xq"] = true,
  #       ["bluez5.enable-msbc"] = true,
  #       ["bluez5.enable-hw-volume"] = true,
  #       ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
  #     }
  #   '';
  # };

  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [ nerd-fonts.fira-code ];
  environment.pathsToLink = [ "/share/zsh" ];

  programs = {
    nix-ld.enable = true;
    steam.enable = true;

    # enable installing zsh at the system level to set the users default terminal. Everything else configuration wise is done in home manager.
    zsh = {
      enable = true;
      enableCompletion = false;
    };

    # Same for sway and hyprland, install to system to ensure wayland sessions are propagated correctly.
    sway = {
      enable = true;
      package = pkgs.swayfx;
      extraOptions = [ "--unsupported-gpu" ];
    };
    hyprland = {
      enable = true;
      withUWSM = true;
    };

    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      # SSH is handled by gnome-keyring's gcr-ssh-agent, unlocked by pam at
      # login. gpg-agent would hijack SSH_AUTH_SOCK and prompt via pinentry
      # on every use, which is unreachable over a remote session.
      enableSSHSupport = false;
      pinentryPackage = pkgs.pinentry-curses;
    };

    direnv = {
      enable = true;
      # re-use system shell
      direnvrcExtra = "export SHELL=$SHELL";
    };

    gnome-disks.enable = true; # disk manager

    # Add `open in wezterm` entry to nautilus
    nautilus-open-any-terminal = {
      enable = true;
      terminal = "foot";
    };
  };

  virtualisation.waydroid.enable = true;
  # waydroid.cfg is mutable state the module doesn't manage. [properties] is only
  # folded into waydroid_base.prop by `waydroid init`/`upgrade`, not on container
  # start, so write both. Density 200 keeps the display above android's 600dp
  # large-screen threshold, below which activities cannot be resized.
  systemd.services.waydroid-container.preStart =
    let
      props = {
        "persist.waydroid.multi_windows" = "true";
        "persist.waydroid.width" = "1600";
        "persist.waydroid.height" = "900";
        "ro.sf.lcd_density" = "200";
      };
    in
    ''
      cfg=/var/lib/waydroid/waydroid.cfg
      prop=/var/lib/waydroid/waydroid_base.prop
      [ -f "$cfg" ] || exit 0
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (k: v: ''
        ${pkgs.crudini}/bin/crudini --set "$cfg" properties ${k} ${v}
        if [ -f "$prop" ]; then
          ${pkgs.gnused}/bin/sed -i '/^${k}=/d' "$prop"
          echo '${k}=${v}' >> "$prop"
        fi
      '') props
    );
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "24.05"; # Did you read the comment?
}
