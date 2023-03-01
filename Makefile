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
	.config/kitty/kitty.conf \
	.config/helix/config.toml \
	.config/micro/settings.json \
	.config/hypr \
	.config/waybar \
	.config/deadd

pkgs= \
  kitty \
  git-delta \
  zsh \
  starship \
  helix \
  bat \
  exa \
  nodejs \
  yarn \
  rofi \
  rustup \
  slop \
  imagemagick \
  zsh-autocomplete-git \
  zsh-autosuggestions \
  hyprland-nvidia-hidpi-git \
  waybar-hyprland \
  wofi \
  ttf-firacode-nerd-font \
  deadd-notification-center-bin

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
	cd dots && cp -rv . $$HOME/

save: ascii
	# Saving dotfiles
	@for path in ${configs}; do to=$$HOME/$$path; \
		if [[ -f "$$to" ]]; then \
			\cp -v "$$to" "./dots/$$path"; \
		elif [[ -d "$$to" ]]; then \
			\cp -rv $$to/* "./dots/$$path/"; \
		fi \
	done
