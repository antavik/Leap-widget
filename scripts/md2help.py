#!/usr/bin/python3
"""Renders the Markdown manual in `docs/manual` as Help Book HTML pages.

A deliberately small Markdown subset – the manual is written against what this
understands, not the other way round: ATX headings, paragraphs, ordered and
unordered lists, pipe tables, fenced code, blockquotes, and the inline set
(code, images, links, autolinks, bold, italic). HTML comments are dropped, so
the `<!-- SHOT: … -->` notes beside each screenshot never reach a reader.

Written for the system Python (3.9) so a build needs nothing installed.
"""

import argparse
import html
import os
import re
import sys

COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
FENCE = re.compile(r"^```(\w*)\s*$")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*$")
UNORDERED = re.compile(r"^[-*]\s+(.*)$")
ORDERED = re.compile(r"^(\d+)\.\s+(.*)$")
TABLE_DIVIDER = re.compile(r"^\|?[\s:-]*-[\s|:-]*$")
CODE_SPAN = re.compile(r"`([^`]+)`")
IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)\)")
LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
AUTOLINK = re.compile(r"&lt;(https?://[^&\s]+)&gt;")
BOLD = re.compile(r"\*\*(.+?)\*\*")
ITALIC = re.compile(r"(?<![\*\w])\*([^*]+)\*(?!\*)")
SLUG_STRIP = re.compile(r"[^a-z0-9\s-]")


def slug(text):
    return re.sub(r"\s+", "-", SLUG_STRIP.sub("", text.lower()).strip())


def inline(text):
    """Inline spans, innermost first; code spans are parked so their contents
    are never re-parsed as Markdown."""
    parked = []

    def park(match):
        parked.append("<code>%s</code>" % html.escape(match.group(1)))
        return "\x00%d\x00" % (len(parked) - 1)

    text = CODE_SPAN.sub(park, text)
    text = html.escape(text, quote=False)
    text = IMAGE.sub(
        lambda m: '<img src="%s" alt="%s">' % (html.escape(m.group(2), quote=True),
                                               html.escape(m.group(1), quote=True)),
        text)
    text = LINK.sub(
        lambda m: '<a href="%s">%s</a>' % (html.escape(rewrite_href(m.group(2)),
                                                       quote=True),
                                           m.group(1)),
        text)
    text = AUTOLINK.sub(lambda m: '<a href="%s">%s</a>' % (m.group(1), m.group(1)),
                        text)
    text = BOLD.sub(r"<strong>\1</strong>", text)
    text = ITALIC.sub(r"<em>\1</em>", text)

    return re.sub(r"\x00(\d+)\x00", lambda m: parked[int(m.group(1))], text)


def rewrite_href(href):
    """`widgets.md` and `widgets.md#anchor` both point at the built page."""
    if href.startswith(("http://", "https://", "mailto:", "#")):
        return href

    path, _, fragment = href.partition("#")
    if path.endswith(".md"):
        path = path[:-3] + ".html"

    return path + ("#" + fragment if fragment else "")


