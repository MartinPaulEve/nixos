# Sublime Text: declaratively install plugins by pinning them in Nix, rather
# than enabling Package Control and letting it download packages at runtime.
# Runtime installs need network on first launch and are not reproducible; the
# store-pinned approach here is the same one used for the Obsidian plugins in
# ./obsidian.nix.
#
# Sublime loads any folder under `Packages/` as a package automatically, so each
# plugin just needs to be unpacked into `Packages/<Name>/`. Both plugins below
# are self-contained (no Package Control "dependencies"), so no dependency
# machinery is required.
#
# Updating a plugin: bump its `version`, then refresh the hash with
#   nix store prefetch-file <url>
{ pkgs, ... }:

let
  # Jekyll blog checkout; the plugin creates posts/drafts/templates under here.
  blog = "/home/martin/Programming/blog";

  # Fetch a Sublime package's release tarball (pinned by its flat archive hash)
  # and unpack it, stripping the archive's top-level directory, into a plain
  # package folder that Sublime can load directly.
  fetchSublimePackage =
    { pname, version, url, hash }:
    pkgs.runCommandLocal "${pname}-${version}" {
      src = pkgs.fetchurl { inherit url hash; };
    } ''
      mkdir -p "$out"
      tar -xzf "$src" --strip-components=1 -C "$out"
    '';

  # Jekyll: new-post/draft commands, front-matter syntax, snippets.
  jekyll = fetchSublimePackage {
    pname = "sublime-jekyll";
    version = "3.1.7";
    url = "https://github.com/23maverick23/sublime-jekyll/archive/refs/tags/v3.1.7.tar.gz";
    hash = "sha256-Rkc61amrmwZkIG1Pxszv//08OAbu6AJbGo5Etrjrir0=";
  };

  # MarkdownEditing: the de-facto markdown editing package — enhanced syntax
  # highlighting, keymaps, reference-link management, and (on by default via its
  # `mde.auto_fold_link.enabled` setting) automatic folding of the URL part of
  # inline `[text](url)` links and images.
  markdownEditing = fetchSublimePackage {
    pname = "MarkdownEditing";
    version = "4200-3.6.3";
    url = "https://github.com/SublimeText-Markdown/MarkdownEditing/archive/refs/tags/4200-3.6.3.tar.gz";
    hash = "sha256-YZs9qSclvs9NKX8P4uXEFxxlfgpqxlzsyT82rU5yrf8=";
  };
in
{
  xdg.configFile = {
    # Unpacked plugins, each loaded by Sublime as a package of the same name.
    "sublime-text/Packages/Jekyll".source = jekyll;
    "sublime-text/Packages/MarkdownEditing".source = markdownEditing;

    # User overrides for the Jekyll plugin's own defaults. Only the keys that
    # differ from its shipped Jekyll.sublime-settings need to appear here.
    # `_drafts` does not exist yet; the plugin creates it on first draft.
    "sublime-text/Packages/User/Jekyll.sublime-settings".text = builtins.toJSON {
      jekyll_posts_path = "${blog}/_posts";
      jekyll_drafts_path = "${blog}/_drafts";
      jekyll_templates_path = "${blog}/_templates";
      # New posts/drafts get a .md extension rather than the plugin's default .markdown.
      jekyll_markdown_extension = "md";
    };
  };
}
