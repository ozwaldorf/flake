# The scrolling layout's bookkeeping, unrolled over every window slot. The
# scene language has no loops that accumulate, so the sums over the other
# slots (column index, offset along the strip, rows within a column) are
# written out here.
#
# The order of the strip is the scene's own: each window has a column
# position and a row position, and windows on one workspace sharing a column
# position are one column. Rearranging is reassigning those numbers, so a
# column moves whole whatever its size, and the compositor's own order of
# windows is never consulted.
{
  lib,
  slots ? 16,
  monitors ? 4,
}:
let
  inherit (lib) concatMapStringsSep range;
  S = toString;
  all = range 0 (slots - 1);
  mons = range 0 (monitors - 1);
  pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);

  sum = f: "(" + concatMapStringsSep " + " f all + ")";
  sumOthers = i: f: "(" + concatMapStringsSep " + " f (lib.remove i all) + ")";
  pick = idx: field: "pick(${idx}, ${concatMapStringsSep ", " (j: field (S j)) all})";
  maxOf = js: f: lib.foldl' (acc: j: "max(${acc}, ${f j})") (f (lib.head js)) (lib.tail js);

  # Slot j is tiled on the same monitor and workspace as slot i.
  same =
    i: j:
    if i == j then
      "(win.${S i}.place >= 0)"
    else
      "(win.${S j}.place >= 0 and win.${S j}.screen == win.${S i}.screen and win.${S j}.pool == win.${S i}.pool)";
  # ...as the focused window.
  sf = j: "(win.${S j}.place >= 0 and win.${S j}.screen == f.sc and win.${S j}.pool == f.pool)";
  # Shown and tiled on monitor s.
  shownOn =
    s: j:
    "(win.${S j}.place >= 0 and win.${S j}.screen == ${S s} and win.${S j}.pool == win.pool.${S s})";
  # Slot j comes before slot i within their column.
  above =
    i: j: "(rpos.${S j} < rpos.${S i}${lib.optionalString (j < i) " or rpos.${S j} == rpos.${S i}"})";

  perSlot = f: concatMapStringsSep "\n" f all;

  # The slot at row r of column c on the focused workspace, -1 if none.
  at =
    c: r:
    "(" + sum (j: "${sf j} * (c.col.${S j} == ${c}) * (c.row.${S j} == ${r}) * ${S (j + 1)}") + " - 1)";
  # The column's shown window: the one with the keyboard most recently.
  act =
    c:
    "(" + sum (j: "${sf j} * (c.col.${S j} == ${c}) * (c.beat.${S j} < 0.5) * ${S (j + 1)}") + " - 1)";
  # A column's position, by its index on the focused workspace.
  cposOf = c: sum (j: "${sf j} * c.head.${S j} * (c.col.${S j} == ${c}) * cpos.${S j}");
  # The highest row position in a column, by its position.
  rmaxOf = cp: "(" + maxOf all (j: "${sf j} * (cpos.${S j} == ${cp}) * (rpos.${S j} + 1)") + " - 1)";
