#!/usr/bin/python3
"""Renders the Markdown manual in `docs/manual` as Help Book HTML pages.

A deliberately small Markdown subset – the manual is written against what this
understands, not the other way round: ATX headings, paragraphs, nested ordered
and unordered lists, pipe tables, fenced code, blockquotes, thematic breaks,
and the inline set (code, images, links, autolinks, bold, italic). HTML
comments are dropped, so the `<!-- SHOT: … -->` notes beside each screenshot
never reach a reader.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from pathlib import Path

COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
FENCE = re.compile(r"^```\s*(\w*)\s*$")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*$")
LIST_ITEM = re.compile(r"^(\s*)(?:[-*]|(\d+)\.)\s+(.*)$")
THEMATIC_BREAK = re.compile(r"^ {0,3}([-*_])(?:\s*\1){2,}\s*$")
DIVIDER_CELL = re.compile(r"^:?-+:?$")
CODE_SPAN = re.compile(r"`([^`]+)`")
IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
AUTOLINK = re.compile(r"&lt;(https?://[^&\s]+)&gt;")
BOLD = re.compile(r"\*\*(.+?)\*\*")
ITALIC = re.compile(r"(?<![\*\w])\*([^*]+)\*(?!\*)")
SLUG_STRIP = re.compile(r"[^a-z0-9\s-]")
PAGE_LINK = re.compile(r"\]\(([a-z0-9-]+)\.md(?:#[^)\s]*)?\)")
ONLY_IMAGE = re.compile(r'^<img [^>]*alt="([^"]*)">$')
PARKED = re.compile("\x00(\\d+)\x00")

PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="index,anchors">
<meta name="AppleTitle" content="{apple_title}">
<meta name="description" content="{description}">
<title>{title}</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<nav class="crumbs">{crumbs}</nav>
<article>
{body}
</article>
<nav class="pages">
<h2>Leap Help</h2>
{contents}
</nav>
</body>
</html>
"""


def slug(text: str) -> str:
    return re.sub(r"\s+", "-", SLUG_STRIP.sub("", text.lower()).strip())


def attribute(value: str) -> str:
    return value.replace('"', "&quot;")


def cells(row: str) -> list[str]:
    found: list[str] = []
    cell: list[str] = []
    code = False
    for char in row.strip().strip("|"):
        if char == "`":
            code = not code
        if char == "|" and not code:
            found.append("".join(cell).strip())
            cell = []
        else:
            cell.append(char)

    found.append("".join(cell).strip())

    return found


def inline(text: str) -> str:
    parked: list[str] = []

    def park(match: re.Match) -> str:
        parked.append(f"<code>{html.escape(match.group(1))}</code>")
        return f"\x00{len(parked) - 1}\x00"

    def image(match: re.Match) -> str:
        return f'<img src="{attribute(match.group(2))}" alt="{attribute(match.group(1))}">'

    def link(match: re.Match) -> str:
        href = attribute(rewrite_href(match.group(2)))
        return f'<a href="{href}">{match.group(1)}</a>'

    def autolink(match: re.Match) -> str:
        return f'<a href="{attribute(match.group(1))}">{match.group(1)}</a>'

    text = CODE_SPAN.sub(park, text)
    text = html.escape(text, quote=False)
    text = IMAGE.sub(image, text)
    text = LINK.sub(link, text)
    text = AUTOLINK.sub(autolink, text)
    text = BOLD.sub(r"<strong>\1</strong>", text)
    text = ITALIC.sub(r"<em>\1</em>", text)

    return PARKED.sub(lambda m: parked[int(m.group(1))], text)


def rewrite_href(href: str) -> str:
    """`widgets.md` and `widgets.md#anchor` both point at the built page."""
    if href.startswith(("http://", "https://", "mailto:", "#")):
        return href

    path, _, fragment = href.partition("#")
    if path.endswith(".md"):
        path = path[:-3] + ".html"

    return path + ("#" + fragment or "")


