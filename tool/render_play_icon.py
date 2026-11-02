#!/usr/bin/env python3
"""Render the 512 x 512 Play Store icon from the launcher icon's vector drawables (#101).

The drawables in android/app/src/main/res/drawable/ are the one source of truth: this
script turns ic_launcher_background.xml + ic_launcher_foreground.xml into one SVG, keeps
the centre 72 x 72 of the 108 x 108 adaptive canvas (what a launcher shows; Play rounds
the corners itself), renders it with rsvg-convert and writes a 32-bit PNG with Pillow.

It understands the subset of VectorDrawable the icon uses: nested <group> transforms,
<path> fill/stroke with alphas, fillType, line caps/joins, and linear/radial gradients
in <aapt:attr>.

    tool/render_play_icon.py [--svg out.svg] [out.png]   # default store/listing/ic_launcher_play_store.png

Needs rsvg-convert (librsvg2-bin) and Pillow.
"""
import argparse
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRAWABLE = os.path.join(ROOT, "android", "app", "src", "main", "res", "drawable")
LAYERS = ["ic_launcher_background.xml", "ic_launcher_foreground.xml"]
DEFAULT_OUT = os.path.join(ROOT, "store", "listing", "ic_launcher_play_store.png")
SIZE = 512
A = "{http://schemas.android.com/apk/res/android}"


def attr(el, name, default=None):
    return el.get(A + name, default)


def colour(argb):
    """#AARRGGBB or #RRGGBB -> (#RRGGBB, opacity)."""
    h = argb.lstrip("#")
    if len(h) == 8:
        return "#" + h[2:], int(h[:2], 16) / 255
    return "#" + h, 1.0


class Converter:
    def __init__(self):
        self.defs = []
        self.ids = 0

    def gradient(self, g):
        self.ids += 1
        gid = f"g{self.ids}"
        stops = "".join(
            '<stop offset="{}" stop-color="{}" stop-opacity="{:.4f}"/>'.format(
                attr(item, "offset"), *colour(attr(item, "color")))
            for item in g.findall("item"))
        if attr(g, "type") == "radial":
            self.defs.append(
                f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{attr(g, "centerX")}" '
                f'cy="{attr(g, "centerY")}" r="{attr(g, "gradientRadius")}">{stops}</radialGradient>')
        else:
            self.defs.append(
                f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="{attr(g, "startX")}" '
                f'y1="{attr(g, "startY")}" x2="{attr(g, "endX")}" y2="{attr(g, "endY")}">{stops}</linearGradient>')
        return f"url(#{gid})"

    def path(self, p):
        paints = {}
        for aapt in p:  # <aapt:attr name="android:fillColor"><gradient …/></aapt:attr>
            paints[aapt.get("name").split(":")[1]] = self.gradient(aapt.find("gradient"))
        out = [f'd="{attr(p, "pathData")}"']
        for kind, svg in (("fill", "fill"), ("stroke", "stroke")):
            value = paints.get(kind + "Color")
            opacity = float(attr(p, kind + "Alpha", "1"))
            if value is None and attr(p, kind + "Color"):
                value, a = colour(attr(p, kind + "Color"))
                opacity *= a
            out.append(f'{svg}="{value or "none"}"')
            if value and opacity < 1:
                out.append(f'{svg}-opacity="{opacity:.4f}"')
        if attr(p, "fillType") == "evenOdd":
            out.append('fill-rule="evenodd"')
        if attr(p, "strokeColor") or "strokeColor" in paints:
            out.append(f'stroke-width="{attr(p, "strokeWidth", "0")}"')
            out.append(f'stroke-linejoin="{attr(p, "strokeLineJoin", "miter")}"')
            out.append(f'stroke-linecap="{attr(p, "strokeLineCap", "butt")}"')
        return "<path " + " ".join(out) + "/>"

    def group(self, g):
        # A VectorDrawable group scales and rotates about its pivot, then translates.
        px, py = float(attr(g, "pivotX", "0")), float(attr(g, "pivotY", "0"))
        tx, ty = float(attr(g, "translateX", "0")), float(attr(g, "translateY", "0"))
        transform = (f"translate({tx + px},{ty + py}) rotate({attr(g, 'rotation', '0')}) "
                     f"scale({attr(g, 'scaleX', '1')},{attr(g, 'scaleY', '1')}) translate({-px},{-py})")
        return f'<g transform="{transform}">' + self.children(g) + "</g>"

    def children(self, el):
        parts = []
        for child in el:
            if child.tag == "group":
                parts.append(self.group(child))
            elif child.tag == "path":
                parts.append(self.path(child))
            else:
                sys.exit(f"render_play_icon: unsupported <{child.tag}>")
        return "".join(parts)


def icon_svg():
    conv = Converter()
    body = ""
    for name in LAYERS:
        vector = ET.parse(os.path.join(DRAWABLE, name)).getroot()
        if attr(vector, "viewportWidth") != "108":
            sys.exit(f"render_play_icon: {name} is not on the 108 x 108 adaptive canvas")
        body += conv.children(vector)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="18 18 72 72" '
            f'width="{SIZE}" height="{SIZE}"><defs>{"".join(conv.defs)}</defs>{body}</svg>')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", nargs="?", default=DEFAULT_OUT)
    parser.add_argument("--svg", help="also keep the intermediate SVG here")
    args = parser.parse_args()
    svg = icon_svg()
    if args.svg:
        with open(args.svg, "w") as f:
            f.write(svg)
    with tempfile.TemporaryDirectory() as tmp:
        src, png = os.path.join(tmp, "icon.svg"), os.path.join(tmp, "icon.png")
        with open(src, "w") as f:
            f.write(svg)
        subprocess.run(["rsvg-convert", "-w", str(SIZE), "-h", str(SIZE), src, "-o", png], check=True)
        # Play wants a 32-bit PNG (RGBA), 512 x 512, at most 1 MB.
        image = Image.open(png).convert("RGBA")
        os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
        image.save(args.out, optimize=True)
    print(f"{args.out}: {SIZE} x {SIZE}, {os.path.getsize(args.out) // 1024} KB")


if __name__ == "__main__":
    main()
