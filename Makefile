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
	.zshrc \
	.Xresources \
	.gitconfig \
	.config/starship.toml \
	.config/picom.conf \
	.config/helix/config.toml \
	.config/micro/settings.json \
	.config/i3 \
	.config/i3status-rust \
	.config/kitty \
	.config/rofi

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
  rofi

ascii:
	@echo "$$ASCII"

deps: ascii
	@which yay || { echo "yay is not installed"; exit 1; }
	# Install packages
	sudo -S yay -S --needed --noconfirm ${pkgs}
	# Check if gh is logged in,
	if gh auth status &>/dev/null; then
		# check notifications is installed, or install it
		gh notifications -help &>/dev/null || gh extension install daniel-leinweber/gh-notifications
	else
		@echo "gh is not logged in, please set \"GH_TOKEN\" and \"I3RS_GITHUB_TOKEN\""
	fi

install: ascii
	# Installing dotfiles
	GLOBIGNORE='.:..' cp -rv ./dots/$(.*) $$HOME

save: ascii
	# Saving dotfiles
	@for path in ${configs}; do to=$$HOME/$$path; \
		if [[ -f "$$to" ]]; then \
			\cp -v "$$to" "./dots/$$path"; \
		elif [[ -d "$$to" ]]; then \
			\cp -rv $$to/* "./dots/$$path/"; \
		fi \
	done
