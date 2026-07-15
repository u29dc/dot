import unittest

from scripts.markdown import compact_tables


class CompactTablesTest(unittest.TestCase):
    def test_compacts_regular_table_padding(self) -> None:
        source = "| A    | B   |\n| ---- | --- |\n| one  | two |\n"
        expected = "| A | B |\n| --- | --- |\n| one | two |\n"

        self.assertEqual(compact_tables(source), expected)

    def test_preserves_escaped_and_code_span_pipes(self) -> None:
        source = "| A | B |\n| --- | --- |\n| `x|y` | a\\|b |\n"

        self.assertEqual(compact_tables(source), source)

    def test_preserves_pipes_in_multi_backtick_code_spans(self) -> None:
        source = "| A | B |\n| --- | --- |\n| ``x`|y`` | value |\n"

        self.assertEqual(compact_tables(source), source)

    def test_unmatched_backtick_does_not_hide_cell_delimiters(self) -> None:
        source = "| A | B |\n| --- | --- |\n| broken `text   | value |\n"
        expected = "| A | B |\n| --- | --- |\n| broken `text | value |\n"

        self.assertEqual(compact_tables(source), expected)

    def test_escaped_pipe_does_not_create_a_table_header(self) -> None:
        source = "Not a \\| table\n:------ | ------:\n"

        self.assertEqual(compact_tables(source), source)

    def test_preserves_tables_inside_mixed_fences(self) -> None:
        source = "~~~md\n```\n| A    | B   |\n| ---- | --- |\n| one  | two |\n~~~\n"

        self.assertEqual(compact_tables(source), source)

    def test_shorter_fence_does_not_close_longer_fence(self) -> None:
        source = "````md\n```\n| A    | B   |\n| ---- | --- |\n| one  | two |\n````\n"

        self.assertEqual(compact_tables(source), source)


if __name__ == "__main__":
    unittest.main()
