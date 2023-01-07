#!/bin/node
const fs = require("fs-extra");
const path = require("path");
const argv = require("yargs");

const backupDir = "src";

const items = [
  ".zshrc",
  ".Xresources",
  ".gitconfig",
  ".config/starship.toml",
  ".config/picom.conf",
  ".config/helix/config.toml",
  ".config/micro/settings.json",
  ".config/i3/", ".config/i3status-rust", ".config/kitty/", ".config/rofi/"
]

const copy = (fromPath, toPath, name) => {
  fs.copy(fromPath, toPath, {
    overwrite: true,
  })
    .then(() => {
      console.log(`${name} copied`);
    })
    .catch((err) => {
      console.log(`error copying ${name}: ${err}`);
    });
};

argv.command("save", ": save current config files", () => {
  console.log("saving config files --\n");
  items.forEach((item_path) => {
    copy(
      path.join(process.env.HOME, item_path),
      path.join(__dirname, backupDir, item_path),
      item_path
    );
  });
});

argv.command("install", "install saved dotfiles", () => {
  console.log("installing config files --\n");
  items.forEach((item_path) => {
    copy(
      path.join(__dirname, backupDir, item_path),
      path.join(process.env.HOME, item_path),
      item_path
    );
  });
}).argv;
