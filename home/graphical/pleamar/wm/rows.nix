# The row layout's bookkeeping, unrolled over every window slot. The scene
# language has no loops that accumulate, so the sums over the other slots
# (place in the row, row index, offsets) are written out here.
#
# Each monitor shows one workspace made of rows stacked top to bottom. A row
# is a strip of windows, each with its own width, centred when it fits and
# panned when it does not. Each window has a row position and a position
# within its row (gaps allowed, only the order counts); windows on one monitor
# sharing a row position are one row, and the first of them holds its height.
#
# Up to three windows the shape follows the count (centre, pair, two over
# one); a fourth window, or a window moving between rows or being resized,
# makes the monitor's rows its own until it is down to one window again.
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

  sum = f: "(" + concatMapStringsSep " + " f all + ")";
  sumOthers = i: f: "(" + concatMapStringsSep " + " f (lib.remove i all) + ")";
  pick = idx: field: "pick(${idx}, ${concatMapStringsSep ", " (j: field (S j)) all})";
  pickMon = idx: field: "pick(${idx}, ${concatMapStringsSep ", " (s: field (S s)) mons})";
  fold =
    op: js: f:
    lib.foldl' (acc: j: "${op}(${acc}, ${f j})") (f (lib.head js)) (lib.tail js);
  maxOf = fold "max";
  minOf = fold "min";

  # Slot j is tiled on the same monitor and workspace as slot i. A window
  # still waiting for its place (nw) counts for nobody else: the rest do not
  # make room for where it sits until place_new puts it where it goes.
  # From then on the auto shape counts it (counted), but the others only make
  # room for it once it shows (nhold), in the same frame as the camera.
  counted =
    i: j:
    if i == j then
      "(win.${S i}.place >= 0)"
    else
      "(win.${S j}.place >= 0 and nw != ${S j} and win.${S j}.screen == win.${S i}.screen and win.${S j}.pool == win.${S i}.pool)";
  same =
    i: j: if i == j then counted i j else "(${counted i j} and not (nhold > 0.5 and nwl == ${S j}))";
  # ...and in the same row.
  sameRow = i: j: if i == j then same i j else "(${same i j} and rpos.${S j} == rpos.${S i})";
  # ...as the focused window.
  sf = j: "(win.${S j}.place >= 0 and win.${S j}.screen == f.sc and win.${S j}.pool == f.pool)";
  # Shown and tiled on monitor s.
  shownOn =
    s: j:
    "(win.${S j}.place >= 0 and nw != ${S j} and win.${S j}.screen == ${S s} and win.${S j}.pool == win.pool.${S s})";
  # Slot j comes before slot i within their row, and in the whole order.
  before =
    i: j: "(cpos.${S j} < cpos.${S i}${lib.optionalString (j < i) " or cpos.${S j} == cpos.${S i}"})";
  ordBefore =
    i: j: "(rpos.${S j} < rpos.${S i} or (rpos.${S j} == rpos.${S i} and ${before i j}))";

  perSlot = f: concatMapStringsSep "\n" f all;
  perMon = f: concatMapStringsSep "\n" f mons;

  # The width and height presets, cycled upwards and back to the smallest.
  nextPreset = v: "if(${v} < 0.32, 0.3333, if(${v} < 0.49, 0.5, if(${v} < 0.65, 0.6667, if(${v} < 0.99, 1, 0.3333))))";
