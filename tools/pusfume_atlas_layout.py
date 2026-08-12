"""Load the shared texture-atlas layout for Pusfume's native pipeline."""

import json
import os


LAYOUT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pusfume_atlas_layout.json")
with open(LAYOUT_PATH, encoding="utf-8") as layout_file:
    LAYOUT = json.load(layout_file)

ATLAS_SIZE = LAYOUT["atlas_size"]
ATLAS_REGIONS = {}
for material_name, material in LAYOUT["materials"].items():
    tile = LAYOUT["tiles"][material["tile"]]
    width, height = tile["size"]
    center_x, center_y = tile["center"]
    inset = tile["inset"]
    origin_x = tile["origin"][0] + center_x * width + inset
    origin_y = tile["origin"][1] + center_y * height + inset
    sample_width = width - 2 * inset
    sample_height = height - 2 * inset
    region = {
        "origin": (origin_x, origin_y),
        "size": (sample_width, sample_height),
        "allowed_min": (
            -center_x - inset / sample_width,
            -center_y - inset / sample_height,
        ),
        "allowed_max": (
            tile["grid"][0] - center_x + inset / sample_width,
            tile["grid"][1] - center_y + inset / sample_height,
        ),
    }
    if material["repeat"]:
        region["repeat"] = True
        region["center"] = region.pop("origin")
    ATLAS_REGIONS[material_name] = region
