"""Unit tests for the pure logic in markdown_preview.py.

Run outside Sublime with:
    python3 -m unittest test_markdown_preview -v
"""

import unittest

from markdown_preview import is_markdown_file, preview_command


class IsMarkdownFileTests(unittest.TestCase):
    def test_accepts_common_markdown_extensions(self):
        for name in ("notes.md", "post.markdown", "x.mdown", "y.mkd", "z.mkdn"):
            self.assertTrue(is_markdown_file("/home/martin/" + name), name)

    def test_is_case_insensitive(self):
        self.assertTrue(is_markdown_file("/tmp/README.MD"))

    def test_rejects_other_files(self):
        for name in ("script.py", "page.html", "README", "notes.txt"):
            self.assertFalse(is_markdown_file("/home/martin/" + name), name)

    def test_rejects_unsaved_buffer(self):
        self.assertFalse(is_markdown_file(None))
        self.assertFalse(is_markdown_file(""))


class PreviewCommandTests(unittest.TestCase):
    def test_launches_inlyne_on_the_file(self):
        argv = preview_command("/home/martin/notes/todo.md")
        self.assertEqual(argv[0], "inlyne")
        self.assertEqual(argv[-1], "/home/martin/notes/todo.md")

    def test_path_is_passed_as_a_single_argument(self):
        argv = preview_command("/home/martin/my notes/a b.md")
        self.assertIn("/home/martin/my notes/a b.md", argv)
        self.assertEqual(argv.count("/home/martin/my notes/a b.md"), 1)

    def test_returns_a_fresh_list_each_call(self):
        first = preview_command("/a.md")
        first.append("--mutated")
        self.assertNotIn("--mutated", preview_command("/a.md"))


if __name__ == "__main__":
    unittest.main()
