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
  .Xresources \
  .gitconfig \
  .zshrc \
  .scripts \
  .config/term.png \
  .config/starship.toml \
  .config/micro/settings.json \
  .config/mako/config \
  .config/waybar \
  .config/wofi \
  .config/wezterm \
  .config/nvim/{init.lua,lua} \
  .config/sway

pkgs= \
  swayfx \
  waybar \
  wofi \
  wezterm \
  git-delta \
  zsh \
  starship \
  neovim \
  bat \
  eza \
  rustup \
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
