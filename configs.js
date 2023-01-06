#!/bin/node
const fs = require("fs-extra");
const path = require("path");
const argv = require("yargs");

const dir = "src";

const config = {
  files: [
    ".zshrc",
    ".gitconfig",
    ".config/starship.toml",
    ".config/picom.conf",
    ".config/helix/config.toml",
    ".config/micro/settings.json",
  ],
  folders: [".config/i3/", ".config/kitty/"],
};

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
  config.files.forEach((file) => {
    copy(
      path.join(process.env.HOME, file),
      path.join(__dirname, dir, file),
      file
    );
  });

  config.folders.forEach((folder) => {
    copy(
      path.join(process.env.HOME, folder),
      path.join(__dirname, dir, folder),
      folder
    );
  });
});

argv.command("install", "install saved dotfiles", () => {
  console.log("installing config files --\n");
  config.files.forEach((file) => {
    copy(
      path.join(__dirname, dir, file),
      path.join(process.env.HOME, file),
      file
    );
  });

  config.folders.forEach((folder) => {
    copy(
      path.join(__dirname, dir, folder),
      path.join(process.env.HOME, folder),
      folder
    );
  });
}).argv;
