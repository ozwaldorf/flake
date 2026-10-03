{ config, pkgs, ... }:
let
  # Foot's opacity, which the gtk windows are matched to. Fluent stacks a
  # pane's background over the window's, so each layer takes what two of them
  # need to reach it; menus are one layer and take it as is.
  menu = "0.8";
  layer = "0.55";
in
{
  imports = [ ./modules/pointer.nix ];

  home = {
    # Standalone gnome desktop apps
    packages = with pkgs; [
      pavucontrol # volume control
      wdisplays # display control
      gnome-system-monitor # resource monitor

      nautilus # file explorer
      file-roller # archive manager
      simple-scan # document scanner

      eog # photo viewer
      celluloid # video player
      evince # document viewer
      gnome-characters # character viewer
      gnome-font-viewer # font viewer
    ];

    pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
      x11.enable = true;
      gtk.enable = true;
    };
  };

  # Read through the settings portal by libadwaita, Firefox and Electron apps,
  # which otherwise default to light
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  gtk = {
    enable = true;
    # Translucent backgrounds made for a compositor blurring behind them, as
    # niri does for every window
    theme = {
      name = "Fluent-Dark";
      package =
        (pkgs.fluent-gtk-theme.override {
          colorVariants = [ "dark" ];
          tweaks = [ "blur" ];
        }).overrideAttrs
          (old: {
            # The dark palette moved onto carburetor's, keeping fluent's order
            # of lighter surfaces and darker views and titlebar, with its
            # accent, status and link colours. The prerendered png assets keep
            # fluent's own blue. Menus take their colour before the blur tweak
            # thins the surfaces, so they are set again from the thinned one,
            # and the blur opacity is raised to match foot.
            postPatch = old.postPatch + ''
              sed -i \
                -e 's/#333333/#161616/' \
                -e 's/#3C3C3C/#262626/' \
                -e 's/#2B2B2B/#121212/' \
                -e 's/#303030/#141414/' \
                -e "/variant == 'dark'/{s/#202020/#0B0B0B/; s/#2C2C2C/#161616/}" \
                -e 's/#3281EA/#4589ff/' \
                -e 's/#FDD633/#fddc69/' \
                -e 's/#F28B82/#fa4d56/' \
                -e 's/#81C995/#42be65/' \
                -e "s/^\(\$link: *\)\$blue-600;/\1if(\$variant == 'light', \$blue-600, #78a9ff);/" \
                -e 's/\$purple-200)/#d4bbff)/' \
                -e "s/\(blur_opacity: *if(\$variant == 'light', 0.85, \)0.5)/\1${layer})/" \
                -e '/^  \$surface: .*blur_opacity/a\  $menu: rgba($surface, ${menu});' \
                src/_sass/_colors.scss
            '';
            # A flat headerbar over the content takes only the window's
            # layer while the view under it adds its own, so the content pane
            # carries the one layer instead, as the sidebar does
            postInstall = (old.postInstall or "") + ''
              for css in $out/share/themes/*/gtk-4.0/gtk{,-dark}.css; do
                cat >> $css <<'EOF'
              .content-pane { background-color: rgba(18, 18, 18, ${layer}); }
              .content-pane .view { background-color: transparent; }
              EOF
              done
            '';
          });
    };
    # Keep the pre-26.05 default; gtk4 apps follow the same theme as gtk3
    gtk4.theme = config.gtk.theme;
    iconTheme = {
      name = "Fluent-dark";
      # every accented icon shares the one blue, swapped for carburetor's
      package = pkgs.fluent-icon-theme.overrideAttrs (old: {
        postPatch = old.postPatch + ''
          grep -rlZ '#198ee6' src links | xargs -0 sed -i 's/#198ee6/#4589ff/g'
        '';
      });
    };
  };

  # Qt does not read gtk-icon-theme-name, so tray and menu icon lookups need
  # the theme naming its own way
  home.sessionVariables.QT_ICON_THEME = config.gtk.iconTheme.name;
}
