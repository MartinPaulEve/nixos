"""Custom front matter for the sublime-jekyll "New Post" command.

Overrides the stock `jekyll_new_post` command (Packages/User loads after
Packages/Jekyll, so the re-registered command wins) so that a new post is
created with eve.gd's full front matter: quoted title, today's date, a DOI
minted by `commonmeta encode 10.59348`, and the literal image placeholder
block.

The pure builders (no Sublime dependency) live at module level so they can
be unit-tested outside the plugin host.
"""

import re
import subprocess
from datetime import datetime

DOI_COMMAND = ["commonmeta", "encode", "10.59348"]
DOI_TIMEOUT_SECONDS = 10


def snippet_escape(text):
    """Escape a literal value for use inside a Sublime insert_snippet body."""
    return text.replace("\\", "\\\\").replace("$", "\\$")


def yaml_quote(text):
    """Return text as a double-quoted YAML scalar."""
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


# commonmeta prints the minted DOI to stderr, so capture both streams.
def _run_doi_command(cmd, timeout):
    return subprocess.check_output(
        cmd, timeout=timeout, universal_newlines=True,
        stderr=subprocess.STDOUT
    )


def fetch_doi(runner=_run_doi_command):
    """Mint a DOI via commonmeta; return '' on any failure."""
    try:
        output = runner(DOI_COMMAND, timeout=DOI_TIMEOUT_SECONDS)
    except Exception:
        return ""
    for line in output.splitlines():
        if line.strip().startswith("https://doi.org/"):
            return line.strip()
    return ""


def build_frontmatter(title, date_str, doi, categories=()):
    """Assemble the full front matter snippet string."""
    return (
        "---\n"
        "title: " + snippet_escape(yaml_quote(title)) + "\n"
        "layout: post\n"
        "date: " + snippet_escape(date_str) + "\n"
        "doi: " + snippet_escape(doi) + "\n"
        + snippet_escape(build_categories_block(list(categories)))
        + "image:\n"
        '  credit: "Image Credit Here"\n'
        '  creditlink: "https://url.com"\n'
        "  feature: image.png\n"
        '  title: "Place image title here"\n'
        "---\n"
        "$0"
    )


# The front matter is the block between an opening `---` on line one and the
# next line that is exactly `---`; group(1) captures the inside (with its
# trailing newline), so replacements can splice around it.
_FRONT_MATTER_RE = re.compile(r"\A---[ \t]*\n(.*?)^---[ \t]*$", re.S | re.M)

# The `categories:` key line plus every consecutive `- item` line under it.
_CATEGORIES_BLOCK_RE = re.compile(r"^categories:[^\n]*\n(?:[ \t]*-[^\n]*\n?)*", re.M)


