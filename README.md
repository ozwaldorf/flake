# dotfiles

📷 [screens](#--screens)
📝 [info](#--info)
💻 [usage](#--usage) 

---

## ↛ 📷 screens

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/71a05127-5489-44f0-8314-4229465333f8)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/1bc53bf1-5a1b-40b3-8fd1-c77647fe2d38)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/795ed968-cb9f-48d3-be6a-0b3b76af8e4c)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/3175d137-88a1-4992-9c37-c30f6c6d5a56)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/1bb1fbdb-c3ff-43f1-a2d2-09caaeffdf6f)

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
