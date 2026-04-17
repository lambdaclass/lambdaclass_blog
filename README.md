# LambdaClass Blog Repository

In this repository you will find all the posts and images from our blog.

## Prerequisites

- [Nix](https://nixos.org/download.html) package manager
- Or [Zola](https://www.getzola.org/documentation/getting-started/installation/) installed directly

## Development

Start the local development server:

```bash
make dev
```

The site will be available at `http://127.0.0.1:1111`.

## Building

Build the static site:

```bash
make build
```

Output goes to the `public/` directory.
