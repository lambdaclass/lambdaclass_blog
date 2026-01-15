{
  description = "LambdaClass Blog - A Zola static site";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zola
            lightningcss
            nodePackages.terser
          ];

          shellHook = ''
            echo "LambdaClass Blog development environment"
            echo "Zola version: $(zola --version)"
            echo ""
            echo "Available commands:"
            echo "  make build  - Build the site"
            echo "  make serve  - Start development server"
            echo "  make clean  - Remove build artifacts"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          pname = "lambdaclass-blog";
          version = "1.0.0";
          src = ./.;

          nativeBuildInputs = with pkgs; [ zola lightningcss nodePackages.terser findutils ];

          buildPhase = ''
            zola build
            # Minify CSS
            find public -name "*.css" -exec lightningcss --minify {} -o {} \;
            # Minify JS (excluding already minified files)
            find public -name "*.js" ! -name "*.min.js" -exec terser {} -o {} -c -m \;
          '';

          installPhase = ''
            mkdir -p $out
            cp -r public/* $out/
          '';
        };
      }
    );
}
