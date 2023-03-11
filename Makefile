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
	.config/hypr \
	.config/waybar \
	.config/wofi \
	.config/deadd \
	.config/wezterm \
	.config/nvim

pkgs= \
	hyprland-nvidia-hidpi-git \
  waybar-hyprland \
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
  deadd-notification-center-bin \
	swww \

cargo_pkgs= \
	punfetch

ascii:
	@echo "$$ASCII"

deps: ascii
	@which yay || { echo "yay is not installed"; exit 1; }
	# Install packages
	sudo -S yay -S --needed --noconfirm ${pkgs}
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
