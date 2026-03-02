#!/usr/bin/env python3
"""Compact Markdown table cell padding.

Reads Markdown from stdin and rewrites table blocks to use single-space cell
padding instead of aligned columns.
"""

from __future__ import annotations

import re
import sys
from typing import List, Tuple

FENCE_RE = re.compile(r"^\s*(```+|~~~+)")
SEPARATOR_RE = re.compile(r"^\s*\|?\s*:?-{1,}:?\s*(?:\|\s*:?-{1,}:?\s*)+\|?\s*$")
INDENT_RE = re.compile(r"^\s*")


def split_row(line: str) -> Tuple[str, bool, bool, List[str]]:
    indent = INDENT_RE.match(line).group(0)
    stripped = line.strip()
    starts_with_pipe = stripped.startswith("|")
    ends_with_pipe = stripped.endswith("|")

    core = stripped
    if starts_with_pipe:
        core = core[1:]
    if ends_with_pipe:
        core = core[:-1]

    cells = [cell.strip() for cell in core.split("|")]
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
    in_fence = False
    index = 0

    while index < len(lines):
        line = lines[index]

        if FENCE_RE.match(line):
            in_fence = not in_fence
            output.append(line)
            index += 1
            continue

        if in_fence:
            output.append(line)
            index += 1
            continue

        has_header = "|" in line
        has_separator = (
            index + 1 < len(lines) and SEPARATOR_RE.match(lines[index + 1]) is not None
        )

        if has_header and has_separator:
            block = [line, lines[index + 1]]
            index += 2

            while index < len(lines):
                row = lines[index]
                if not row.strip() or "|" not in row or FENCE_RE.match(row):
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
