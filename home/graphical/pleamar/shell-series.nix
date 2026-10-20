# The system page's charts, unrolled over their samples. A path's steps read
# facts, not model records, so each series is one fact per sample (written by
# logic/info.luau, already scaled 0 to 1 against the window's range), and
# each chart is a component whose path walks them.
{
  lib,
  samples ? 60,
}:
let
  inherit (lib) concatMapStringsSep range;
  S = toString;
  last = samples - 1;
  # c cpu, m memory, g gpu; r and w disk read and write, d and u network
  # down and up
  series = [
    "c"
    "m"
    "g"
    "r"
    "w"
    "d"
    "u"
  ];
  # Samples before inf.s.first have not been taken yet: they collapse onto
  # the first one, so the line grows in from the right as the window fills.
  px = k: "w * max(${S k}, inf.s.first) / ${S last}";
  points = s: concatMapStringsSep "\n" (k: "        line ${px k}, dir * h * inf.s.${s}.${S k}") (range 1 last);

  # A line from its baseline at (x, y), growing up (dir -1) or down (dir 1),
  # over a faint fill back to the baseline.
  chart = s: ''
    component InfLine_${s}(x: number, y: number, w: number, h: number, tone: color, dir: number = -1) {
        path {
            at: x, y
            color: tone
            opacity: 14%
            move ${px 0}, 0
            line ${px 0}, dir * h * inf.s.${s}.0
    ${points s}
            line w, 0
            close
        }
        path {
            at: x, y
            stroke: 1.6
            color: tone
            move ${px 0}, dir * h * inf.s.${s}.0
    ${points s}
        }
    }
  '';
in
''
  // Generated from home/graphical/pleamar/shell-series.nix.
  part InfoSeries {
      fact inf.s.first = ${S samples}
  ${concatMapStringsSep "\n" (
    s: concatMapStringsSep "\n" (k: "    fact inf.s.${s}.${S k} = 0") (range 0 last)
  ) series}

  ${concatMapStringsSep "\n" chart series}
  }
''