def _strip_yaml_quotes(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def parse_taxonomy_names(taxonomy_yaml):
    """Return the canonical category names, in order, from taxonomy.yml text."""
    names = []
    for line in taxonomy_yaml.splitlines():
        match = re.match(r"\s*-\s+name:\s*(.+?)\s*$", line)
        if match:
            names.append(_strip_yaml_quotes(match.group(1)))
    return names


def build_categories_block(categories):
    """Return a plain YAML `categories:` block for the given names."""
    if not categories:
        return ""
    return "categories:\n" + "".join("- " + name + "\n" for name in categories)


def extract_frontmatter_categories(post_text):
    """Return the categories listed in a post's front matter, or None."""
    front = _FRONT_MATTER_RE.match(post_text)
    if not front:
        return None
    fm = front.group(1)
    key = re.search(r"^categories:[ \t]*([^\n]*)$", fm, re.M)
    if not key:
        return None

    inline = key.group(1).strip()
    if inline.startswith("[") and inline.endswith("]"):
        return [
            _strip_yaml_quotes(part)
            for part in inline[1:-1].split(",")
            if part.strip()
        ]

    categories = []
    for line in fm[key.end():].splitlines():
        item = re.match(r"[ \t]*-\s+(.+?)\s*$", line)
        if item:
            categories.append(_strip_yaml_quotes(item.group(1)))
        elif not line.strip() and not categories:
            continue
        else:
            break
    return categories


def replace_categories_block(post_text, categories):
    """Insert, replace, or remove the categories block in a post's front matter."""
    front = _FRONT_MATTER_RE.match(post_text)
    if front is None:
        return None
    fm = front.group(1)
    block = build_categories_block(categories)

    existing = _CATEGORIES_BLOCK_RE.search(fm)
    if existing:
        new_fm = fm[:existing.start()] + block + fm[existing.end():]
    else:
        new_fm = fm + block

    return post_text[:front.start(1)] + new_fm + post_text[front.end(1):]


def find_unknown_categories(categories, canonical_names):
    """Return the categories that are not in the canonical taxonomy, in order."""
    canonical = set(canonical_names)
    return [name for name in categories if name not in canonical]


# ---------------------------------------------------------------------------
# Sublime wiring (skipped when imported outside the plugin host, e.g. tests).
# ---------------------------------------------------------------------------
try:
    from Jekyll.jekyll import (
        JekyllNewPostCommand as _StockNewPost,
        JekyllNewDraftCommand as _StockNewDraft,
        get_setting as _get_setting,
    )
except ImportError:
    _StockNewPost = None
    _StockNewDraft = None

if _StockNewPost:
    import os

    import sublime
    import sublime_plugin

    MAX_CATEGORIES = 3
    _DONE_ITEM = "✔ Done"
    _NEW_ITEM = "＋ New category (not in taxonomy)…"

    def _taxonomy_path_for(start_dir):
        """Walk up from start_dir to find _categorization/taxonomy.yml."""
        directory = start_dir
        while True:
            candidate = os.path.join(
                directory, "_categorization", "taxonomy.yml"
            )
            if os.path.isfile(candidate):
                return candidate
            parent = os.path.dirname(directory)
            if parent == directory:
                return None
            directory = parent

    def _load_taxonomy(window):
        """Return the canonical category names, or None if no taxonomy.yml."""
        view = window.active_view()
        start_dirs = []
        if view and view.file_name():
            start_dirs.append(os.path.dirname(view.file_name()))
        posts_path = _get_setting(view, "jekyll_posts_path", "")
        if posts_path:
            start_dirs.append(posts_path)
        for start in start_dirs:
            path = _taxonomy_path_for(start)
            if path:
                try:
                    with open(path, "r", encoding="utf-8") as handle:
                        names = parse_taxonomy_names(handle.read())
                except OSError:
                    continue
                if names:
                    return names
        return None

    def _pick_categories(window, names, on_complete):
        """Chain quick panels: pick 1-3 taxonomy categories, salient first.

        The quick panel only ever offers canonical names, so free text cannot
        creep in; the one escape hatch is the explicit "New category" item,
        which opens an input panel and nags about updating taxonomy.yml.
        """
        chosen = []

        def show():
            items = []
            if chosen:
                items.append(_DONE_ITEM + " — " + ", ".join(chosen))
            items.append(_NEW_ITEM)
            items.extend(name for name in names if name not in chosen)

            def on_select(index):
                offset = 1 if chosen else 0
                if index == -1 or (chosen and index == 0):
                    on_complete(chosen)
                elif index == offset:
                    window.show_input_panel(
                        "New category (add it to taxonomy.yml too):",
                        "",
                        on_new_category,
                        None,
                        lambda: sublime.set_timeout(show, 10),
                    )
                else:
                    chosen.append(items[index])
                    advance()

            window.show_quick_panel(
                items,
                on_select,
                placeholder="Category %d of up to %d (most salient first)"
                % (len(chosen) + 1, MAX_CATEGORIES),
            )

        def on_new_category(text):
            text = text.strip()
            if text:
                chosen.append(text)
                sublime.status_message(
                    "Jekyll: '%s' is not canonical - add it to "
                    "_categorization/taxonomy.yml" % text
                )
            advance()

        def advance():
            if len(chosen) >= MAX_CATEGORIES:
                on_complete(chosen)
            else:
                sublime.set_timeout(show, 10)

        show()

    class _EveFrontmatterMixin(object):
        def on_done(self, title):
            names = _load_taxonomy(self.window)
            if names is None:
                sublime.status_message(
                    "Jekyll: _categorization/taxonomy.yml not found; "
                    "post created without categories"
                )
                self._eve_categories = []
                self.title_input(title)
                return

            def complete(chosen):
                self._eve_categories = chosen
                self.title_input(title)

            _pick_categories(self.window, names, complete)

        def create_post_frontmatter(self, title, comment=None):
            doi = fetch_doi()
            if not doi:
                sublime.status_message(
                    "Jekyll: commonmeta DOI minting failed; doi field left blank"
                )
            return build_frontmatter(
                title,
                datetime.today().strftime("%Y-%m-%d"),
                doi,
                getattr(self, "_eve_categories", []),
            )

    class JekyllNewPostCommand(_EveFrontmatterMixin, _StockNewPost):
        pass

    class JekyllNewDraftCommand(_EveFrontmatterMixin, _StockNewDraft):
        pass

    class JekyllEveCategoriesCommand(sublime_plugin.WindowCommand):
        """Pick categories for the open post and write its front matter."""

        def run(self):
            view = self.window.active_view()
            if not view:
                return
            text = view.substr(sublime.Region(0, view.size()))
            if not _FRONT_MATTER_RE.match(text):
                sublime.status_message("Jekyll: no front matter in this file")
                return
            names = _load_taxonomy(self.window)
            if names is None:
                sublime.status_message(
                    "Jekyll: _categorization/taxonomy.yml not found"
                )
                return

            def complete(chosen):
                if not chosen:
                    return
                current = view.substr(sublime.Region(0, view.size()))
                new_text = replace_categories_block(current, chosen)
                if new_text is not None and new_text != current:
                    view.run_command(
                        "jekyll_eve_apply_text", {"text": new_text}
                    )

            _pick_categories(self.window, names, complete)

    class JekyllEveApplyTextCommand(sublime_plugin.TextCommand):
        """Helper: replace the buffer (TextCommands own the edit token)."""

        def run(self, edit, text):
            self.view.replace(edit, sublime.Region(0, self.view.size()), text)

    class EveCategoryTaxonomyListener(sublime_plugin.EventListener):
        """On save of a post/draft, flag categories outside the taxonomy."""

        def on_post_save_async(self, view):
            file_name = view.file_name()
            if not file_name or not file_name.endswith((".md", ".markdown")):
                return
            parts = os.path.normpath(file_name).split(os.sep)
            if "_posts" not in parts and "_drafts" not in parts:
                return
            taxonomy_path = _taxonomy_path_for(os.path.dirname(file_name))
            if taxonomy_path is None:
                return
            try:
                with open(taxonomy_path, "r", encoding="utf-8") as handle:
                    canonical = parse_taxonomy_names(handle.read())
            except OSError:
                return

            text = view.substr(sublime.Region(0, view.size()))
            categories = extract_frontmatter_categories(text)
            if not categories:
                sublime.status_message(
                    "Jekyll: no categories in front matter "
                    "(want 1-3 from the taxonomy)"
                )
                return
            unknown = find_unknown_categories(categories, canonical)
            if unknown:
                sublime.error_message(
                    "Non-canonical categories in this post:\n\n  "
                    + "\n  ".join(unknown)
                    + "\n\nCanonical names live in _categorization/"
                    "taxonomy.yml. Fix the front matter, or add the new "
                    "category to the taxonomy if you really mean it."
                )
            elif len(categories) > MAX_CATEGORIES:
                sublime.status_message(
                    "Jekyll: %d categories; the taxonomy wants 1-3"
                    % len(categories)
                )
