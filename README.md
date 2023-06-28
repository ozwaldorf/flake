# dotfiles

📷 [screens](#--screens)
📝 [info](#--info)
💻 [usage](#--usage) 

---

## ↛ 📷 screens

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/3d8f346c-781e-478b-b7cc-2aab2b7b856d)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/ad07379b-e450-45be-9344-3f00ab124d13)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/95cb3105-4dc2-442b-96ef-6761cc2bb791)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/87d8c0bd-5a6d-4c9b-a806-2a1168268d97)

---

## ↛ 📝 info

### desktop

```
OS: Arch Linux
Compositor: Hyprland
Bar: Waybar
GTK Theme: Catppuccin Mocha Pink (+ transparent mod)
Icon Theme: Papyrus (Catppuccin folders patch)
Font: FiraCode Nerd Font
Notification Daemon: Mako
Application Launcher: Wofi
```

### terminal

```
Terminal: Wezterm
Shell: Zsh 5.9
Fetch: Punfetch + Onefetch
Prompt: Starship
Editor: Nvim
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
