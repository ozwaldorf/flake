PHONY: update ags

update:
	nix flake update ./neovim
	nix flake update .

ags:
	inotifywait -me modify home/ags | \
		while read; do \
			ags -q; ags -c ./home/ags/config.js & \
		done
