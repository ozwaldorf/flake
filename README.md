# dotfiles

📷 [screens](#--screens)
🖹 [info](#--info)
💻 [usage](#--usage) 

---

## ↛ 📷 screens

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/c2881497-79e9-45c8-809d-e930d8d6089d)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/acf71d26-b484-4e21-893d-da51365d7e96)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/bb9df7a1-7976-42ef-bc78-c0fb9a49a1c4)

![image](https://github.com/ozwaldorf/dotfiles/assets/8976745/4c85f4af-21fa-4682-b02b-6ed5fde01cbe)

---

## ↛ 🖹 info

### desktop

```
OS: Arch Linux 
Compositor: Hyprland
Bar: waybar
GTK Theme: catppuccin (+ transparent mod)
Icon Theme: Papyrus (catppuccin folders patch)
Font: FiraCode Nerd Font
```

### terminal

```
Terminal: wezterm
Shell: zsh 5.9
Fetch: punfetch + onefetch
Prompt: starship
Git Diff: delta
```

### apps

```
Browser: brave
Editor: nvim
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
