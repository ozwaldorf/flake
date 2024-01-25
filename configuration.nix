{ config, pkgs, inputs, ... }:

{
  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "onix";
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

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    plymouth = { enable = true; };
    kernelPackages = pkgs.linuxPackages_6_7;
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [ "quiet" "splash" "udev.log_level=0" ];
  };

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.displayManager.gdm = {
    enable = true;
    wayland = true;
  };
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  security.polkit.enable = true;
  services.printing.enable = true;
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.oz = {
    isNormalUser = true;
    description = "Ossian Mapes";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    packages = with pkgs; [ firefox ];
  };

  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs;
    [ (nerdfonts.override { fonts = [ "FiraCode" ]; }) ];

  environment.systemPackages = with pkgs; [
    inputs.ags.packages."${pkgs.system}".default
    (sway-contrib.grimshot.overrideAttrs (_: {
      src = fetchFromGitHub {
        owner = "OctopusET";
        repo = "sway-contrib";
        rev = "b7825b218e677c65f6849be061b93bd5654991bf";
        hash = "sha256-ZTfItJ77mrNSzXFVcj7OV/6zYBElBj+1LcLLHxBFypk=";
      };
    }))
    swww

    gtk3
    (pkgs.callPackage ./pkgs/gtk.nix { })
		papirus-icon-theme

    webcord
    gnome.eog
		pavucontrol

    wezterm
    zsh
    zsh-autosuggestions
    zsh-autocomplete
    zsh-syntax-highlighting
    curl
    tree
    eza
    starship
    onefetch

    wl-clipboard
    wf-recorder
    brightnessctl
    playerctl

    neovim
    rustup
    git
    gnumake
    gcc
    nodejs
    sassc
    delta

    stdenv
    zlib
    zstd
  ];

  fonts.fontconfig.enable = true;

  programs.sway = {
    enable = true;
    package = pkgs.sway.override {
      sway-unwrapped = inputs.swayfx.packages.${pkgs.system}.default;
      extraOptions = [ "--unsupported-gpu" ];
    };
  };
  programs.hyprland.enable = true;
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
  };
	programs.direnv = {
		enable = true;
		direnvrcExtra = "export SHELL=$SHELL";
	};

  programs.starship.enable = true;
  programs.starship.settings = {
    format =
      "$directory$all$cmd_duration$jobs$status$shell$line_break$env_var$username$sudo$character";
    right_format = "$battery$time";
    add_newline = true;
    character = {
      format = "$symbol ";
      success_symbol = "[●](bright-green)";
      error_symbol = "[●](red)";
      vicmd_symbol = "[◆](blue)";

    };
    sudo = {
      format = "[$symbol]($style)";
      style = "bright-purple";
      symbol = ":";
      disabled = false;
    };
    username = {
      style_user = "yellow bold";
      style_root = "purple bold";
      format = "[$user]($style) ▻ ";
      disabled = false;
      show_always = false;
    };
    directory = {
      home_symbol = "⌂";
      truncation_length = 2;
      truncation_symbol = "□ ";
      read_only = " △";
      use_os_path_sep = true;
      style = "bright-blue";
    };
    git_branch = {
      format = "[$symbol $branch(:$remote_branch)]($style) ";
      symbol = "[△](green)";
      style = "green";
    };
    git_status = {
      format =
        "($ahead_behind$staged$renamed$modified$untracked$deleted$conflicted$stashed)";
      conflicted = "[◪ ]( bright-magenta)";
      ahead = "[▲ [$count](bold white) ](green)";
      behind = "[▼ [$count](bold white) ](red)";
      diverged =
        "[◇ [$ahead_count](bold green)/[$behind_count](bold red) ](bright-magenta)";
      untracked = "[○ ](bright-yellow)";
      stashed = "[$count ](bold white)";
      renamed = "[● ](bright-blue)";
      modified = "[● ](yellow)";
      staged = "[● ](bright-cyan)";
      deleted = "[✕ ](red)";
    };
    deno = {
      format = "deno [∫ $version](blue ) ";
      version_format = "$major.$minor";
    };
    nodejs = {
      format = "node [◫ ($version)]( bright-green) ";
      detect_files = [ "package.json" ];
      version_format = "$major.$minor";
    };
    rust = {
      format = "rs [$symbol$version]($style) ";
      symbol = "⊃ ";
      version_format = "$major.$minor";
      style = "red";
    };
    package = {
      format = "pkg [$symbol$version]($style) ";
      version_format = "$major.$minor";
      symbol = "◫ ";
      style = "bright-yellow ";
    };
    nix_shell = {
      symbol = "⊛ ";
      format = "nix [$symbol$state $name]($style) ";
    };
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.variables.NIXOS_OZONE_WL = "1";
  environment.variables.EDITOR = "nvim";
  environment.variables.GTK_THEME = "Catppuccin-Mocha-Standard-Blue-Dark";

  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.registry = {
    nixpkgs.to = {
      type = "path";
      path = pkgs.path;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
