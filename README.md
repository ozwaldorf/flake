# dotfiles

🖹 [info](#--info)
💻 [usage](#--usage) 
📷 [screens](#--screens)

---

## ↛ 📷 screens

![image](https://user-images.githubusercontent.com/8976745/226779414-11b5d8be-1f89-40c7-b0e4-c1a022bd954f.png)

![image](https://user-images.githubusercontent.com/8976745/229902601-83d18d4b-8715-44af-b848-eac1a441ac41.png)
---

## ↛ 🖹 info

### desktop

```
OS: Arch Linux 
Compositor: Hyprland
Bar: waybar
GTK Theme: catppuccin
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

backup/save configuration from system:

```sh
make save
```
