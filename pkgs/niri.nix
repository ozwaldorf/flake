{ niri }:

niri.overrideAttrs (old: {
  # Layout invariant tests assert the upstream layout, which the patches below
  # change, so they are skipped.
  doCheck = false;
  patches = (old.patches or [ ]) ++ [
    # Regular blur samples the framebuffer, so it vanishes wherever a window is
    # drawn offscreen: opening, closing and while dragged. Keeps dragged
    # windows opaque so they render directly, and falls back to xray blur for
    # the offscreen renders.
    ./patches/niri-offscreen-blur.patch
    # Extends always-center-single-column to center any set of columns that
    # fits on screen together.
    ./patches/niri-center-fitting-columns.patch
    # A column's lone window, when shorter than the column, is centered in it
    # rather than held to its top.
    ./patches/niri-center-lone-window.patch
    # A working area change keeps the focused column against the edge it was
    # against, and a view that keeps it in sight still snaps to a column edge
    # rather than resting between them.
    ./patches/niri-snap-view.patch
    # The first tiled window on an empty workspace opens at 2/3 width instead
    # of the default column width.
    ./patches/niri-wide-first-column.patch
  ];
})
