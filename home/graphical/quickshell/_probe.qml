import QtQuick
import Quickshell

ShellRoot {
  FloatingWindow {
    id: w
    implicitWidth: 300; implicitHeight: 110; color: "#161616"
    Row {
      anchors.centerIn: parent
      spacing: 24
      Repeater {
        model: [0xeb99, 0xf0159, 0xf467, 0xf4bc]
        Column {
          required property int modelData
          spacing: 4
          Text { font.family: "FiraCode Nerd Font"; font.pixelSize: 40; color: "#f4f4f4"
                 text: String.fromCodePoint(modelData) }
          Text { font.pixelSize: 10; color: "#8d8d8d"; text: modelData.toString(16) }
        }
      }
    }
    Timer { running: true; interval: 1200
      onTriggered: { w.contentItem.grabToImage(function(r) { r.saveToFile("/tmp/glyphs.png"); Qt.quit(); }); } }
  }
}
