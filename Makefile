.PHONY: build dev

build:
	nix develop --command zola build

dev:
	nix develop --command zola serve
