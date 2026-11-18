"""Build the periodic OpenRaster layers and tangent-space normal for Session 3.

From the project root, run with Python (NumPy, OpenCV, Pillow), then open
tmp/session3/handlaid_sandstone.ora in Krita and save it as the layered master.
Export the visible composite for Godot. The hidden height layer spans 0–40 mm.
"""

import io
import json
from pathlib import Path
import zipfile
from xml.etree.ElementTree import Element, SubElement, tostring

import cv2
import numpy as np
from PIL import Image


SIZE = 1024
PER_METRE = SIZE / 4
WORK = Path("tmp/session3")
TEXTURES = Path("assets/textures/canyon_pbr")


def smoothstep(value):
    t = np.clip(value, 0, 1)
    return t * t * (3 - 2 * t)


def periodic_noise(rng, divisions):
    lattice = rng.normal(0, 1, (divisions, divisions)).astype(np.float32)
    expanded = cv2.resize(np.tile(lattice, (3, 3)), (3 * SIZE, 3 * SIZE), interpolation=cv2.INTER_CUBIC)
    return expanded[SIZE:2 * SIZE, SIZE:2 * SIZE]


def encode_rgb(values):
    return np.clip(np.rint(values), 0, 255).astype(np.uint8)


def raster_coverage(color, alpha):
    return Image.fromarray(encode_rgb(np.dstack((color, alpha * 255))))


