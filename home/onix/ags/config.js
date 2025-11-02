import App from "resource:///com/github/Aylur/ags/app.js";
import main from "./src/main.js";

const v = {
  ags: `v${pkg.version}`,
  expected: `v1.7.3`,
};

function mismatch() {
  print(`my config expects ${v.expected}, but your ags is ${v.ags}`);
  App.connect("config-parsed", (app) => app.Quit());
  return {};
}

export default main;
