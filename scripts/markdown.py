#!/usr/bin/env python3
"""Compact Markdown table cell padding.

Reads Markdown from stdin and rewrites table blocks to use single-space cell
padding instead of aligned columns.
"""

from __future__ import annotations

import re
import sys
from typing import List, Tuple

FENCE_RE = re.compile(r"^[ \t]{0,3}(`{3,}|~{3,})(.*)$")
SEPARATOR_RE = re.compile(r"^\s*\|?\s*:?-{1,}:?\s*(?:\|\s*:?-{1,}:?\s*)+\|?\s*$")
INDENT_RE = re.compile(r"^\s*")


def is_escaped(text: str, index: int) -> bool:
    backslashes = 0
    index -= 1
    while index >= 0 and text[index] == "\\":
        backslashes += 1
        index -= 1
    return backslashes % 2 == 1


def has_closing_code_span(row: str, start: int, tick_count: int) -> bool:
    index = start
    while index < len(row):
        tick_start = row.find("`", index)
        if tick_start == -1:
            return False

        tick_end = tick_start + 1
        while tick_end < len(row) and row[tick_end] == "`":
            tick_end += 1
        if tick_end - tick_start == tick_count:
            return True
        index = tick_end

    return False


def delimiter_positions(row: str) -> List[int]:
    positions: List[int] = []
    code_tick_count = 0
    index = 0

    while index < len(row):
        if row[index] == "`" and not is_escaped(row, index):
            run_end = index + 1
            while run_end < len(row) and row[run_end] == "`":
                run_end += 1
            run_length = run_end - index

            if code_tick_count == 0 and has_closing_code_span(row, run_end, run_length):
                code_tick_count = run_length
            elif run_length == code_tick_count:
                code_tick_count = 0

            index = run_end
            continue

        if row[index] == "|" and code_tick_count == 0 and not is_escaped(row, index):
            positions.append(index)

        index += 1

    return positions


def split_row(line: str) -> Tuple[str, bool, bool, List[str]]:
    indent = INDENT_RE.match(line).group(0)
    stripped = line.strip()
    delimiters = delimiter_positions(stripped)
    starts_with_pipe = bool(delimiters and delimiters[0] == 0)
    ends_with_pipe = bool(delimiters and delimiters[-1] == len(stripped) - 1)

    content_start = 1 if starts_with_pipe else 0
    content_end = len(stripped) - 1 if ends_with_pipe else len(stripped)
    content_delimiters = [
        position for position in delimiters if content_start <= position < content_end
    ]

    cells: List[str] = []
    cell_start = content_start
    for position in content_delimiters:
        cells.append(stripped[cell_start:position].strip())
        cell_start = position + 1
    cells.append(stripped[cell_start:content_end].strip())
    return indent, starts_with_pipe, ends_with_pipe, cells


def join_row(
    indent: str, starts_with_pipe: bool, ends_with_pipe: bool, cells: List[str]
) -> str:
    content = " | ".join(cells)
    if starts_with_pipe and ends_with_pipe:
        return f"{indent}| {content} |"
    if starts_with_pipe:
        return f"{indent}| {content}"
    if ends_with_pipe:
        return f"{indent}{content} |"
    return f"{indent}{content}"


def normalize_separator(cells: List[str]) -> List[str]:
    normalized: List[str] = []
    for cell in cells:
        token = cell.replace(" ", "")
        if not token:
            normalized.append("---")
            continue

        has_left_align = token.startswith(":")
        has_right_align = token.endswith(":")

        if has_left_align and has_right_align:
            normalized.append(":---:")
        elif has_left_align:
            normalized.append(":---")
        elif has_right_align:
            normalized.append("---:")
        else:
            normalized.append("---")

    return normalized


def normalize_table_block(lines: List[str]) -> List[str]:
    normalized: List[str] = []
    for index, line in enumerate(lines):
        indent, starts_with_pipe, ends_with_pipe, cells = split_row(line)
        if index == 1:
            cells = normalize_separator(cells)
        normalized.append(join_row(indent, starts_with_pipe, ends_with_pipe, cells))
    return normalized


def compact_tables(text: str) -> str:
    has_trailing_newline = text.endswith("\n")
    lines = text.splitlines()
    output: List[str] = []
    fence_marker = ""
    fence_length = 0
    index = 0

    while index < len(lines):
        line = lines[index]

        fence_match = FENCE_RE.match(line)
        if not fence_marker and fence_match:
            marker = fence_match.group(1)
            fence_marker = marker[0]
            fence_length = len(marker)
            output.append(line)
            index += 1
            continue

        if fence_marker:
            output.append(line)
            if fence_match:
                marker = fence_match.group(1)
                trailing = fence_match.group(2)
                if (
                    marker[0] == fence_marker
                    and len(marker) >= fence_length
                    and not trailing.strip()
                ):
                    fence_marker = ""
                    fence_length = 0
            index += 1
            continue

        header_parts = split_row(line)
        separator_parts = (
            split_row(lines[index + 1]) if index + 1 < len(lines) else None
        )
        has_header = bool(delimiter_positions(line.strip()))
        has_separator = (
            separator_parts is not None
            and SEPARATOR_RE.match(lines[index + 1]) is not None
            and len(header_parts[3]) >= 2
            and len(header_parts[3]) == len(separator_parts[3])
        )

        if has_header and has_separator:
            block = [line, lines[index + 1]]
            index += 2

            while index < len(lines):
                row = lines[index]
                if (
                    not row.strip()
                    or not delimiter_positions(row.strip())
                    or FENCE_RE.match(row)
                ):
                    break
                block.append(row)
                index += 1

            output.extend(normalize_table_block(block))
            continue

        output.append(line)
        index += 1

    rendered = "\n".join(output)
    if has_trailing_newline:
        rendered += "\n"
    return rendered


def main() -> int:
    source = sys.stdin.read()
    sys.stdout.write(compact_tables(source))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
