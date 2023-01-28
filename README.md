# dotfiles



---

🖹 [info](#--info)
💻 [usage](#--usage) 
📷 [screens](#--screens)

---


## ↛ 📷 screens

![image](https://user-images.githubusercontent.com/8976745/215278149-ec3d08d1-3f22-48ae-91f0-ea6eb080c8c6.png)
![image](https://user-images.githubusercontent.com/8976745/215278576-f34f6d19-97fd-44aa-99e8-6632cd7aa121.png)


---

## ↛ 🖹 info

### desktop

```
OS: Manjaro 21.2.6 Qonos (community i3)
Compositor: hyprland
Bar: waybar
GTK Theme: dracula [GTK2/3]
Icon Theme: dracula-icons
Font: FiraCode Nerd Font
```

### terminal
```
Terminal: kitty
Shell: vanilla zsh 5.9
Fetch: punfetch + onefetch
Prompt: starship
Git Diff-Viewer: delta
```

### apps
```
Browser: brave
Editor: clion / micro / helix
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
