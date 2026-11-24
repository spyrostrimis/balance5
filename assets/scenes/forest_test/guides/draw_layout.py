"""Regenerate the painting brief and its annotated companion using Pillow."""

from pathlib import Path
from random import Random
import re

from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
route_text = (HERE.parent / "forest_route.gd").read_text(encoding="utf-8")
guide_rows = route_text.split("const GUIDE_TRAIL := [")[1].split("]")[0]
rows = [
    tuple(map(int, match))
    for match in re.findall(r"Vector3\((\d+), (\d+), (\d+)\)", guide_rows)
]
width, height = 1536, 2048
canvas = Image.new("RGB", (width, height))
draw = ImageDraw.Draw(canvas)
rng = Random(46)


def bounds(y):
    for (south, left, right), (north, next_left, next_right) in zip(rows, rows[1:]):
        if y >= north:
            weight = (south - y) / (south - north)
            return (
                left + weight * (next_left - left),
                right + weight * (next_right - right),
            )
    return rows[-1][1:]


for y in range(height):
    clearing = max(0, 1 - abs(y - 360) / 360)
    wash = (int(28 + clearing * 40), int(56 + clearing * 36), int(46 + clearing * 36))
    draw.line((0, y, width, y), fill=wash)

for _ in range(360):
    y = rng.randrange(height)
    left, right = bounds(y)
    x = rng.randrange(width)
    if left - 22 < x < right + 22 and y >= rows[-1][0]:
        continue
    span = rng.randrange(15, 150)
    leaf = rng.choice(("#244b34", "#365d38", "#526d40", "#647d47", "#426451", "#1a392b"))
    draw.ellipse((x - span, y - span // 3, x + span, y + span // 3), fill=leaf)

left_edge = [(left, y) for y, left, _ in rows]
right_edge = [(right, y) for y, _, right in rows]
draw.polygon(left_edge + right_edge[::-1], fill="#b58b5d")
draw.line(left_edge, fill="#d2a875", width=7)
draw.line(right_edge, fill="#d2a875", width=7)

# Rounded clearing and progressively more distant forest beyond it.
draw.ellipse((652, 306, 893, 522), fill="#cba16d")
draw.polygon([(690, 363), (754, 318), (812, 318), (867, 359)], fill="#cba16d")

for x, y, span in [(445, 1660, 98), (1120, 1720, 83), (526, 1010, 101),
                   (1012, 853, 88), (490, 681, 64), (1020, 492, 55)]:
    draw.polygon([(x - span, y + 75), (x - 33, y - 32), (x - 46, y - 320),
                  (x + 25, y - 355), (x + 29, y - 41), (x + span, y + 66),
                  (x + 13, y + 23), (x - 15, y + 33)], fill="#75493b")
    draw.line([(x - 18, y - 298), (x - 7, y - 38), (x - span + 15, y + 48)],
              fill="#9a654d", width=12)

for x, y, span in [(1040, 1255, 32), (1093, 1221, 46), (1130, 1276, 29),
                   (920, 403, 56)]:
    draw.polygon([(x - span, y + 14), (x - span // 2, y - 23),
                  (x + span // 2, y - 34), (x + span, y), (x + span // 2, y + 18)],
                 fill="#a9ac91" if y > 500 else "#78885c")

canvas.save(HERE / "trail-art-guide.png")

font = ImageFont.load_default(size=30)
for y, label in [
    (1720, "Start · perspective entrance"),
    (1380, "Parallel fern grove"),
    (1070, "Perspective rise"),
    (730, "Parallel clearing"),
    (440, "Turnaround inside the clearing"),
]:
    left, right = bounds(y)
    draw.line((left, y, right, y), fill="#fff3c4", width=4)
    box = draw.textbbox((0, 0), label, font=font)
    draw.rounded_rectangle((30, y - 23, 66 + box[2], y + 26), 8, fill="#1a392b")
    draw.text((48, y - 18), label, fill="#fff3c4", font=font)

canvas.save(HERE / "trail-annotated.png")

scene = (HERE.parent / "forest_walk.tscn").read_text(encoding="utf-8")
painting = re.search(r'^painting_file = "(.*)"$', scene, re.MULTILINE)[1]
painted_rows = scene.split("painted_trail =")[1].split("])")[0]
fitted = [
    tuple(map(int, match))
    for match in re.findall(r"Vector3\((\d+), (\d+), (\d+)\)", painted_rows)
]

with Image.open(HERE.parent / "art" / painting) as source:
    fitted_guide = source.resize((width, height), Image.Resampling.LANCZOS)

draw = ImageDraw.Draw(fitted_guide, "RGBA")
for edge in (1, 2):
    drawn = [(row[edge], row[0]) for row in fitted]
    planned = [(row[edge], row[0]) for row in rows]
    draw.line(planned, fill=(255, 222, 157, 210), width=4, joint="curve")
    draw.line(drawn, fill=(150, 248, 237, 235), width=6, joint="curve")
for y in (440, 730, 1070, 1380, 1720):
    left, right = bounds(y)
    draw.line((left, y, right, y), fill=(255, 255, 255, 135), width=2)

draw.rounded_rectangle((32, 37, 478, 156), 12, fill=(16, 32, 30, 240))
draw.text((50, 52), "Planned trail edges", fill="#ffde9d", font=font)
draw.text((50, 100), "Fitted painted verge", fill="#96f8ed", font=font)
fitted_guide.save(HERE / "paint-fit.png")
