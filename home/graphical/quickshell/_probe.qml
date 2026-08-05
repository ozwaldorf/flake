import QtQuick
import Quickshell

ShellRoot {
  Component.onCompleted: {
    const step = 0.05;
    function apply(v, delta) { return Math.max(0, Math.min(1, v + delta / 120 * step)); }
    console.log("from 0.50, one notch up  (+120):", apply(0.50, 120).toFixed(4));
    console.log("from 0.50, one notch down(-120):", apply(0.50, -120).toFixed(4));
    console.log("from 0.98, one notch up:        ", apply(0.98, 120).toFixed(4), "(clamps at 1)");
    console.log("from 0.02, one notch down:      ", apply(0.02, -120).toFixed(4), "(clamps at 0)");
    console.log("touchpad fraction (+40):        ", apply(0.50, 40).toFixed(4));
    let v = 0.5; for (let i=0;i<3;i++) v = apply(v, 40);
    console.log("three +40 fractions accumulate: ", v.toFixed(4), "(= one full notch)");
    Qt.quit();
  }
}