in
''
  part Columns {
      // per slot: where on the strip, and how wide
      // cpos, rpos: its column's position on the strip and its own within the
      // column (gaps allowed, only the order counts). wp: a head's width, as
      // a share of the working area. tb: a head's column is tabbed. stamp:
      // when it last had the keyboard, so a column knows what to show.
  ${perSlot (i: ''
    fact cpos.${S i} = 0
    fact rpos.${S i} = 0
    fact wp.${S i} = 0.5
    fact tb.${S i} = 0
    fact stamp.${S i} = 0'')}
      fact stamp.top = 0

      // springs shared across slots and monitors
  ${perSlot (i: ''
    prop x.${S i} = 0 ~niri
    prop y.${S i} = 0 ~niri
    prop w.${S i} = 100 ~niri
    prop h.${S i} = 100 ~niri'')}
      // How far each monitor's strip has glided, and which workspace it shows.
  ${concatMapStringsSep "\n" (
    s:
    let
      n = S s;
    in
    ''
      fact sco.${n} = 0
      prop vx.${n} = 0 ~niri
      prop wsv.${n} = 1 ~slide''
  ) mons}

      // A column's head is its first window; it holds the column's width.
  ${perSlot (
    i:
    "    let c.head.${S i} = "
    + sumOthers i (j: "${same i j} * (cpos.${S j} == cpos.${S i}) * ${above i j}")
    + " < 0.5"
  )}
  ${perSlot (
    i: "    let c.col.${S i} = " + sum (j: "${same i j} * c.head.${S j} * (cpos.${S j} < cpos.${S i})")
  )}
  ${perSlot (i: "    let c.ncol.${S i} = " + sum (j: "${same i j} * c.head.${S j}"))}
  ${perSlot (
    i:
    "    let c.cw.${S i} = "
    + sum (j: "${same i j} * c.head.${S j} * (cpos.${S j} == cpos.${S i}) * wp.${S j}")
  )}
  ${perSlot (
    i:
    "    let c.tab.${S i} = "
    + sum (j: "${same i j} * c.head.${S j} * (cpos.${S j} == cpos.${S i}) * tb.${S j}")
  )}
  ${perSlot (
    i:
    "    let c.before.${S i} = "
    + sum (j: "${same i j} * c.head.${S j} * (cpos.${S j} < cpos.${S i}) * wp.${S j}")
  )}
  ${perSlot (
    i:
    "    let c.row.${S i} = "
    + sumOthers i (j: "${same i j} * (cpos.${S j} == cpos.${S i}) * ${above i j}")
  )}
  ${perSlot (i: "    let c.rows.${S i} = " + sum (j: "${same i j} * (cpos.${S j} == cpos.${S i})"))}
  ${perSlot (
    i:
    "    let c.beat.${S i} = "
    + sumOthers i (j: "${same i j} * (cpos.${S j} == cpos.${S i}) * (stamp.${S j} > stamp.${S i})")
  )}
      // The last column position on its workspace, not counting itself.
  ${perSlot (
    i:
    "    let c.last.${S i} = "
    + maxOf (lib.remove i all) (j: "${same i j} * (cpos.${S j} + 1)")
    + " - 1"
  )}

      // Members of a column follow its head's width and tabbing, so whichever
      // of them heads it next keeps both.
  ${perSlot
    (i: ''
      on change c.cw.${S i} while not c.head.${S i} and win.${S i}.place >= 0 { wp.${S i} = c.cw.${S i} }
      on change c.tab.${S i} while not c.head.${S i} and win.${S i}.place >= 0 { tb.${S i} = c.tab.${S i} }'')
  }

      // per monitor: the strip on the workspace it shows
  ${concatMapStringsSep "\n" (
    s: "    let m.all.${S s} = " + sum (j: "${shownOn s j} * c.head.${S j} * wp.${S j}")
  ) mons}
      // The window there that had the keyboard last, for crossing monitors.
  ${concatMapStringsSep "\n" (
    s:
    "    let m.top.${S s} = "
    + maxOf all (
      j:
      "(win.${S j}.open and not win.${S j}.minimized and win.${S j}.screen == ${S s} and win.${S j}.pool == win.pool.${S s}) * (stamp.${S j} + 1)"
    )
  ) mons}
  ${concatMapStringsSep "\n" (
    s:
    "    let m.topslot.${S s} = "
    + sum (
      j:
      "(win.${S j}.open and not win.${S j}.minimized and win.${S j}.screen == ${S s} and win.${S j}.pool == win.pool.${S s}) * (stamp.${S j} + 1 == m.top.${S s}) * (m.top.${S s} > 0.5) * ${S (j + 1)}"
    )
    + " - 1"
  ) mons}

      // per monitor: its working area
      // Space a layer reserves at the left or right shifts the strip rather
      // than narrowing it, so the shell's drawer slides windows aside; room
      // is what the shell's rail and drawer take, told by the shell itself
  ${concatMapStringsSep "\n" (
    s:
    let
      n = S s;
    in
    ''
      let W.${n} = screen.${n}.width
      let H.${n} = screen.${n}.height
      let Ax.${n} = strut + win.reserved.${n}.left - win.reserved.${n}.right + room.${n}
      let Wa.${n} = W.${n} - 2 * strut
      let Ay.${n} = win.reserved.${n}.top + strut + gap
      let Ha.${n} = H.${n} - win.reserved.${n}.top - win.reserved.${n}.bottom - 2 * strut - 2 * gap
      let avail.${n} = Wa.${n} - 2 * gap
      let T.${n} = (Wa.${n} - gap) * m.all.${n} - gap
      let view.${n} = if(T.${n} <= avail.${n}, (T.${n} - avail.${n}) / 2, clamp(sco.${n}, 0, T.${n} - avail.${n}))''
  ) mons}

      // Which of a monitor's first ten workspaces hold windows, as bits.
  ${concatMapStringsSep "\n" (
    s:
    "    let ws.occ.${S s} = "
    + concatMapStringsSep " + " (
      k:
      "${S (pow2 (k - 1))} * min(1, "
      + sum (
        j:
        "(win.${S j}.open and not win.${S j}.minimized and win.${S j}.screen == ${S s} and win.${S j}.workspace == ${S k})"
      )
      + ")"
    ) (range 1 10)
  ) mons}

      // the focused window
      let f = max(win.focus, 0)
      // A closed window can stay named as focused for a moment: f.live says
      // it is still there.
      let f.live = win.focus >= 0 and ${pick "f" (j: "win.${j}.open")}
      let f.on = win.focus >= 0 and ${pick "f" (j: "win.${j}.place")} >= 0
      let f.sc = ${pick "f" (j: "win.${j}.screen")}
      let f.pool = ${pick "f" (j: "win.${j}.pool")}
      // f.vis: and on the workspace its monitor shows (closing a window can
      // hand the keyboard to one on a workspace out of sight)
      let f.vis = f.live and f.pool == pick(f.sc, ${concatMapStringsSep ", " (s: "win.pool.${S s}") mons})
      let f.ws = ${pick "f" (j: "win.${j}.workspace")}
      let f.cpos = ${pick "f" (j: "cpos.${j}")}
      let f.rpos = ${pick "f" (j: "rpos.${j}")}
      let f.col = ${pick "f" (j: "c.col.${j}")}
      let f.row = ${pick "f" (j: "c.row.${j}")}
      let f.rows = ${pick "f" (j: "c.rows.${j}")}
      let f.ncol = ${pick "f" (j: "c.ncol.${j}")}
      let f.lcpos = ${cposOf "f.col - 1"}
      let f.rcpos = ${cposOf "f.col + 1"}
      let f.lrmax = ${rmaxOf "f.lcpos"}
      let f.rrmax = ${rmaxOf "f.rcpos"}
      let f.left = ${act "f.col - 1"}
      let f.right = ${act "f.col + 1"}
      let f.up = ${at "f.col" "f.row - 1"}
      let f.down = ${at "f.col" "f.row + 1"}
      let f.bottom = ${at "f.col" "f.rows - 1"}
      let f.uprpos = ${pick "max(f.up, 0)" (j: "rpos.${j}")}
      let f.downrpos = ${pick "max(f.down, 0)" (j: "rpos.${j}")}
      let f.monl = ${
        pick "max(f.sc - 1, 0)" (j: if lib.toInt j < monitors then "m.topslot.${j}" else "-1")
      }
      let f.monr = ${pick "f.sc + 1" (j: if lib.toInt j < monitors then "m.topslot.${j}" else "-1")}
      // The monitor the pointer is on, and the workspace it shows.
      let p.ws = pick(mon, ${concatMapStringsSep ", " (s: "win.shown.${S s}") mons})
      // The monitor with the keyboard (kmon, in session.plm), and the
      // workspace it shows.
      let k.ws = pick(kmon, ${concatMapStringsSep ", " (s: "win.shown.${S s}") mons})

      // moving the keyboard
      on focus_left while f.on and f.col > 0.5 and f.left >= 0 {
          pan = 1
          focus win(f.left)
      }
      on focus_left while (not f.on or f.col < 0.5) and f.sc > 0.5 and f.monl >= 0 {
          pan = 1
          focus win(f.monl)
      }
      on focus_right while f.on and f.col < f.ncol - 1.5 and f.right >= 0 {
          pan = 1
          focus win(f.right)
      }
      on focus_right while (not f.on or f.col > f.ncol - 1.5) and f.sc < screens.count - 1.5 and f.monr >= 0 {
          pan = 1
          focus win(f.monr)
      }
      on focus_up while f.on and f.row > 0.5 { focus win(f.up) }
      on focus_up while (not f.on or f.row < 0.5) and f.vis and f.ws > 1.5 {
          pan = 1
          workspace f.ws - 1 on f.sc
      }
      on focus_up while not f.vis and k.ws > 1.5 { workspace k.ws - 1 on kmon }
      on focus_down while f.on and f.row < f.rows - 1.5 { focus win(f.down) }
      on focus_down while (not f.on or f.row > f.rows - 1.5) and f.vis {
          pan = 1
          workspace f.ws + 1 on f.sc
      }
      on focus_down while not f.vis { workspace k.ws + 1 on kmon }
      on focus_cycle while f.on and f.row > 0.5 { focus win(f.up) }
      on focus_cycle while f.on and f.row < 0.5 and f.rows > 1.5 { focus win(f.bottom) }

      // moving windows past the edge of the column, or of the strip
      on move_up while f.vis and (not f.on or f.row < 0.5) and f.ws > 1.5 {
          send win(win.focus) to workspace f.ws - 1
          workspace f.ws - 1 on f.sc
      }
      on move_down while f.vis and (not f.on or f.row > f.rows - 1.5) {
          send win(win.focus) to workspace f.ws + 1
          workspace f.ws + 1 on f.sc
      }
      on move_left while f.on and f.col > 0.5 { pan = 1 }
      on move_right while f.on and f.col < f.ncol - 1.5 { pan = 1 }
      on move_left while win.focus >= 0 and (not f.on or f.col < 0.5) and f.sc > 0.5 { send win(win.focus) to f.sc - 1 }
      on move_right while win.focus >= 0 and (not f.on or f.col > f.ncol - 1.5) and f.sc < screens.count - 1.5 { send win(win.focus) to f.sc + 1 }
      on consume_left while f.on { pan = 1 }
      on consume_right while f.on { pan = 1 }

  ${perSlot (
    i:
    let
      n = S i;
      ws = sf i;
      me = "win.focus == ${n}";
    in
    ''
      // slot ${n}
      // A column and its neighbour trade positions.
      on move_left while f.on and f.col > 0.5 and ${ws} and cpos.${n} == f.cpos { cpos.${n} = f.lcpos }
      on move_left while f.on and f.col > 0.5 and ${ws} and cpos.${n} == f.lcpos { cpos.${n} = f.cpos }
      on move_right while f.on and f.col < f.ncol - 1.5 and ${ws} and cpos.${n} == f.cpos { cpos.${n} = f.rcpos }
      on move_right while f.on and f.col < f.ncol - 1.5 and ${ws} and cpos.${n} == f.rcpos { cpos.${n} = f.cpos }
      // Within a column, a window and its neighbour trade rows.
      on move_up while f.on and f.row > 0.5 and ${me} { rpos.${n} = f.uprpos }
      on move_up while f.on and f.row > 0.5 and f.up == ${n} { rpos.${n} = f.rpos }
      on move_down while f.on and f.row < f.rows - 1.5 and ${me} { rpos.${n} = f.downrpos }
      on move_down while f.on and f.row < f.rows - 1.5 and f.down == ${n} { rpos.${n} = f.rpos }
      // Out of a shared column into its own, left of it: everything from
      // that column on moves one along.
      on consume_left while f.on and f.rows > 1.5 and ${ws} and not ${me} and cpos.${n} >= f.cpos { cpos.${n} = cpos.${n} + 1 }
      on consume_left while f.on and f.rows > 1.5 and ${me} { wp.${n} = c.cw.${n} }
      // ...or right of it.
      on consume_right while f.on and f.rows > 1.5 and ${ws} and not ${me} and cpos.${n} > f.cpos { cpos.${n} = cpos.${n} + 1 }
      on consume_right while f.on and f.rows > 1.5 and ${me} {
          cpos.${n} = f.cpos + 1
          wp.${n} = c.cw.${n}
      }
      // Alone, into the bottom of the neighbouring column.
      on consume_left while f.on and f.rows < 1.5 and f.col > 0.5 and ${me} {
          cpos.${n} = f.lcpos
          rpos.${n} = f.lrmax + 1
      }
      on consume_right while f.on and f.rows < 1.5 and f.col < f.ncol - 1.5 and ${me} {
          cpos.${n} = f.rcpos
          rpos.${n} = f.rrmax + 1
      }
      on toggle_tabbed while f.on and c.head.${n} and ${ws} and cpos.${n} == f.cpos { tb.${n} = 1 - tb.${n} }
      // A window that arrives on a workspace, or comes back from floating,
      // goes at the end of the strip there.
      on change win.${n}.pool while win.${n}.open and nw != ${n} {
          cpos.${n} = c.last.${n} + 1
          rpos.${n} = 0
      }
      on change win.${n}.floating while not win.${n}.floating and win.${n}.open {
          cpos.${n} = c.last.${n} + 1
          rpos.${n} = 0
      }
      // A window that opens goes right of the column that had the keyboard,
      // or at the end if that one is elsewhere.
      on place_new while n.ok and (win.${n}.place >= 0 and win.${n}.screen == n.sc and win.${n}.pool == n.pool) and nw != ${n} and cpos.${n} > n.fcpos { cpos.${n} = cpos.${n} + 1 }
      on place_new while nw == ${n} {
          cpos.${n} = if(n.ok, n.fcpos + 1, c.last.${n} + 1)
          rpos.${n} = 0
          wp.${n} = if(c.ncol.${n} < 1.5, 0.6667, 0.5)
      }''
  )}

      // the window that just opened, and the one that had the keyboard before it
      fact nw = -1
      fact nwt = 0
      fact lf = -1
      fact lf.prev = -1
      event place_new
      on change win.focus {
          lf.prev = lf
          lf = win.focus
      }
      let n = max(nw, 0)
      let n.sc = ${pick "n" (j: "win.${j}.screen")}
      let n.pool = ${pick "n" (j: "win.${j}.pool")}
      let n.from = if(lf == nw, lf.prev, lf)
      let n.fk = max(n.from, 0)
      let n.ok = nw >= 0 and n.from >= 0 and n.from != nw and ${
        pick "n.fk" (j: "win.${j}.place")
      } >= 0 and ${pick "n.fk" (j: "win.${j}.screen")} == n.sc and ${
        pick "n.fk" (j: "win.${j}.pool")
      } == n.pool
      let n.fcpos = ${pick "n.fk" (j: "cpos.${j}")}
      on place_new {
          nw = -1
          newpan = 1
      }

      // the window being dragged
      let d = max(dslot, 0)
      let d.sc = ${pick "d" (j: "win.${j}.screen")}
      let d.pool = ${pick "d" (j: "win.${j}.pool")}
      let d.cpos = ${pick "d" (j: "cpos.${j}")}
  }
''