def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def save_openraster(layers):
    doc = Element("image", {"w": str(SIZE), "h": str(SIZE), "name": "Hand-laid sandstone, 4 m"})
    stack = SubElement(doc, "stack")
    merged = Image.new("RGBA", (SIZE, SIZE))
    with zipfile.ZipFile(WORK / "handlaid_sandstone.ora", "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("mimetype", "image/openraster", compress_type=zipfile.ZIP_STORED)
        for i, (name, layer, visible) in enumerate(layers):
            path = f"data/layer{i}.png"
            archive.writestr(path, png_bytes(layer))
            SubElement(stack, "layer", {
                "name": name, "src": path, "visibility": "visible" if visible else "hidden",
                "opacity": "1.0", "composite-op": "svg:src-over", "x": "0", "y": "0",
            })
        for _, layer, visible in reversed(layers):
            if visible:
                merged.alpha_composite(layer)
        archive.writestr("stack.xml", tostring(doc, encoding="utf-8"))
        archive.writestr("mergedimage.png", png_bytes(merged))


def author_tile():
    rng = np.random.default_rng(130127)
    weathering = periodic_noise(rng, 16) * 0.55 + periodic_noise(rng, 38) * 0.45
    mineral = periodic_noise(rng, 84) * 0.68 + periodic_noise(rng, 192) * 0.32
    grit = periodic_noise(rng, 360) * 0.65 + rng.normal(0, 0.42, (SIZE, SIZE))
    chips = periodic_noise(rng, 127)
    mortar = np.array([110, 77, 50]) + (weathering * 11 + mineral * 8 + grit * 6)[..., None]
    height = 0.0009 + (mineral * 0.00037 + grit * 0.00022)
    faces = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    coverage = np.zeros((SIZE, SIZE), dtype=np.float32)
    course_depths = rng.uniform(40, 73, 18)
    course_depths *= SIZE / course_depths.sum()
    course_edges = np.r_[0, np.cumsum(course_depths)]
    stones = []

    for course, depth in enumerate(course_depths):
        centre_z = (course_edges[course] + depth / 2 + 14) % SIZE
        count = rng.integers(10, 14)
        widths = rng.uniform(0.66, 1.39, count)
        widths *= SIZE / widths.sum()
        offset = (course * 43 + rng.uniform(-27, 27)) % SIZE
        row_tint = rng.uniform(-5.5, 5.5)
        for width in widths:
            centre_x = (offset + width / 2) % SIZE
            offset += width
            z_start = rng.uniform(-4.2, 4.2)
            x_indices = np.arange(int(centre_x - width / 2 - 19), int(centre_x + width / 2 + 20))
            z_indices = np.arange(int(centre_z - depth / 2 - 19), int(centre_z + depth / 2 + 20))
            ix = np.ix_(z_indices % SIZE, x_indices % SIZE)
            x = x_indices[None, :] - centre_x
            phase = 2 * np.pi * x_indices[None, :] / SIZE
            bend = 5.7 * np.sin(3 * phase + course * 0.53) + 2.8 * np.sin(7 * phase - course * 1.11)
            z = z_indices[:, None] - centre_z - bend - z_start - x * rng.uniform(-0.13, 0.13)
            wedge = rng.uniform(-0.48, 0.48) if rng.random() < 0.17 else rng.uniform(-0.15, 0.15)
            x = x - z * wedge * 0.52
            half_x = (width / 2 - rng.uniform(2.6, 7.2)) * (1 + wedge * z / depth)
            half_z = depth / 2 - rng.uniform(2.7, 7.0)
            rounding = min(half_z * rng.uniform(0.48, 0.90), half_x.min() * 0.74)

            qx = np.abs(x) - half_x + rounding
            qz = np.abs(z) - half_z + rounding
            inset = rounding - (np.hypot(np.maximum(qx, 0), np.maximum(qz, 0)) + np.minimum(np.maximum(qx, qz), 0))
            chipped = np.maximum(chips[ix] - 0.36, 0) * 2.9
            inset += weathering[ix] * 1.45 + mineral[ix] * 0.81 - chipped
            alpha = smoothstep((inset + 0.85) / 1.7)

            # Broad mound over the rounded toe. Grain varies height locally without a painted sun direction.
            dome = np.clip(1 - 0.54 * (x / half_x) ** 2 - 0.73 * (z / half_z) ** 2, 0, 1)
            shoulder = smoothstep(inset / rng.uniform(6.0, 12.0))
            top = 0.0012 + shoulder * (0.003 + rng.uniform(0.020, 0.032) * dome
                                      + mineral[ix] * 0.00078 + weathering[ix] * 0.00105)
            height[ix] = np.maximum(height[ix], top * alpha)

            tone = rng.uniform(-16, 13) + row_tint
            tint = np.array([160.0, 120.0, 79.0]) + tone + rng.uniform(-5, 5, 3)
            stain = weathering[ix] * 8.0 + mineral[ix] * 4.4 - 18 * (1 - shoulder)
            old_spalls = np.maximum(chips[ix] - 0.95, 0) * (5.5 + 7 * (1 - shoulder))
            paint = tint + (stain - old_spalls)[..., None]
            faces[ix] = np.where((alpha > coverage[ix])[..., None], paint, faces[ix])
            coverage[ix] = np.maximum(coverage[ix], alpha)
            stones.append({"x": centre_x, "z": centre_z + z_start, "width": 2 * float(half_x.mean()), "wedge": wedge})

    flecks = mineral * 0.66 + grit * 0.64
    fleck_color = np.where((flecks > 0)[..., None], [225, 185, 136], [78, 52, 33])
    height_u8 = encode_rgb(height * (255 / 0.04))
    save_openraster([
        ("Mineral flecks and grit", raster_coverage(fleck_color, np.minimum(0.35, abs(flecks) * 0.16) * coverage), True),
        ("Worn sandstone setts", raster_coverage(faces, coverage), True),
        ("Warm sand in recessed joints", Image.fromarray(encode_rgb(mortar)).convert("RGBA"), True),
        ("Linear height · 0–40 mm", Image.fromarray(height_u8).convert("RGBA"), False),
    ])

    height_m = height_u8.astype(np.float32) * (0.04 / 255)
    dx = (np.roll(height_m, -1, axis=1) - np.roll(height_m, 1, axis=1)) * (PER_METRE / 2)
    dz = (np.roll(height_m, -1, axis=0) - np.roll(height_m, 1, axis=0)) * (PER_METRE / 2)
    normal = np.stack((-dx, dz, np.ones_like(dx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    Image.fromarray(encode_rgb((normal * 0.5 + 0.5) * 255)).save(TEXTURES / "handlaid_sandstone_normal.png")
    (WORK / "stones.json").write_text(json.dumps(stones), encoding="utf-8")


if __name__ == "__main__":
    WORK.mkdir(parents=True, exist_ok=True)
    author_tile()
