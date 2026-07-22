"""Encode linear-authored diffuse pixels into an sRGB texture payload."""

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageStat


def linear_to_srgb_byte(value):
    linear = value / 255.0
    srgb = 12.92 * linear if linear <= 0.0031308 else 1.055 * math.pow(linear, 1 / 2.4) - 0.055
    return max(0, min(255, round(srgb * 255)))


LINEAR_TO_SRGB_LUT = [linear_to_srgb_byte(value) for value in range(256)]


def encode_linear_diffuse(source_path, output_path):
    with Image.open(source_path) as source:
        rgba = source.convert("RGBA")
        red, green, blue, alpha = rgba.split()
        encoded = Image.merge(
            "RGBA",
            (
                red.point(LINEAR_TO_SRGB_LUT),
                green.point(LINEAR_TO_SRGB_LUT),
                blue.point(LINEAR_TO_SRGB_LUT),
                alpha,
            ),
        )
        source_mean = ImageStat.Stat(rgba).mean[:3]
        encoded_mean = ImageStat.Stat(encoded).mean[:3]
        encoded.save(output_path, format="PNG")
    return {
        "encoded_mean": [round(value, 3) for value in encoded_mean],
        "output": str(output_path),
        "size": list(rgba.size),
        "source": str(source_path),
        "source_mean": [round(value, 3) for value in source_mean],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if not args.source.is_file():
        parser.error("source diffuse does not exist: %s" % args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result = encode_linear_diffuse(args.source, args.output)
    print("PUSFUME_LINEAR_DIFFUSE=" + json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
