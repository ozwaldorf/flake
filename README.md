# dotfiles

📷 [screens](#--screens)
📝 [info](#--info)
💻 [usage](#--usage) 

---

## ↛ 📷 screens

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/22588535-8a2c-45c1-aa31-fe8657bca242)

---

## ↛ 📝 info

### desktop

```
OS: Arch Linux
Compositor: Hyprland
Wallpaper: swww
Bar: AGS
Notification Daemon: AGS
Application Launcher: AGS
GTK Theme: Carburetor (Catppuccin Mocha Blue, patched)
Icon Theme: Papyrus
Font: Berkeley Mono
```

### terminal

```
Terminal: Wezterm
Shell: Zsh 5.9
Fetch: Punfetch + Onefetch
Prompt: Starship
Editor: Neovim
Git Diff: Delta
```

### apps

```
Browser: Firefox
File Manager: Nautilus
Volume Control: Pavucontrol
Disk Manager: Gnome Disks
```

---

## ↛ 💻 usage

> Note: you will need `make` and `yay` installed

clone and enter the repo:

```sh
git clone https://github.com/ozwaldorf/dotfiles && cd dotfiles
```

install packages:
```sh
make deps
```

install dotfiles to system:

> NOTE: My .gitconfig is included, so be sure to edit it with your info, or else you'll commit stuff as me!

```sh
make install
```

transparent gtk mod:

```sh 
make transparent-gtk
```

backup/save configuration from system:

```sh
make save
```
