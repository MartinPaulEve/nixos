"""Unit tests for the pure logic in jekyll_eve_frontmatter.py.

Run outside Sublime with:
    python3 -m unittest test_jekyll_eve_frontmatter -v
"""

import unittest

from jekyll_eve_frontmatter import (
    build_categories_block,
    build_frontmatter,
    extract_frontmatter_categories,
    find_unknown_categories,
    parse_taxonomy_names,
    replace_categories_block,
)

TAXONOMY_SNIPPET = """\
# Canonical category taxonomy for eve.gd
categories:
  - name: Open Access
    criteria: >
      Open access advocacy, economics, and policy: the Open Library of
      Humanities, Plan S, APCs/BPCs.
    examples: ["Gold Open Access does NOT mean: 'author pays'"]
  - name: Higher Education
    criteria: >
      Higher education policy and university politics.
    examples: ["HE Green Paper: response to question 1"]
  - name: Thomas Pynchon
    criteria: >
      All Pynchon scholarship and news.
    examples: ["What is Thomas Pynchon's Gravity's Rainbow about?"]
"""

POST_WITH_CATEGORIES = """\
---
title: "A post"
layout: post
date: 2026-09-05
categories:
- Open Access
- Linux
image:
  feature: image.png
---
Body text with a stray categories: word in it.
"""

POST_WITHOUT_CATEGORIES = """\
---
title: "A post"
layout: post
date: 2026-09-05
---
Body text here.
"""


class ParseTaxonomyNamesTests(unittest.TestCase):
    def test_returns_names_in_taxonomy_order(self):
        self.assertEqual(
            parse_taxonomy_names(TAXONOMY_SNIPPET),
            ["Open Access", "Higher Education", "Thomas Pynchon"],
        )

    def test_ignores_criteria_and_examples_lines(self):
        names = parse_taxonomy_names(TAXONOMY_SNIPPET)
        self.assertNotIn("criteria", " ".join(names).lower())
        self.assertEqual(len(names), 3)

    def test_strips_quotes_from_quoted_names(self):
        yaml_text = 'categories:\n  - name: "Copyright: Licensing"\n'
        self.assertEqual(parse_taxonomy_names(yaml_text), ["Copyright: Licensing"])

    def test_returns_empty_list_for_text_without_names(self):
        self.assertEqual(parse_taxonomy_names("just: some\nother: yaml\n"), [])


class BuildCategoriesBlockTests(unittest.TestCase):
    def test_builds_block_matching_post_front_matter_style(self):
        self.assertEqual(
            build_categories_block(["Open Access", "Linux"]),
            "categories:\n- Open Access\n- Linux\n",
        )

    def test_empty_list_builds_empty_string(self):
        self.assertEqual(build_categories_block([]), "")


class ExtractFrontmatterCategoriesTests(unittest.TestCase):
    def test_reads_block_style_categories(self):
        self.assertEqual(
            extract_frontmatter_categories(POST_WITH_CATEGORIES),
            ["Open Access", "Linux"],
        )

    def test_reads_indented_block_style_categories(self):
        post = "---\ntitle: x\ncategories:\n  - Music\n  - Health\n---\nBody\n"
        self.assertEqual(extract_frontmatter_categories(post), ["Music", "Health"])

    def test_reads_inline_flow_style_categories(self):
        post = "---\ntitle: x\ncategories: [Music, Health]\n---\nBody\n"
        self.assertEqual(extract_frontmatter_categories(post), ["Music", "Health"])

    def test_strips_quotes_from_entries(self):
        post = '---\ntitle: x\ncategories:\n- "Music"\n---\nBody\n'
        self.assertEqual(extract_frontmatter_categories(post), ["Music"])

    def test_returns_none_when_no_categories_key(self):
        self.assertIsNone(extract_frontmatter_categories(POST_WITHOUT_CATEGORIES))

    def test_returns_none_when_no_front_matter(self):
        self.assertIsNone(extract_frontmatter_categories("Just a plain file.\n"))

    def test_ignores_categories_mentioned_in_body(self):
        post = "---\ntitle: x\n---\ncategories:\n- Not Real\n"
        self.assertIsNone(extract_frontmatter_categories(post))


class ReplaceCategoriesBlockTests(unittest.TestCase):
    def test_replaces_existing_block_in_place(self):
        result = replace_categories_block(POST_WITH_CATEGORIES, ["Music"])
        self.assertEqual(extract_frontmatter_categories(result), ["Music"])
        self.assertNotIn("Open Access", result)

    def test_replacement_leaves_other_front_matter_and_body_untouched(self):
        result = replace_categories_block(POST_WITH_CATEGORIES, ["Music"])
        self.assertIn('title: "A post"', result)
        self.assertIn("  feature: image.png", result)
        self.assertIn("Body text with a stray categories: word in it.", result)

    def test_inserts_block_when_absent(self):
        result = replace_categories_block(POST_WITHOUT_CATEGORIES, ["Music", "Health"])
        self.assertEqual(extract_frontmatter_categories(result), ["Music", "Health"])
        self.assertIn("Body text here.", result)

    def test_inserted_block_sits_inside_front_matter(self):
        result = replace_categories_block(POST_WITHOUT_CATEGORIES, ["Music"])
        front_matter = result.split("---\n")[1]
        self.assertIn("categories:\n- Music\n", front_matter)

    def test_empty_list_removes_existing_block(self):
        result = replace_categories_block(POST_WITH_CATEGORIES, [])
        self.assertIsNone(extract_frontmatter_categories(result))
        self.assertIn('title: "A post"', result)

    def test_returns_none_when_no_front_matter(self):
        self.assertIsNone(replace_categories_block("Plain file.\n", ["Music"]))


class FindUnknownCategoriesTests(unittest.TestCase):
    CANONICAL = ["Open Access", "Linux", "Music"]

    def test_returns_unknown_categories_in_order(self):
        self.assertEqual(
            find_unknown_categories(["Linux", "Warez", "open access"], self.CANONICAL),
            ["Warez", "open access"],
        )

    def test_returns_empty_list_when_all_canonical(self):
        self.assertEqual(
            find_unknown_categories(["Music", "Linux"], self.CANONICAL), []
        )


class BuildFrontmatterCategoriesTests(unittest.TestCase):
    def test_includes_chosen_categories_in_front_matter(self):
        result = build_frontmatter(
            "Title", "2026-09-05", "", categories=["Open Access", "Linux"]
        )
        self.assertIn("categories:\n- Open Access\n- Linux\n", result)

    def test_omits_categories_block_when_none_chosen(self):
        result = build_frontmatter("Title", "2026-09-05", "")
        self.assertNotIn("categories", result)

    def test_category_names_are_snippet_escaped(self):
        result = build_frontmatter("Title", "2026-09-05", "", categories=["C$H"])
        self.assertIn("C\\$H", result)


if __name__ == "__main__":
    unittest.main()
