"""Cut a magenta-backed prop sheet into transparent PNGs. Requires Pillow, NumPy and SciPy."""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ASSET_DIR = Path(__file__).resolve().parents[1] / "assets"
PADDING = 8
MIN_COMPONENT_AREA = 24
DETAIL_LINK_RADIUS = 5


def key_magenta(sheet):
    rgba = np.array(sheet, dtype=np.float32) / 255
    rgb = rgba[..., :3]
    red, green, blue = np.moveaxis(rgb, -1, 0)
    magenta = np.minimum(red, blue) - green

    # The range tolerates color variation in a painted or compressed screen.
    coverage = np.clip((0.67 - magenta) / (0.67 - 0.14), 0, 1)
    coverage = coverage * coverage * (3 - 2 * coverage)

    # Remove the screen contribution at soft edges and neutralize residual magenta.
    edges = (coverage > 0) & (coverage < 1)
    screen = np.array([1, 0, 1], dtype=np.float32)
    edge_coverage = coverage[edges, None]
    edge_rgb = np.clip((rgb[edges] - screen * (1 - edge_coverage)) / edge_coverage, 0, 1)
    edge_rgb[:, 2] = np.minimum(edge_rgb[:, 2], np.maximum(edge_rgb[:, 1], 0.18))
    rgb[edges] = edge_rgb
    rgba[..., 3] *= coverage
    return np.rint(rgba * 255).astype(np.uint8)


def cut_sheet(sheet_path, output_dir):
    with Image.open(sheet_path) as sheet:
        rgba = key_magenta(sheet.convert("RGBA"))

    visible = rgba[..., 3] > 0
    neighbors = np.ones((3, 3), dtype=bool)
    # Keep nearby petals, grass tips and loose pebbles with the prop they belong to.
    groups = ndimage.binary_dilation(visible, structure=neighbors, iterations=DETAIL_LINK_RADIUS)
    labels, _ = ndimage.label(groups, structure=neighbors)
    labels[~visible] = 0
    areas = np.bincount(labels.ravel())
    components = []
    for label, bounds in enumerate(ndimage.find_objects(labels), start=1):
        if bounds is not None and areas[label] >= MIN_COMPONENT_AREA:
            rows, columns = bounds
            components.append((rows.start, columns.start, label, bounds))

    # Assign stable IDs by the first occupied row, then the left edge.
    output_dir.mkdir(parents=True, exist_ok=True)
    for index, (_, _, label, bounds) in enumerate(sorted(components), start=1):
        cropped = rgba[bounds].copy()
        cropped[labels[bounds] != label] = 0
        height, width = cropped.shape[:2]
        canvas = Image.new("RGBA", (width + 2 * PADDING, height + 2 * PADDING))
        canvas.paste(Image.fromarray(cropped), (PADDING, PADDING))
        output = output_dir / f"prop_{index:02}.png"
        canvas.save(output)
        print(output.name)
    return len(components)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sheet", type=Path, help="Source sheet with a #FF00FF background")
    args = parser.parse_args()
    if not cut_sheet(args.sheet, ASSET_DIR):
        parser.exit(1, "No props found on the sheet.\n")


if __name__ == "__main__":
    main()
