# The palette as a pleamar library: every scene imports it, so the window
# manager and the shell are drawn from the same colours.
{ lib, palette }:
''
  library Theme {
  ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: hex: "    let ${name} = #${hex}") palette)}
  }
''
