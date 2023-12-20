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
  .config/wezterm \
  .config/nvim/{init.lua,lua} \
  .config/hypr \
	.config/sway \
	.config/ags

pkgs= \
  hyprland \
	swayfx \
  aylars-gtk-shell \
  swww \
  wezterm \
  zsh \
	zsh-autosuggestions \
  zsh-autocomplete-git \
	manydots-magic \
  starship \
  git-delta \
  neovim \
  bat \
  eza \
  rustup \
  punfetch-bin \
  lutgen-bin

ascii:
	@echo "$$ASCII"

deps: ascii
	@which yay || { echo "yay is not installed"; exit 1; }
	# Install packages
	yay -S --needed --noconfirm ${pkgs}

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