class Renderer:
    def __init__(self, lines: list[str], name: str = "") -> None:
        self.lines = lines
        self.name = name
        self.index = 0
        self.out: list[str] = []
        self.title: str | None = None
        self.anchors: set[str] = set()

    def warn(self, message: str) -> None:
        """Malformed Markdown still renders, but silently wrong pages are worse
        than noisy builds – so say which line to look at."""
        if self.name:
            where = f"{self.name}:{self.index + 1}"
        else:
            where = f"line {self.index + 1}"

        print(f"md2help: {where}: {message}", file=sys.stderr)

    def render(self) -> tuple[str, str | None]:
        while self.index < len(self.lines):
            line = self.lines[self.index]

            if not line.strip():
                self.index += 1
            elif FENCE.match(line):
                self.code_block()
            elif HEADING.match(line):
                self.heading()
            elif THEMATIC_BREAK.match(line):
                self.index += 1
                self.out.append("<hr>")
            elif self.is_table():
                self.table()
            elif LIST_ITEM.match(line):
                self.out.append(self.list_block())
            elif line.startswith(">"):
                self.quote()
            else:
                self.paragraph()

        return "\n".join(self.out), self.title

    def code_block(self) -> None:
        language = FENCE.match(self.lines[self.index]).group(1)

        self.index += 1
        lines = []
        while self.index < len(self.lines) and not FENCE.match(self.lines[self.index]):
            lines.append(self.lines[self.index])
            self.index += 1

        if self.index >= len(self.lines):
            self.warn("code fence is never closed")

        self.index += 1

        attributes = f' class="language-{language}"' if language else ""
        body = html.escape("\n".join(lines), quote=False)
        self.out.append(f"<pre><code{attributes}>{body}</code></pre>")

    def heading(self) -> None:
        level, text = HEADING.match(self.lines[self.index]).groups()
        self.index += 1
        depth = len(level)
        if depth == 1 and self.title is None:
            self.title = re.sub(r"[*`]", "", text)

        # Anchors let the Help menu's search results jump to a section, so two
        # sections sharing a heading still need an id each – and the suffix a
        # repeat gets must not collide with a heading that reads like one.
        anchor = base = slug(text) or "section"
        suffix = 0
        while anchor in self.anchors:
            suffix += 1
            anchor = f"{base}-{suffix}"

        self.anchors.add(anchor)

        self.out.append(f'<h{depth} id="{anchor}">{inline(text)}</h{depth}>')

    def is_table(self) -> bool:
        line = self.lines[self.index]
        if "|" not in line or (self.index + 1 >= len(self.lines)):
            return False

        divider = cells(self.lines[self.index + 1])
        # A rule under a line that merely contains a pipe is not a table: the
        # divider has to describe every one of the header's columns.
        return (len(divider) == len(cells(line))
                and all(DIVIDER_CELL.match(cell) for cell in divider))

    def table(self) -> None:
        header = cells(self.lines[self.index])
        width = len(header)
        self.index += 2
        rows = []
        while self.index < len(self.lines) and "|" in self.lines[self.index]:
            row = cells(self.lines[self.index])
            if len(row) != width:
                self.warn(f"table row has {len(row)} cells, the header has {width}")
                # Every row keeps the header's shape, or the browser lays the
                # table out with cells hanging off the end of it.
                row = (row + [""] * width)[:width]

            rows.append(row)
            self.index += 1

        heads = "".join(f"<th>{inline(cell)}</th>" for cell in header)
        self.out.append("<table>")
        self.out.append(f"<thead><tr>{heads}</tr></thead>")
        self.out.append("<tbody>")
        for row in rows:
            body = "".join(f"<td>{inline(cell)}</td>" for cell in row)
            self.out.append(f"<tr>{body}</tr>")
        self.out.append("</tbody></table>")

    def list_block(self, indent: int | None = None) -> str:
        first = LIST_ITEM.match(self.lines[self.index])
        ordered = first.group(2) is not None
        if indent is None:
            indent = len(first.group(1))

        # Per item: the raw Markdown of its own lines, and any nested list.
        items: list[tuple[list[str], list[str]]] = []

        while self.index < len(self.lines):
            line = self.lines[self.index]

            # A blank line between two items keeps one list; anything else
            # after it ends the list, rather than starting a second one – an
            # ordered list split in two would start counting at 1 again.
            if not line.strip():
                following = self.continues(indent)
                if following is None:
                    break
                self.index = following
                continue

            # `* * *` reads as a bullet, so the break has to win here too.
            if THEMATIC_BREAK.match(line):
                break

            match = LIST_ITEM.match(line)

            if match:
                depth = len(match.group(1))
                if depth > indent and items:
                    items[-1][1].append(self.list_block(depth))
                    continue

                if depth < indent or (match.group(2) is not None) != ordered:
                    break

                items.append(([match.group(3)], []))
                self.index += 1
                continue

            # An indented line continues the item above it, and is joined
            # before parsing so a span may straddle the line break.
            if items and line[:1].isspace():
                items[-1][0].append(line.strip())
                self.index += 1
                continue

            break

        tag = "ol" if ordered else "ul"
        body = "\n".join(f"<li>{inline(' '.join(text))}{''.join(nested)}</li>"
                         for text, nested in items)

        return f"<{tag}>\n{body}\n</{tag}>"

    def continues(self, indent: int) -> int | None:
        """The line a list interrupted by blank lines carries on at: a further
        item, or a paragraph indented under the last one. None ends the list."""
        index = self.index
        while index < len(self.lines) and not self.lines[index].strip():
            index += 1

        if index >= len(self.lines) or THEMATIC_BREAK.match(self.lines[index]):
            return None

        line = self.lines[index]
        match = LIST_ITEM.match(line)
        depth = len(match.group(1)) if match else len(line) - len(line.lstrip())

        # A paragraph level with the list is prose after it, not part of it.
        if depth < indent or (match is None and depth == indent):
            return None

        return index

    def quote(self) -> None:
        lines = []
        while self.index < len(self.lines) and self.lines[self.index].startswith(">"):
            lines.append(self.lines[self.index][1:].strip())
            self.index += 1

        body = inline(" ".join(lines))
        self.out.append(f"<blockquote><p>{body}</p></blockquote>")

    def paragraph(self) -> None:
        lines = []
        while self.index < len(self.lines) and self.lines[self.index].strip():
            line = self.lines[self.index]
            if HEADING.match(line) or FENCE.match(line) or self.is_table():
                break

            if LIST_ITEM.match(line) or THEMATIC_BREAK.match(line):
                break

            if line.startswith(">"):
                break

            lines.append(line.strip())
            self.index += 1

        body = inline(" ".join(lines))
        # A paragraph that is only a screenshot becomes a figure, so the alt
        # text is visible as a caption in Help Viewer while the shot is missing.
        only_image = ONLY_IMAGE.match(body)
        if only_image:
            caption = only_image.group(1)
            self.out.append(f"<figure>{body}<figcaption>{caption}</figcaption></figure>")
        else:
            self.out.append(f"<p>{body}</p>")


