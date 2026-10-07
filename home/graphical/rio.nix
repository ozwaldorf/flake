{ lib, inputs, ... }:
let
  palette = (lib.importJSON "${inputs.carburetor}/whiskers.json").mocha;
  color = name: "#${palette.${name}}";
  opacity = 0.8;
  # Rio's vulkan renderer clears with the straight background colour while the
  # compositor reads it as premultiplied, so it is premultiplied here
  premultiplied =
    name:
    let
      channel =
        i:
        lib.fixedWidthString 2 "0" (
          lib.toHexString (
            builtins.floor (lib.fromHexString (builtins.substring i 2 palette.${name}) * opacity + 0.5)
          )
        );
    in
    "#${channel 0}${channel 2}${channel 4}";
in
{
  programs.rio = {
    enable = true;
    settings = {
      confirm-before-quit = false;
      # Plain drops the tab bar and its keybindings, splits are their own switch
      navigation = {
        mode = "Plain";
        use-split = false;
      };
      # niri's window rule blurs behind every translucent window
      window = {
        inherit opacity;
        decorations = "Disabled";
      };
      # Rio's own new window shares the process, and closing one segfaults
      # the vulkan renderer on nvidia and takes every window down with it.
      # Run detaches the child and starts it in the foreground process's cwd.
      bindings.keys = [
        {
          key = "n";
          "with" = "control | shift";
          action = "Run(rio)";
        }
      ];
      # Remote hosts rarely carry rio's terminfo
      env-vars = [ "TERM=xterm-256color" ];

      # Scaled by the output scale rather than physical dpi; matched by eye
      # against foot's 9pt on the 1.5 scale laptop panel
      fonts = {
        family = "Berkeley Mono";
        size = 15;
      };
      # foot's cell is taller than Rio's for the same font
      line-height = 1.075;
      margin = [ 14 ];
      cursor = {
        shape = "beam";
        blinking = true;
      };

      # carburetor, as its foot theme maps it
      colors = {
        background = premultiplied "base";
        foreground = color "text";
        cursor = color "rosewater";
        vi-cursor = color "rosewater";
        selection-background = "#424242";
        selection-foreground = color "text";
        search-match-background = color "surface0";
        search-match-foreground = color "text";
        search-focused-match-background = color "peach";
        search-focused-match-foreground = color "crust";

        black = color "surface1";
        red = color "red";
        green = color "green";
        yellow = color "yellow";
        blue = color "blue";
        magenta = color "pink";
        cyan = color "teal";
        white = color "subtext1";

        light-black = color "surface2";
        light-red = color "red";
        light-green = color "green";
        light-yellow = color "yellow";
        light-blue = color "blue";
        light-magenta = color "pink";
        light-cyan = color "teal";
        light-white = color "subtext0";
      };
    };
  };
}
