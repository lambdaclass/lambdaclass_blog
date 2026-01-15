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

## Contributing

### Adding a new post

1. Create a new markdown file in `content/posts/`:
   ```
   content/posts/your-post-title.md
   ```

2. Add frontmatter at the top:
   ```toml
   +++
   title = "Your Post Title"
   date = 2024-01-15
   description = "Brief description for SEO (max 160 chars)"

   [taxonomies]
   tags = ["rust", "cryptography"]

   [extra]
   authors = ["Author Name"]
   feature_image = "/images/your-image.png"  # optional
   math = true  # optional, enables KaTeX for LaTeX math
   +++
   ```

3. Write your content in markdown below the frontmatter.

### Math support

For posts with mathematical notation, set `math = true` in `[extra]`. Then use:
- Inline math: `$E = mc^2$`
- Display math: `$$\sum_{i=1}^n i = \frac{n(n+1)}{2}$$`

### Images

Place images in `static/images/` and reference them with absolute paths:
```markdown
![Alt text](/images/your-image.png)
```
