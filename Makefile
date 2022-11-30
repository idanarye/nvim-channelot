.PHONY: docs

docs:
	mkdir -p doc
	lemmy-help --prefix-func lua/channelot/init.lua | tee doc/channelot.txt
