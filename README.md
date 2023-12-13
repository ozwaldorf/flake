# dotfiles

📷 [screens](#--screens)
📝 [info](#--info)
💻 [usage](#--usage) 

---

## ↛ 📷 screens

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/566e71f5-5d54-4506-81af-4482efa2e014)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/6c2f0440-c902-449d-b5a9-65d135c4b8b4)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/0bfdddc4-8297-470c-b396-5bb47660244e)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/fec1794b-5d9c-4ae0-8e9b-b336e34e00b2)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/6fda9169-1864-479b-a3ba-e7c90c41087d)

---

## ↛ 📝 info

### desktop

```
OS: Arch Linux
Compositor: SwayFx
Bar: Waybar
GTK Theme: Carburetor (Catppuccin Mocha Blue, patched)
Icon Theme: Papyrus
Font: Berkeley Mono
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
