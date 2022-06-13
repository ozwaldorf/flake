#!/bin/node
const fs = require("fs-extra");
const path = require("path");
const argv = require("yargs");

const config = {
  files: [".zshrc", ".gitconfig", ".config/starship.toml"],
  folders: [".config/i3/", ".config/kitty/", ".config/micro/"],
};

argv.command("save", ": save current config files", () => {
  // Copy files
  config.files.forEach((file) => {
    fs.copy(path.join(process.env.HOME, file), path.join(__dirname, file), {
      overwrite: true,
    })
      .then(() => {
        console.log(`${file} copied`);
      })
      .catch((err) => {
        console.log(`${file}: ${err}`);
      });
  });

  // Copy folders
  config.folders.forEach((folder) => {
    fs.copy(path.join(process.env.HOME, folder), path.join(__dirname, folder), {
      overwrite: true,
    })
      .then(() => {
        console.log(`${folder} copied`);
      })
      .catch((err) => {
        console.log(`${folder}: ${err}`);
      });
  });
});

argv.command("install", "install saved dotfiles", () => {
  // Copy files
  config.files.forEach((file) => {
    fs.copy(path.join(__dirname, file), path.join(process.env.HOME, file))
      .then(() => {
        console.log(`${file} copied`);
      })
      .catch((err) => {
        console.log(`${file}: ${err}`);
      });
  });

  // Copy folders
  config.folders.forEach((folder) => {
    fs.copy(path.join(__dirname, folder), path.join(process.env.HOME, folder))
      .then(() => {
        console.log(`${folder} copied`);
      })
      .catch((err) => {
        console.log(`${folder}: ${err}`);
      });
  });
}).argv;
