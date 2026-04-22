# Contributing

## Adding a new post

To add a blog post, you must:

1. Branch off of `main`
2. Create a new markdown file in `content/posts/`:
   ```
   content/posts/your-post-title.md
   ```
3. Add frontmatter at the top:
   ```toml
   +++
   title = "Your Post Title"
   date = 2024-01-15
   description = "Brief description for SEO (max 160 chars)"

   [taxonomies]
   tags = ["rust", "cryptography"] # grep or ask claude for existing tags

   [extra]
   authors = ["Author Name"]
   feature_image = "/images/your-image.png"  # optional
   math = true  # optional, enables KaTeX for LaTeX math
   +++
   ```
4. Write your content in markdown below the frontmatter.

### Math support

For posts with mathematical notation, set `math = true` in `[extra]`. Then use:
- Inline math: `$E = mc^2$`
- Display math: `$$\sum_{i=1}^n i = \frac{n(n+1)}{2}$$`

### Images

Place images in `static/images/` and reference them with absolute paths:
```markdown
![Alt text](/images/your-image.png)
```

- Choose a background image by prompting claude for a classical or renaissance painting that hasn't been used yet. 
- If your post contains many images consider creating a subfolder for them. 

5. Commit and create a PR.
6. Have two reviewers approve the PR. 
7. Merge. Once merged to main the [deploy workflow](https://github.com/lambdaclass/lambdaclass_blog/blob/main/.github/workflows/deploy.yml) will run and render and deploy the site to Github pages. 
   The site build and deploy will also update the [RSS feed](https://lambdaclass.github.io/lambdaclass_blog/rss.xml). 
   Buttondown is [configured](https://buttondown.com/feeds) to read this feed and send an email to subscribers when it is updated. How this works is explained [here](https://docs.buttondown.com/rss-to-email).