in
''
  part Rows {
      // per slot: where in the scene, and how big
      // rpos, cpos: its row's position and its own within the row (gaps
      // allowed, only the order counts). wp: its width, as a share of the
      // working area. hp: a head's row height, as a share of it. stamp: when
      // it last had the keyboard.
  ${perSlot (i: ''
    fact rpos.${S i} = 0
    fact cpos.${S i} = 0
    fact wp.${S i} = 0.5
    fact hp.${S i} = 1
    fact stamp.${S i} = 0'')}
      fact stamp.top = 0

      // springs shared across slots and monitors
  ${perSlot (i: ''
    prop x.${S i} = 0 ~niri
    prop y.${S i} = 0 ~niri
    prop w.${S i} = 100 ~niri
    prop h.${S i} = 100 ~niri'')}

      // per monitor: the camera, the row shapes, and the window it follows
      // auto: the shape follows the count. cam.a: the window the camera is
      // on, moved by the keyboard, not the pointer. ofs: a pan by hand.
  ${perMon (
    s:
    let
      n = S s;
    in
    ''
      fact auto.${n} = true
      fact cam.a.${n} = -1
      fact ofs.x.${n} = 0
      fact ofs.y.${n} = 0
      prop vx.${n} = 0 ~niri
      prop vy.${n} = 0 ~niri''
  )}

      // A row's head is its first window; it holds the row's height.
  ${perSlot (i: "    let r.head.${S i} = " + sumOthers i (j: "${sameRow i j} * ${before i j}") + " < 0.5")}
  ${perSlot (i: "    let c.idx.${S i} = " + sumOthers i (j: "${sameRow i j} * ${before i j}"))}
  ${perSlot (i: "    let r.n.${S i} = " + sum (j: sameRow i j))}
  ${perSlot (
    i: "    let r.idx.${S i} = " + sum (j: "${same i j} * r.head.${S j} * (rpos.${S j} < rpos.${S i})")
  )}
  ${perSlot (i: "    let r.cnt.${S i} = " + sum (j: "${same i j} * r.head.${S j}"))}
  ${perSlot (i: "    let r.hp.${S i} = " + sum (j: "${sameRow i j} * r.head.${S j} * hp.${S j}"))}
  ${perSlot (
    i:
    "    let r.hb.${S i} = "
    + sum (j: "${same i j} * r.head.${S j} * (rpos.${S j} < rpos.${S i}) * hp.${S j}")
  )}
  ${perSlot (i: "    let m.ht.${S i} = " + sum (j: "${same i j} * r.head.${S j} * hp.${S j}"))}
  ${perSlot (i: "    let r.w.${S i} = " + sum (j: "${sameRow i j} * wp.${S j}"))}
  ${perSlot (i: "    let c.before.${S i} = " + sumOthers i (j: "${sameRow i j} * ${before i j} * wp.${S j}"))}
  ${perSlot (i: "    let o.idx.${S i} = " + sumOthers i (j: "${counted i j} * ${ordBefore i j}"))}
  ${perSlot (i: "    let m.k.${S i} = " + sum (j: counted i j))}

      // Members of a row follow its head's height, so whichever of them
      // heads it next keeps it.
  ${perSlot (
    i:
    "    on change r.hp.${S i} while not r.head.${S i} and win.${S i}.place >= 0 { hp.${S i} = r.hp.${S i} }"
  )}

      // per monitor: its working area
      // Space a layer reserves at the left or right shifts the scene rather
      // than narrowing it, so the shell's drawer slides windows aside; room
      // is what the shell's rail and drawer take, told by the shell itself
  ${perMon (
    s:
    let
      n = S s;
    in
    ''
      let W.${n} = screen.${n}.width
      let H.${n} = screen.${n}.height
      let Ax.${n} = strut + win.reserved.${n}.left - win.reserved.${n}.right + room.${n} + max(edge.${n}, 0)
      let Wa.${n} = W.${n} - 2 * strut - abs(edge.${n})
      let Ay.${n} = win.reserved.${n}.top + strut + gap
      let Ha.${n} = H.${n} - win.reserved.${n}.top - win.reserved.${n}.bottom - 2 * strut - 2 * gap
      let avail.${n} = Wa.${n} - 2 * gap''
  )}

      // per slot: its place, centred on the middle of the working area
      // uw, uh: what a width or height share of 1 measures, gap included.
  ${perSlot (
    i:
    let
      n = S i;
      sc = "win.${n}.screen";
    in
    ''
      let uw.${n} = ${pickMon sc (s: "Wa.${s} - gap")}
      let uh.${n} = ${pickMon sc (s: "Ha.${s} + gap")}
      let av.${n} = ${pickMon sc (s: "avail.${s}")}
      let ha.${n} = ${pickMon sc (s: "Ha.${s}")}
      let tw.${n} = max(uw.${n} * wp.${n} - gap, 40)
      let th.${n} = max(uh.${n} * r.hp.${n} - gap, 40)
      let rw.${n} = uw.${n} * r.w.${n} - gap
      let tht.${n} = uh.${n} * m.ht.${n} - gap
      let lx.${n} = uw.${n} * c.before.${n} - rw.${n} / 2
      let ly.${n} = uh.${n} * r.hb.${n} - tht.${n} / 2
      let cx.${n} = lx.${n} + tw.${n} / 2
      // Where the camera goes to show it: still when its row (or the stack)
      // fits, else on it, with the first and last snapped to the edge.
      let tgx.${n} = if(rw.${n} <= av.${n} + 0.5, 0, if(c.idx.${n} < 0.5, (av.${n} - rw.${n}) / 2, if(c.idx.${n} > r.n.${n} - 1.5, (rw.${n} - av.${n}) / 2, cx.${n})))
      let tgy.${n} = if(tht.${n} <= ha.${n} + 0.5, 0, if(r.idx.${n} < 0.5, (ha.${n} - tht.${n}) / 2, if(r.idx.${n} > r.cnt.${n} - 1.5, (tht.${n} - ha.${n}) / 2, ly.${n} + th.${n} / 2)))''
  )}

      // the window taking the place of a focused one that closes (below)
  ${perSlot (
    i:
    let
      n = S i;
    in
    "    let cl.k.${n} = if(win.${n}.open and win.${n}.place >= 0 and win.${n}.screen == cl.sc and win.${n}.pool == cl.pool, if(rpos.${n} == cl.rpos, if(cpos.${n} > cl.cpos, cpos.${n} - cl.cpos, 1000 + cl.cpos - cpos.${n}), 100000 + abs(rpos.${n} - cl.rpos) * 1000 + cpos.${n}), 1000000000) + ${n} * 0.001"
  )}
      let cl.min = ${minOf all (j: "cl.k.${S j}")}
      let cl.target = ${sum (j: "${S j} * if(abs(cl.k.${S j} - cl.min) < 0.0005, 1, 0)")}

      // per monitor: what is shown, and where the camera goes
  ${perMon (s: "    let m.count.${S s} = " + sum (shownOn s))}
      // The window there that had the keyboard last, for crossing monitors.
  ${perMon (
    s:
    "    let m.top.${S s} = "
    + maxOf all (
      j:
      "(win.${S j}.open and not win.${S j}.minimized and win.${S j}.screen == ${S s} and win.${S j}.pool == win.pool.${S s}) * (stamp.${S j} + 1)"
    )
  )}
  ${perMon (
    s:
    "    let m.topslot.${S s} = "
    + sum (
      j:
      "(win.${S j}.open and not win.${S j}.minimized and win.${S j}.screen == ${S s} and win.${S j}.pool == win.pool.${S s}) * (stamp.${S j} + 1 == m.top.${S s}) * (m.top.${S s} > 0.5) * ${S (j + 1)}"
    )
    + " - 1"
  )}
  ${perMon (
    s:
    let
      n = S s;
    in
    ''
      // the camera's window: the one it was put on while still here, or the
      // last with the keyboard. A new window, until it has its place and the
      // shape has settled, holds it on the window it was opened from. One
      // closing goes straight to the one taking its place, from the frame it
      // closes, not by whatever pleamar-wm focused meanwhile.
      let cam.c.${n} = if(cl.pending and cl.sc == ${n} and cl.min < 100000000, cl.target, if((nw >= 0 and cam.a.${n} == nw) or (nhold > 0.5 and cam.a.${n} == nwl), if(lf == cam.a.${n}, lf.prev, lf), cam.a.${n}))
      let cam.k.${n} = if(cam.c.${n} >= 0 and ${pick "max(cam.c.${n}, 0)" (shownOn s)}, cam.c.${n}, m.topslot.${n})
      let cam.tx.${n} = if(cam.k.${n} >= 0, ${pick "max(cam.k.${n}, 0)" (j: "tgx.${j}")}, 0) + ofs.x.${n}
      let cam.ty.${n} = if(cam.k.${n} >= 0, ${pick "max(cam.k.${n}, 0)" (j: "tgy.${j}")}, 0) + ofs.y.${n}
      // the widest row and the whole stack, for the overview
      let m.rw.${n} = ${maxOf all (j: "${shownOn s j} * rw.${S j}")}
      let m.th.${n} = ${maxOf all (j: "${shownOn s j} * tht.${S j}")}''
  )}

      // the focused window
      let f = max(win.focus, 0)
      // A closed window can stay named as focused for a moment: f.live says
      // it is still there.
      let f.live = win.focus >= 0 and ${pick "f" (j: "win.${j}.open")}
      let f.on = win.focus >= 0 and ${pick "f" (j: "win.${j}.place")} >= 0
      let f.sc = ${pick "f" (j: "win.${j}.screen")}
      let f.pool = ${pick "f" (j: "win.${j}.pool")}
      // f.vis: and on the workspace its monitor shows
      let f.vis = f.live and f.pool == ${pickMon "f.sc" (s: "win.pool.${s}")}
      let f.rpos = ${pick "f" (j: "rpos.${j}")}
      let f.cpos = ${pick "f" (j: "cpos.${j}")}
      let f.c = ${pick "f" (j: "c.idx.${j}")}
      let f.rn = ${pick "f" (j: "r.n.${j}")}
      let f.ri = ${pick "f" (j: "r.idx.${j}")}
      let f.rc = ${pick "f" (j: "r.cnt.${j}")}
      let f.hp = ${pick "f" (j: "r.hp.${j}")}
      let f.o = ${pick "f" (j: "o.idx.${j}")}
      let f.cx = ${pick "f" (j: "cx.${j}")}
      let f.auto = ${pickMon "f.sc" (s: "auto.${s}")}
      // neighbours in the row, and in the whole order
      let f.left = ${sum (j: "${sf j} * (rpos.${S j} == f.rpos) * (c.idx.${S j} == f.c - 1) * ${S (j + 1)}")} - 1
      let f.right = ${sum (j: "${sf j} * (rpos.${S j} == f.rpos) * (c.idx.${S j} == f.c + 1) * ${S (j + 1)}")} - 1
      let f.prev = ${sum (j: "${sf j} * (o.idx.${S j} == f.o - 1) * ${S (j + 1)}")} - 1
      let f.next = ${sum (j: "${sf j} * (o.idx.${S j} == f.o + 1) * ${S (j + 1)}")} - 1
      // The rows above and below: the window in each nearest to its middle.
  ${perSlot (
    j:
    let
      n = S j;
    in
    ''
      let du.${n} = if(${sf j} and r.idx.${n} == f.ri - 1, abs(cx.${n} - f.cx) + ${n} * 0.01, 100000)
      let dd.${n} = if(${sf j} and r.idx.${n} == f.ri + 1, abs(cx.${n} - f.cx) + ${n} * 0.01, 100000)''
  )}
      let f.du = ${minOf all (j: "du.${S j}")}
      let f.dd = ${minOf all (j: "dd.${S j}")}
      let f.up = if(f.du > 50000, -1, ${sum (j: "(du.${S j} == f.du) * ${S (j + 1)}")} - 1)
      let f.down = if(f.dd > 50000, -1, ${sum (j: "(dd.${S j} == f.dd) * ${S (j + 1)}")} - 1)
      let f.uprpos = ${pick "max(f.up, 0)" (j: "rpos.${j}")}
      let f.downrpos = ${pick "max(f.down, 0)" (j: "rpos.${j}")}
      let f.uphp = ${pick "max(f.up, 0)" (j: "r.hp.${j}")}
      let f.downhp = ${pick "max(f.down, 0)" (j: "r.hp.${j}")}
      // where in the row above or below it goes: beside the nearest one, on
      // the side its middle is
      let f.upcpos = ${pick "max(f.up, 0)" (j: "cpos.${j} + if(f.cx > cx.${j}, 0.5, -0.5)")}
      let f.downcpos = ${pick "max(f.down, 0)" (j: "cpos.${j} + if(f.cx > cx.${j}, 0.5, -0.5)")}
      let f.monl = ${pick "max(f.sc - 1, 0)" (j: if lib.toInt j < monitors then "m.topslot.${j}" else "-1")}
      let f.monr = ${pick "f.sc + 1" (j: if lib.toInt j < monitors then "m.topslot.${j}" else "-1")}
      // The monitor the pointer is on, and the workspace it shows.
      let p.ws = pick(mon, ${concatMapStringsSep ", " (s: "win.shown.${S s}") mons})

      // positions back to whole numbers once a move has settled. norm counts
      // up so every request is a change. Each slot's rank is taken before any
      // is written: c.idx and r.idx read the others' positions, and the slots'
      // rules run one after the other.
      fact norm = 0
  ${perSlot (i: ''
    fact nr.${S i} = 0
    fact nc.${S i} = 0
    on still norm for 50ms while win.${S i}.place >= 0 {
        nr.${S i} = r.idx.${S i}
        nc.${S i} = c.idx.${S i}
    }'')}

      // moving the keyboard
      on focus_left while f.on and f.left >= 0 {
          pan = 1
          focus win(f.left)
      }
      on focus_left while (not f.on or f.left < 0) and f.sc > 0.5 and f.monl >= 0 {
          pan = 1
          focus win(f.monl)
      }
      on focus_right while f.on and f.right >= 0 {
          pan = 1
          focus win(f.right)
      }
      on focus_right while (not f.on or f.right < 0) and f.sc < screens.count - 1.5 and f.monr >= 0 {
          pan = 1
          focus win(f.monr)
      }
      on focus_up while f.on and f.up >= 0 {
          pan = 1
          focus win(f.up)
      }
      on focus_down while f.on and f.down >= 0 {
          pan = 1
          focus win(f.down)
      }

      // A window and its neighbour in the row trade places: both places are
      // taken here first, since the two slots' rules run one after the other
      // and the first to run changed what the second read (nothing moved
      // when the neighbour's slot came first).
      fact mv.f = 0
      fact mv.n = 0
      on move_left while f.on and f.left >= 0 {
          pan = 1
          mv.f = f.cpos
          mv.n = ${pick "max(f.left, 0)" (j: "cpos.${j}")}
      }
      on move_right while f.on and f.right >= 0 {
          pan = 1
          mv.f = f.cpos
          mv.n = ${pick "max(f.right, 0)" (j: "cpos.${j}")}
      }

      // moving windows past the end of the row, to the next monitor
      on move_left while win.focus >= 0 and (not f.on or f.left < 0) and f.sc > 0.5 {
          sendir = -1
          ksend = win.focus
          send win(win.focus) to f.sc - 1
      }
      on move_right while win.focus >= 0 and (not f.on or f.right < 0) and f.sc < screens.count - 1.5 {
          sendir = 1
          ksend = win.focus
          send win(win.focus) to f.sc + 1
      }
      // Up or down into the next row, or past the last into a new one, unless
      // it is alone at that end already.
      on move_up while f.on and (f.up >= 0 or f.rn > 1.5) {
          pan = 1
          norm = norm + 1
      }
      on move_down while f.on and (f.down >= 0 or f.rn > 1.5) {
          pan = 1
          norm = norm + 1
      }
      fact sendir = 0
      // the window the keyboard is sending to another monitor, until it lands
      fact ksend = -1

      // The rows become the monitor's own: by moving between them, resizing,
      // or a fifth window.
  ${perMon (
    s:
    let
      n = S s;
    in
    ''
      on move_up while f.on and f.sc == ${n} and (f.up >= 0 or f.rn > 1.5) { auto.${n} = false }
      on move_down while f.on and f.sc == ${n} and (f.down >= 0 or f.rn > 1.5) { auto.${n} = false }
      on cycle_width while f.on and f.sc == ${n} { auto.${n} = false }
      on cycle_height while f.on and f.sc == ${n} { auto.${n} = false }
      // Three is the last shape it makes: a fourth window makes the monitor's
      // rows its own, and it joins the focused row (placed by hand, below).
      on change m.count.${n} while m.count.${n} > 3.5 { auto.${n} = false }
      on still m.count.${n} for 100ms while m.count.${n} > 3.5 and auto.${n} { auto.${n} = false }
      on change m.count.${n} while m.count.${n} < 1.5 { auto.${n} = true }
      // The keyboard moving a window takes the camera with it.
      on change pan while pan > 0.5 and f.on and f.sc == ${n} and nw != win.focus {
          cam.a.${n} = win.focus
          ofs.x.${n} = 0
          ofs.y.${n} = 0
      }''
  )}

  ${perSlot (
    i:
    let
      n = S i;
      ws = sf i;
      me = "win.focus == ${n}";
      autoOn = pickMon "win.${n}.screen" (s: "auto.${s}");
      k = "o.idx.${n}";
      cnt = "m.k.${n}";
    in
    ''
      // slot ${n}
      // A window and its neighbour in the row trade places (taken above).
      on move_left while f.on and f.left >= 0 and ${ws} and cpos.${n} == f.cpos and rpos.${n} == f.rpos { cpos.${n} = mv.n }
      on move_left while f.on and f.left == ${n} { cpos.${n} = mv.f }
      on move_right while f.on and f.right >= 0 and ${ws} and cpos.${n} == f.cpos and rpos.${n} == f.rpos { cpos.${n} = mv.n }
      on move_right while f.on and f.right == ${n} { cpos.${n} = mv.f }
      // Into the row above or below, beside the window nearest its middle,
      // taking that row's height; past the end, a new row of half height.
      on move_up while f.on and ${me} and f.up >= 0 {
          rpos.${n} = f.uprpos
          cpos.${n} = f.upcpos
          hp.${n} = f.uphp
      }
      on move_up while f.on and ${me} and f.up < 0 and f.rn > 1.5 {
          rpos.${n} = -1000
          cpos.${n} = 0
          hp.${n} = 0.5
      }
      on move_down while f.on and ${me} and f.down >= 0 {
          rpos.${n} = f.downrpos
          cpos.${n} = f.downcpos
          hp.${n} = f.downhp
      }
      on move_down while f.on and ${me} and f.down < 0 and f.rn > 1.5 {
          rpos.${n} = 1000
          cpos.${n} = 0
          hp.${n} = 0.5
      }
      on still norm for 50ms while win.${n}.place >= 0 {
          rpos.${n} = nr.${n}
          cpos.${n} = nc.${n}
      }
      // Width presets for the window, height presets for its whole row.
      on cycle_width while f.on and ${me} { wp.${n} = ${nextPreset "wp.${n}"} }
      on cycle_height while f.on and ${ws} and rpos.${n} == f.rpos { hp.${n} = ${nextPreset "f.hp"} }

      // A window that arrives from another monitor joins the row the camera
      // is on there, at the side it came in from.
      on change win.${n}.pool while win.${n}.open and nw != ${n} {
          rpos.${n} = ${pickMon "win.${n}.screen" (s: pick "max(cam.k.${s}, 0)" (j: "rpos.${j}"))}
          cpos.${n} = if(sendir > 0, -1000, 1000)
          hp.${n} = ${pickMon "win.${n}.screen" (s: pick "max(cam.k.${s}, 0)" (j: "r.hp.${j}"))}
          norm = norm + 1
      }
      on change win.${n}.floating while not win.${n}.floating and win.${n}.open {
          rpos.${n} = 1000
          cpos.${n} = 0
          hp.${n} = 0.5
          norm = norm + 1
      }
      // A window that opens goes right of the one that had the keyboard, in
      // its row, or in a new row at the bottom if that one is elsewhere; or,
      // that row being full (n.newrow), in a new row just below it.
      on place_new while not ${autoOn} and n.ok and not n.newrow and win.${n}.place >= 0 and win.${n}.screen == n.sc and win.${n}.pool == n.pool and rpos.${n} == n.frpos and nw != ${n} and cpos.${n} > n.fcpos { cpos.${n} = cpos.${n} + 1 }
      on place_new while not ${autoOn} and n.newrow and win.${n}.place >= 0 and win.${n}.screen == n.sc and win.${n}.pool == n.pool and nw != ${n} and rpos.${n} > n.frpos { rpos.${n} = rpos.${n} + 1 }
      on place_new while not ${autoOn} and nw == ${n} {
          rpos.${n} = if(n.newrow, n.frpos + 1, if(n.ok, n.frpos, 1000))
          cpos.${n} = if(n.newrow, 0, if(n.ok, n.fcpos + 1, 0))
          wp.${n} = 0.5
          hp.${n} = if(n.ok, n.fhp, 0.5)
          norm = norm + 1
      }
      // Auto shapes: one in the middle, two side by side, then two over one
      // (the new window goes below, the two above stay; each row two thirds
      // high, the strip scrolling to the lower one); a fourth is placed by hand.
      // Once the count has settled, so the order it reads is the one the
      // other rules left.
      let ash.${n} = ${cnt} + 10 * ${autoOn} + 100 * (win.${n}.place >= 0) + 1000 * win.${n}.screen
      on still ash.${n} for 40ms while ${autoOn} and win.${n}.place >= 0 and ${cnt} < 3.5 {
          rpos.${n} = if(abs(${cnt} - 3) < 0.5, if(${k} < 1.5, 0, 1), if(abs(${cnt} - 4) < 0.5, floor(${k} / 2), 0))
          cpos.${n} = if(abs(${cnt} - 3) < 0.5, if(${k} < 1.5, ${k}, 0), if(abs(${cnt} - 4) < 0.5, mod(${k}, 2), ${k}))
          wp.${n} = if(${cnt} < 1.5, 0.6667, 0.5)
          hp.${n} = if(abs(${cnt} - 3) < 0.5, 0.6667, if(${cnt} > 2.5, 0.5, 1))
          nhold = 0
      }''
  )}

      // the window that just opened, and the one that had the keyboard before it
      fact nw = -1
      fact nwt = 0
      // nwl, nhold: the last window placed, held while the auto shape is made
      // around it. Making it lets go (above); this, if none is made.
      fact nwl = -1
      fact nhold = 0
      on still nhold for 60ms while nhold > 0.5 { nhold = 0 }
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
      let n.ok = nw >= 0 and n.from >= 0 and n.from != nw and ${pick "n.fk" (j: "win.${j}.place")} >= 0 and ${
        pick "n.fk" (j: "win.${j}.screen")
      } == n.sc and ${pick "n.fk" (j: "win.${j}.pool")} == n.pool
      let n.frpos = ${pick "n.fk" (j: "rpos.${j}")}
      let n.fcpos = ${pick "n.fk" (j: "cpos.${j}")}
      let n.fhp = ${pick "n.fk" (j: "r.hp.${j}")}
      // A row three wide is full while the monitor has fewer than seven
      // tiles: the next window starts a row of its own below it instead.
      let n.rc = ${sum (j: "if(win.${S j}.open and win.${S j}.place >= 0 and win.${S j}.screen == n.sc and win.${S j}.pool == n.pool and rpos.${S j} == n.frpos and nw != ${S j}, 1, 0)")}
      let n.m = ${sum (j: "if(win.${S j}.open and win.${S j}.place >= 0 and win.${S j}.screen == n.sc and win.${S j}.pool == n.pool and nw != ${S j}, 1, 0)")} + 1
      let n.newrow = n.ok and n.rc > 2.5 and n.m < 6.5
      on place_new {
          nwl = nw
          nhold = if(${pickMon "n.sc" (s: "auto.${s}")} and n.m > 1.5 and n.m < 3.5, 1, 0)
          nw = -1
          newpan = 1
      }

      // A focused window that closes hands the keyboard to the one taking its
      // place: the next in its row, else the one before it, else the nearest
      // window in the nearest row. A closed slot keeps its monitor, workspace
      // and place, so they are read as it closes.
      fact cl.sc = 0
      fact cl.pool = 0
      fact cl.rpos = 0
      fact cl.cpos = 0
      fact cl.pending = false
  ${perSlot (
    i:
    let
      n = S i;
    in
    ''
      on change win.${n}.open while not win.${n}.open and (lf == ${n} or lf.prev == ${n}) {
          cl.sc = win.${n}.screen
          cl.pool = win.${n}.pool
          cl.rpos = rpos.${n}
          cl.cpos = cpos.${n}
          cl.pending = true
      }''
  )}
      on still win.focus for 50ms while cl.pending and cl.min < 100000000 {
          pan = 1
          focus win(cl.target)
          cl.pending = false
      }
      on still win.focus for 50ms while cl.pending and cl.min >= 100000000 { cl.pending = false }
      // The camera goes straight to it, not by way of whatever pleamar-wm
      // focused in the meantime.
  ${perMon (
    s:
    let
      n = S s;
    in
    ''
      on change cl.pending while cl.pending and cl.min < 100000000 and cl.sc == ${n} {
          cam.a.${n} = cl.target
          ofs.x.${n} = 0
          ofs.y.${n} = 0
      }
      on change cl.target while cl.pending and cl.min < 100000000 and cl.sc == ${n} { cam.a.${n} = cl.target }''
  )}

      // the window being dragged, and a resize of it: its width and its
      // row's height, as shares
      let d = max(dslot, 0)
      let d.sc = ${pick "d" (j: "win.${j}.screen")}
      let d.pool = ${pick "d" (j: "win.${j}.pool")}
      let d.rpos = ${pick "d" (j: "rpos.${j}")}
      fact rsw = 0.5
      fact rsh = 1
  ${perSlot (
    j:
    "    on change rsh while dmode == 3 and dslot >= 0 and win.${S j}.place >= 0 and win.${S j}.screen == d.sc and win.${S j}.pool == d.pool and rpos.${S j} == d.rpos { hp.${S j} = rsh }"
  )}
  ${perMon (s: ''
    on change rsw while dmode == 3 and dslot >= 0 and d.sc == ${S s} { auto.${S s} = false }
    on change rsh while dmode == 3 and dslot >= 0 and d.sc == ${S s} { auto.${S s} = false }'')}
  }
''
