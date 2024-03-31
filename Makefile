PHONY: ags

ags:
	inotifywait -me modify home/ags | \
		while read; do \
			ags -q; ags -c ./home/ags/config.js & \
		done
