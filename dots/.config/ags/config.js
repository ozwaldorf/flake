import App from "resource:///com/github/Aylur/ags/app.js";

const v = {
  ags: `v${pkg.version}`,
  expected: `v1.6.3`,
};

function mismatch() {
  print(`my config expects ${v.expected}, but your ags is ${v.ags}`);
  App.connect("config-parsed", (app) => app.Quit());
  return {};
}

export default v.ags === v.expected
  ? (await import("./src/main.js")).default
  : mismatch();
