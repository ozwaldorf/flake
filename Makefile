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
	.config/term.png \
	.config/starship.toml \
	.config/picom.conf \
	.config/kitty/kitty.conf \
	.config/helix/config.toml \
	.config/micro/settings.json \
	.config/i3/config \
	.config/polybar \
	.config/scripts

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
  i3status-rust \
  github-cli \
  rofi \
  rustup

cargo_pkgs= \
	punfetch

ascii:
	@echo "$$ASCII"

deps: ascii
	@which yay || { echo "yay is not installed"; exit 1; }
	# Install packages
	sudo -S yay -S --needed --noconfirm ${pkgs}
	# Check if gh is logged in,
	@if gh auth status &>/dev/null; then \
		# check notifications is installed, or install it \
		gh notifications -help &>/dev/null || gh extension install daniel-leinweber/gh-notifications; \
	else \
		echo "gh is not logged in, please set \"GH_TOKEN\" and \"I3RS_GITHUB_TOKEN\""; \
	fi
	# Verify rustup is setup
	@cargo -V || rustup install stable && rustup default stable
	# Install cargo packages
	cargo install ${cargo_pkgs}

install: ascii
	# Installing dotfiles
	cd dots && cp -rv . $$HOME/
	cp -rv wallpapers $$HOME/Pictures/

save: ascii
	# Saving dotfiles
	@for path in ${configs}; do to=$$HOME/$$path; \
		if [[ -f "$$to" ]]; then \
			\cp -v "$$to" "./dots/$$path"; \
		elif [[ -d "$$to" ]]; then \
			\cp -rv $$to/* "./dots/$$path/"; \
		fi \
	done
	cp -rv $$HOME/Pictures/wallpapers .
