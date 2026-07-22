import pathlib
import sys
import tempfile
import unittest

from PIL import Image


ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import encode_linear_diffuse as encoder


class LinearDiffuseEncoderTests(unittest.TestCase):
    def test_transfer_function_matches_srgb_reference_points(self):
        self.assertEqual(0, encoder.linear_to_srgb_byte(0))
        self.assertEqual(255, encoder.linear_to_srgb_byte(255))
        self.assertEqual(127, encoder.linear_to_srgb_byte(54))

    def test_encoding_preserves_alpha(self):
        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory) / "source.png"
            output = pathlib.Path(directory) / "output.png"
            Image.new("RGBA", (1, 1), (54, 48, 43, 73)).save(source)
            encoder.encode_linear_diffuse(source, output)
            with Image.open(output) as image:
                self.assertEqual((127, 120, 114, 73), image.getpixel((0, 0)))


if __name__ == "__main__":
    unittest.main()
