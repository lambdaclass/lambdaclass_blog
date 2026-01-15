.PHONY: build dev clean minify help

build:
	nix develop --command zola build
	$(MAKE) minify

dev:
	nix develop --command zola serve

minify:
	nix develop --command sh -c 'find public -name "*.css" -exec lightningcss --minify {} -o {} \;'
	nix develop --command sh -c 'find public -name "*.js" ! -name "*.min.js" -exec terser {} -o {} -c -m \;'

clean:
	rm -rf public/

help:
	@echo "Available targets:"
	@echo "  make build  - Build the site with minified assets"
	@echo "  make dev    - Start development server"
	@echo "  make minify - Minify CSS and JS in public/"
	@echo "  make clean  - Remove build artifacts"
	@echo "  make help   - Show this help message"