class Renderer:
    def __init__(self, lines):
        self.lines = lines
        self.index = 0
        self.out = []
        self.title = None

    def render(self):
        while self.index < len(self.lines):
            line = self.lines[self.index]

            if not line.strip():
                self.index += 1
            elif FENCE.match(line):
                self.code_block()
            elif HEADING.match(line):
                self.heading()
            elif self.is_table():
                self.table()
            elif UNORDERED.match(line) or ORDERED.match(line):
                self.list_block()
            elif line.startswith("> "):
                self.quote()
            else:
                self.paragraph()

        return "\n".join(self.out), self.title

    def code_block(self):
        self.index += 1
        body = []
        while self.index < len(self.lines) and not FENCE.match(self.lines[self.index]):
            body.append(self.lines[self.index])
            self.index += 1
        self.index += 1
        self.out.append("<pre><code>%s</code></pre>"
                        % html.escape("\n".join(body), quote=False))

    def heading(self):
        level, text = HEADING.match(self.lines[self.index]).groups()
        self.index += 1
        depth = len(level)
        if depth == 1 and self.title is None:
            self.title = re.sub(r"[*`]", "", text)
        # Anchors let the Help menu's search results jump to a section.
        self.out.append('<h%d id="%s">%s</h%d>' % (depth, slug(text), inline(text),
                                                   depth))

    def is_table(self):
        line = self.lines[self.index]
        following = self.lines[self.index + 1] if self.index + 1 < len(self.lines) else ""
        return "|" in line and TABLE_DIVIDER.match(following.strip()) is not None

    def table(self):
        def cells(row):
            return [cell.strip() for cell in row.strip().strip("|").split("|")]

        header = cells(self.lines[self.index])
        self.index += 2
        rows = []
        while self.index < len(self.lines) and "|" in self.lines[self.index]:
            rows.append(cells(self.lines[self.index]))
            self.index += 1

        self.out.append("<table>")
        self.out.append("<thead><tr>%s</tr></thead>"
                        % "".join("<th>%s</th>" % inline(cell) for cell in header))
        self.out.append("<tbody>")
        for row in rows:
            self.out.append("<tr>%s</tr>"
                            % "".join("<td>%s</td>" % inline(cell) for cell in row))
        self.out.append("</tbody></table>")

    def list_block(self):
        ordered = ORDERED.match(self.lines[self.index]) is not None
        items = []

        while self.index < len(self.lines):
            line = self.lines[self.index]
            match = ORDERED.match(line) if ordered else UNORDERED.match(line)

            if match:
                items.append(match.group(2) if ordered else match.group(1))
                self.index += 1
                continue

            # An indented line continues the item above it.
            if items and line.startswith(" ") and line.strip():
                items[-1] += " " + line.strip()
                self.index += 1
                continue

            break

        tag = "ol" if ordered else "ul"
        self.out.append("<%s>" % tag)
        self.out.extend("<li>%s</li>" % inline(item) for item in items)
        self.out.append("</%s>" % tag)

    def quote(self):
        body = []
        while self.index < len(self.lines) and self.lines[self.index].startswith("> "):
            body.append(self.lines[self.index][2:].strip())
            self.index += 1
        self.out.append("<blockquote><p>%s</p></blockquote>" % inline(" ".join(body)))

    def paragraph(self):
        body = []
        while self.index < len(self.lines) and self.lines[self.index].strip():
            line = self.lines[self.index]
            if HEADING.match(line) or FENCE.match(line) or self.is_table():
                break
            if UNORDERED.match(line) or ORDERED.match(line):
                break
            body.append(line.strip())
            self.index += 1

        text = inline(" ".join(body))
        # A paragraph that is only a screenshot becomes a figure, so the alt
        # text is visible as a caption in Help Viewer while the shot is missing.
        only_image = re.match(r"^<img [^>]*alt=\"([^\"]*)\">$", text)
        if only_image:
            self.out.append("<figure>%s<figcaption>%s</figcaption></figure>"
                            % (text, only_image.group(1)))
        else:
            self.out.append("<p>%s</p>" % text)


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


def contents_list(pages, current):
    items = []
    for name, title in pages:
        if name == current:
            items.append('<li class="current">%s</li>' % html.escape(title))
        else:
            items.append('<li><a href="%s.html">%s</a></li>'
                         % (name, html.escape(title)))
    return "<ul>\n%s\n</ul>" % "\n".join(items)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="directory of .md pages")
    parser.add_argument("--out", required=True, help="directory to write .html into")
    parser.add_argument("--book-title", default="Leap Help",
                        help="AppleTitle of the book's landing page")
    args = parser.parse_args()

    sources = sorted(name for name in os.listdir(args.source)
                     if name.endswith(".md"))
    if "index.md" not in sources:
        sys.exit("md2help: %s has no index.md" % args.source)

    # Reading order: the landing page first, then whatever it links to, then
    # anything it forgot – so the page list matches the manual's own contents.
    with open(os.path.join(args.source, "index.md"), encoding="utf-8") as handle:
        linked = [match + ".md" for match
                  in re.findall(r"\]\(([a-z0-9-]+)\.md\)", handle.read())]
    order = ["index.md"] + [name for name in linked if name in sources]
    order += [name for name in sources if name not in order]

    rendered = []
    for name in order:
        with open(os.path.join(args.source, name), encoding="utf-8") as handle:
            text = COMMENT.sub("", handle.read())
        body, title = Renderer(text.replace("\r\n", "\n").split("\n")).render()
        stem = name[:-3]
        rendered.append((stem, title or stem, body))

    pages = [(stem, title) for stem, title, _ in rendered]

    os.makedirs(args.out, exist_ok=True)
    for stem, title, body in rendered:
        landing = stem == "index"
        crumbs = ("Leap Help" if landing
                  else '<a href="index.html">Leap Help</a> › %s' % html.escape(title))
        page = PAGE.format(
            apple_title=html.escape(args.book_title if landing else title, quote=True),
            description=html.escape(title if landing else "%s – Leap User Manual" % title,
                                    quote=True),
            title=html.escape(title),
            crumbs=crumbs,
            body=body,
            contents=contents_list(pages, stem))
        with open(os.path.join(args.out, stem + ".html"), "w", encoding="utf-8") as handle:
            handle.write(page)

    print("md2help: %d pages -> %s" % (len(rendered), args.out))


if __name__ == "__main__":
    main()