def contents_list(pages: list[tuple[str, str]], current: str) -> str:
    items = []
    for name, title in pages:
        label = html.escape(title)
        if name == current:
            items.append(f'<li class="current">{label}</li>')
        else:
            items.append(f'<li><a href="{name}.html">{label}</a></li>')

    body = "\n".join(items)

    return f"<ul>\n{body}\n</ul>"


def reading_order(index: str, sources: list[str]) -> list[str]:
    """The landing page first, then whatever it links to, then anything it
    forgot – so the page list matches the manual's own contents. A page linked
    twice is still listed once."""
    linked = [f"{name}.md" for name in PAGE_LINK.findall(index)]
    order = ["index.md"] + [name for name in linked if name in sources]

    return list(dict.fromkeys(order + sources))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path,
                        help="directory of .md pages")
    parser.add_argument("--out", required=True, type=Path,
                        help="directory to write .html into")
    parser.add_argument("--book-title", default="Leap Help",
                        help="AppleTitle of the book's landing page")
    args = parser.parse_args()

    if not args.source.is_dir():
        print(f"md2help: {args.source} is not a directory", file=sys.stderr)
        return 1

    sources = sorted(path.name for path in args.source.glob("*.md"))
    if "index.md" not in sources:
        print(f"md2help: {args.source} has no index.md", file=sys.stderr)
        return 1

    try:
        pages_source = {name: (args.source / name).read_text(encoding="utf-8")
                        for name in sources}
    except (OSError, UnicodeDecodeError) as error:
        print(f"md2help: cannot read the manual: {error}", file=sys.stderr)
        return 1

    rendered = []
    for name in reading_order(pages_source["index.md"], sources):
        text = COMMENT.sub("", pages_source[name])
        body, title = Renderer(text.splitlines(), name).render()
        stem = name[:-3]
        rendered.append((stem, title or stem, body))

    pages = [(stem, title) for stem, title, _ in rendered]

    try:
        args.out.mkdir(parents=True, exist_ok=True)
        for stem, title, body in rendered:
            landing = stem == "index"
            crumbs = ("Leap Help" if landing
                      else f'<a href="index.html">Leap Help</a> › {html.escape(title)}')
            description = title if landing else f"{title} – Leap User Manual"
            page = PAGE.format(
                apple_title=html.escape(args.book_title if landing else title, quote=True),
                description=html.escape(description, quote=True),
                title=html.escape(title),
                crumbs=crumbs,
                body=body,
                contents=contents_list(pages, stem))
            (args.out / f"{stem}.html").write_text(page, encoding="utf-8")
    except OSError as error:
        print(f"md2help: cannot write to {args.out}: {error}", file=sys.stderr)

        return 1

    print(f"md2help: {len(rendered)} pages -> {args.out}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
