# Custom Jekyll front matter for Sublime Text (eve.gd)

*Set up 2026-08-25.*

Home Manager now manages all of this (`home/martin/sublime.nix` in the nixos
repo): the Jekyll plugin is store-pinned (no Package Control involved), and
the override plugin plus this README are installed into `Packages/User/` as
read-only symlinks. To change the plugin, edit the copy in
`home/martin/sublime/` and rebuild — not the deployed file.

## What this is

`jekyll_eve_frontmatter.py` (in this directory, `~/.config/sublime-text/Packages/User/`)
customises the front matter that the **sublime-jekyll** plugin inserts when
creating a new blog post or draft.

Running **"Jekyll: New Post"** or **"Jekyll: New Draft"** from the command
palette now prompts for the title, then for 1–3 categories (see below), and
produces:

```yaml
---
title: "The title you typed"        # quoted, safely escaped
layout: post
date: 2026-08-25                     # today's date, YYYY-MM-DD
doi: https://doi.org/10.59348/xxxxx-xxxxx   # minted at creation time
categories:                          # picked from the canonical taxonomy
- Open Access
- Publishing Technology
image:
  credit: "Image Credit Here"        # literal placeholders, filled in later
  creditlink: "https://url.com"
  feature: image.png
  title: "Place image title here"
---
```

## Controlled category vocabulary

The blog's 24 canonical categories live in `_categorization/taxonomy.yml` in
the blog repo (found by walking up from the saved file or the configured
posts path, so it follows whichever checkout the plugin points at). Three
mechanisms keep front matter inside that vocabulary:

1. **Picker on new posts/drafts.** After the title prompt, a quick panel
   offers only the canonical names (pick up to 3, most salient first). Free
   text cannot be typed into the panel; the explicit escape hatch is the
   "＋ New category (not in taxonomy)…" item, which opens an input panel and
   reminds you to add the name to `taxonomy.yml` as well. Esc finishes with
   whatever is picked so far (possibly nothing — the save validator nags).
2. **"Jekyll: Set Post Categories"** in the command palette runs the same
   picker on the currently open post and inserts/replaces its `categories:`
   block in place.
3. **Save validator.** Saving any `.md`/`.markdown` file under `_posts/` or
   `_drafts/` checks its categories against the taxonomy: unknown names get
   a modal error dialog; a missing block or more than 3 categories only gets
   a status-bar nag (so drafting isn't interrupted).

If `taxonomy.yml` cannot be found (e.g. a checkout that predates it), all
three degrade gracefully: posts are created without categories and a
status-bar message says why.

## How it works

- The stock plugin (`Packages/Jekyll/jekyll.py`) hard-codes its front matter
  in `create_post_frontmatter()` and inserts it via Sublime's `insert_snippet`.
- Sublime loads `Packages/User` **last**, so re-declaring the
  `JekyllNewPostCommand` / `JekyllNewDraftCommand` classes here re-registers
  the `jekyll_new_post` and `jekyll_new_draft` commands, replacing the stock
  ones. The Jekyll package itself is untouched and survives package updates.
- The DOI comes from running `commonmeta encode 10.59348` at post-creation
  time. **Gotcha:** commonmeta prints the DOI to *stderr*, so the plugin
  captures both streams and picks out the `https://doi.org/...` line. If
  minting fails (binary missing, timeout), the `doi:` field is left blank and
  a status-bar message says so.
- Title and date values are YAML-quoted and then snippet-escaped (`\` and `$`)
  so titles containing quotes or `$` can't corrupt the YAML or the snippet.

## How each file persists (all via `home/martin/sublime.nix`)

| File | Role | Managed as |
|------|------|-----------|
| `~/.config/sublime-text/Packages/User/jekyll_eve_frontmatter.py` | the override plugin (the important one) | symlink to `home/martin/sublime/jekyll_eve_frontmatter.py` |
| `~/.config/sublime-text/Packages/User/Jekyll.sublime-settings` | posts/drafts/templates paths for the blog | generated from settings inline in `sublime.nix` |
| `~/.config/sublime-text/Packages/Jekyll/` | the upstream sublime-jekyll package | store-pinned release tarball, fetched by hash |

The `commonmeta` binary must be on PATH (from the system profile:
`/run/current-system/sw/bin/commonmeta`, built in `modules/nixos/packages.nix`).

## Misc notes

- The extensionless files in the blog repo's `_templates/` (`post`, `page`,
  `archive`) are Octopress-era leftovers; sublime-jekyll never offers them
  (it filters templates by file extension) and their `{{ ... }}` placeholders
  are not understood by the plugin. Safe to delete.
- The pure logic (escaping, DOI parsing, front-matter assembly, taxonomy
  parsing, category extraction/replacement) is importable without Sublime;
  run the tests with `python3 -m unittest test_jekyll_eve_frontmatter` from
  `home/martin/sublime/` in the nixos repo.
