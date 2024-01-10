import Widget from "resource:///com/github/Aylur/ags/widget.js";
import Sway from "resource:///com/github/Aylur/ags/service/sway.js";
import * as Utils from "resource:///com/github/Aylur/ags/utils.js";
import options from "../../options.js";
import { range } from "../../utils.js";


const dispatch = (arg) => Utils.execAsync(`swaymsg workspace ${arg}`);

const Workspaces = () => {
  const ws = options.workspaces.value || 20;
  return Widget.Box({
    children: range(ws).map((i) =>
      Widget.Button({
        setup: (btn) => (btn.id = i),
        on_clicked: () => dispatch(i),
        child: Widget.Label({
          label: `${i}`,
          class_name: "indicator",
          vpack: "center",
        }),
        connections: [
          [
            Sway,
            (btn) => {
              btn.toggleClassName("active", Sway.active.workspace.name == i);
              btn.toggleClassName(
                "occupied",
                Sway.getWorkspace(`${i}`)?.nodes.length > 0,
              );
            },
          ],
        ],
      })
    ),
    connections: [
      [
        Sway.active.workspace,
        (box) =>
          box.children.map((btn) => {
            btn.visible = Sway.workspaces.some(
              (ws) => ws.name == btn.id,
            );
          }),
      ],
    ],
  });
};

export default () =>
  Widget.EventBox({
    class_name: "workspaces panel-button",
    child: Widget.Box({
      // its nested like this to keep it consistent with other PanelButton widgets
      child: Widget.EventBox({
        on_scroll_up: () => dispatch("next"),
        on_scroll_down: () => dispatch("prev"),
        class_name: "eventbox",
        binds: [["child", options.workspaces, "value", Workspaces]],
      }),
    }),
  });
