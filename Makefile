# Simple test runner + install for unlock briefing
.PHONY: test load all setup dry-run

test:
	lua tests/test_briefing.lua

load:
	lua tests/test_load.lua

all: test load

# 按 setup.config 安装 Hammerspoon 并部署到 ~/.hammerspoon（可复现）
setup:
	./setup.sh

dry-run:
	./setup.sh --dry-run
