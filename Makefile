.PHONY: build dev clean help

build:
	nix develop --command zola build

dev:
	nix develop --command zola serve

clean:
	rm -rf public/

help:
	@echo "Available targets:"
	@echo "  make build  - Build the site"
	@echo "  make dev    - Start development server"
	@echo "  make clean  - Remove build artifacts"
	@echo "  make help   - Show this help message"
