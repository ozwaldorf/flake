{ niri, fetchpatch }:

niri.overrideAttrs (old: {
  # Layout invariant tests assert the upstream layout, which the patches below
  # change, so they are skipped.
  doCheck = false;
  patches = (old.patches or [ ]) ++ [
    # Software cursors tilt around their hotspot with smoothed horizontal velocity.
    # Hardware cursors stay unrotated.
    # Programmatic pointer warps glide the drawn cursor to its new position.
    (fetchpatch {
      name = "niri-cursor-physics.patch";
      url = "https://github.com/ozwaldorf/niri/commit/c780fbc719381250ec57ced8a4b53b6c96990703.patch";
      hash = "sha256-9h67S5yqERzwXomnhl90vFwpjTjjiatUAbvJq09CTDM=";
    })
    # Play named cursor transitions once, reversing the same asset on return.
    # Integrated from ozwaldorf/niri at 6d568693070f52744d12bf80f4d1440a8827ed76
    # to share the padded texture cache and rendering with cursor physics.
    ./patches/niri-cursor-transitions.patch
    # Regular blur samples the framebuffer, so it vanishes wherever a window is
    # drawn offscreen: opening, closing and while dragged. Keeps dragged
    # windows opaque so they render directly, and falls back to xray blur for
    # the offscreen renders.
    (fetchpatch {
      name = "niri-offscreen-blur.patch";
      url = "https://github.com/ozwaldorf/niri/commit/905f8cf759054ed04a328a975b1c9f30c8f7956b.patch";
      hash = "sha256-YuHhDD1PfbvyW/h59z/W1tCSkNIzSW7GSRxPu+Q1bRQ=";
    })
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
    # Space a layer reserves at the left or right edge shifts the working area
    # instead of narrowing it, so the shell's drawer slides the windows aside
    # without resizing them.
    ./patches/niri-shift-side-zones.patch
  ];
})
