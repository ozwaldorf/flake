.PHONY: deps save install

define ASCII

.  ───── oz's ─────  .
┌┬┐┌─┐┌┬┐┌─┐┬┬  ┌─┐┌─┐
 │││ │ │ ├┤ ││  ├┤ └─┐
─┴┘└─┘ ┴ └  ┴┴─┘└─┘└─┘
·  ───── ·  · ─────  ·

endef
export ASCII

configs= \
	.wallpapers \
	.Xresources \
	.gitconfig \
	.zshrc \
	.config/term.png \
	.config/starship.toml \
	.config/helix/config.toml \
	.config/micro/settings.json \
	.config/mako/config \
	.config/hypr \
	.config/waybar \
	.config/wofi \
	.config/deadd \
	.config/wezterm \
	.config/nvim/{init.lua,lua}

pkgs= \
	hyprland-git \
  waybar-hyprland-cava-git \
  wofi \
  wezterm \
  git-delta \
  zsh \
  starship \
  helix \
	neovim \
  bat \
  exa \
  nodejs \
  yarn \
  rustup \
  slop \
  imagemagick \
  zsh-autocomplete-git \
  zsh-autosuggestions \
  ttf-firacode-nerd \
  mako \
	swww \
	punfetch-bin \
	lutgen-bin

ascii:
	@echo "$$ASCII"

deps: ascii
	@which yay || { echo "yay is not installed"; exit 1; }
	# Install packages
	yay -S --needed --noconfirm ${pkgs}
	# Verify rustup is setup
	@cargo -V || rustup install stable && rustup default stable
	# Install cargo packages
	cargo install ${cargo_pkgs}

install: ascii
	# Installing dotfiles
	cd dots && \cp -rv . $$HOME/

save: ascii
	# Saving dotfiles
	@for path in ${configs}; do to=$$HOME/$$path; \
		if [[ -f "$$to" ]]; then \
			mkdir -p "./dots/$$(dirname $$path)"; \
			\cp -v "$$to" "./dots/$$path"; \
		elif [[ -d "$$to" ]]; then \
			mkdir -p "./dots/$$path"; \
			\cp -rv $$to/* "./dots/$$path/"; \
		fi \
	done

transparent-gtk:
	@echo "Replacing catppuccin colors with transparent variants"
	cd /usr/share/themes/$$GTK_THEME && \
		sudo find . -type f -name "*.css" -exec sed -i 's/#1e1e2e/rgba(30, 30, 46, 0.7)/g' {} + && \
		sudo find . -type f -name "*.css" -exec sed -i 's/#181825/rgba(24, 24, 37, 0.7)/g' {} + && \
		sudo find . -type f -name "*.css" -exec sed -i 's/#11111b/rgba(17, 17, 27, 0.7)/g' {} +
