import importlib.util
import pathlib
import struct
import sys
import tempfile
import unittest
import zlib

TOOLS = pathlib.Path(__file__).resolve().parent.parent / "tools"

def load(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

splice = load("splice_bundle_resource")
make_child = load("make_spliced_child")


def build_structured_bundle(path, resources):
    """resources: list of (type_hash, name_hash, payload_bytes)."""
    image = bytearray()
    image += struct.pack("<I", len(resources))
    image += bytes(256)
    for type_hash, name_hash, payload in resources:
        image += struct.pack("<QQ", type_hash, name_hash)
        image += struct.pack("<II", 0, len(payload))
    for type_hash, name_hash, payload in resources:
        image += struct.pack("<QQ", type_hash, name_hash)
        image += struct.pack("<II", 1, 0)
        image += struct.pack("<III", 0, len(payload), 0)
        image += payload

    out = bytearray()
    out += struct.pack("<II", splice.VT2X_FORMAT, len(image))
    out += b"\x00\x00\x00\x00"
    for start in range(0, len(image), 0x10000):
        block = zlib.compress(bytes(image[start : start + 0x10000]), 9)
        out += struct.pack("<I", len(block))
        out += block
    path.write_bytes(bytes(out))
    return bytes(image)


def build_material_payload(bindings, variables=(), size=768,
                           parent=0x3D25339231384C80):
    payload = bytearray(size)
    struct.pack_into("<IIIIII", payload, 0, 43, 1, 24, size - 24,
                     0xFFFFFFFF, 0)
    position = 24
    struct.pack_into("<IQI", payload, position, 0, parent,
                     len(bindings))
    position += 16
    for channel, resource in bindings:
        struct.pack_into("<IQ", payload, position,
                         make_child._short_hash(channel), resource)
        position += 12
    struct.pack_into("<II", payload, position, 0, len(variables))
    position += 8
    value_offset = 0
    for name, values in variables:
        struct.pack_into("<IIIII", payload, position, len(values) - 1, 0,
                         make_child._short_hash(name), value_offset, 0)
        position += 20
        value_offset += len(values) * 4
    struct.pack_into("<I", payload, position, value_offset)
    position += 4
    for _, values in variables:
        struct.pack_into("<" + "f" * len(values), payload, position, *values)
        position += len(values) * 4
    return payload


class SpliceBundleResourceTests(unittest.TestCase):
    MAT = splice.murmur64a(b"material")
    TEX = splice.murmur64a(b"texture")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = pathlib.Path(self.tmp.name)
        self.bundle = self.dir / "test.mod_bundle"

    def tearDown(self):
        self.tmp.cleanup()

    def run_main(self, module, argv):
        saved = sys.argv
        sys.argv = argv
        try:
            return module.main()
        finally:
            sys.argv = saved

    def test_walk_matches_layout(self):
        resources = [
            (self.MAT, 0x1111, b"A" * 400),
            (self.TEX, 0x2222, b"B" * 70000),  # payload spans a block boundary
            (self.MAT, 0x3333, b"C" * 768),
        ]
        build_structured_bundle(self.bundle, resources)
        fmt, _, data = splice.read_bundle(self.bundle)
        count, index, records = splice.walk(data, fmt)
        self.assertEqual(count, 3)
        self.assertEqual([r["name"] for r in records], [0x1111, 0x2222, 0x3333])
        self.assertEqual(records[1]["total_payload"], 70000)
        self.assertEqual(index[1]["data_size"], 70000)

    def test_splice_grows_payload_and_updates_sizes(self):
        resources = [
            (self.MAT, 0x1111, b"A" * 400),
            (self.MAT, 0x3333, b"C" * 500),
        ]
        build_structured_bundle(self.bundle, resources)
        payload = self.dir / "payload.bin"
        payload.write_bytes(b"Z" * 768)

        rc = self.run_main(splice, [
            "splice_bundle_resource.py", str(self.bundle),
            "--type", "material", "--name", "hash:0000000000001111",
            "--payload", str(payload),
        ])
        self.assertEqual(rc, 0)

        fmt, _, data = splice.read_bundle(self.bundle)
        _, index, records = splice.walk(data, fmt)
        self.assertEqual(records[0]["versions"][0]["size"], 768)
        self.assertEqual(index[0]["data_size"], 768)
        start = records[0]["versions"][0]["payload_offset"]
        self.assertEqual(data[start : start + 768], b"Z" * 768)
        # sibling untouched
        start2 = records[1]["versions"][0]["payload_offset"]
        self.assertEqual(data[start2 : start2 + 500], b"C" * 500)

    def test_splice_missing_resource_fails(self):
        build_structured_bundle(self.bundle, [(self.MAT, 0x1111, b"A" * 16)])
        payload = self.dir / "payload.bin"
        payload.write_bytes(b"Z")
        rc = self.run_main(splice, [
            "splice_bundle_resource.py", str(self.bundle),
            "--type", "material", "--name", "hash:00000000000000FF",
            "--payload", str(payload),
        ])
        self.assertEqual(rc, 1)

    def test_make_spliced_child_patches_each_id_once(self):
        game_child = build_material_payload([
            ("texture_map_02af90f8", 0xDD74D8319F514D96),
            ("texture_map_27b67fd2", 0x45FFAEEF53695A86),
            ("texture_map_8bf37d8e", 0xE334A8CB6BCB5E6D),
        ])
        extracted = self.dir / "child.material"
        extracted.write_bytes(bytes(game_child))
        out = self.dir / "payload.bin"

        rc = self.run_main(make_child, [
            "make_spliced_child.py", "--extracted", str(extracted),
            "--resource", "hash:90BDF3BAC6F81BA8", "--expect-size", "768",
            "--map", "DD74D8319F514D96=C263ECB79A8DCEC0",
            "--map", "E334A8CB6BCB5E6D=A4215592F6297E57",
            "--expect-texture", "texture_map_02af90f8=C263ECB79A8DCEC0",
            "--expect-texture", "texture_map_27b67fd2=45FFAEEF53695A86",
            "--expect-texture", "texture_map_8bf37d8e=A4215592F6297E57",
            "--out", str(out),
        ])
        self.assertEqual(rc, 0)
        patched = out.read_bytes()
        self.assertEqual(struct.unpack_from("<Q", patched, 28)[0], 0x3D25339231384C80)
        bindings = make_child.read_texture_bindings(patched)
        self.assertEqual(bindings[make_child._short_hash("texture_map_02af90f8")],
                         0xC263ECB79A8DCEC0)
        self.assertEqual(bindings[make_child._short_hash("texture_map_27b67fd2")],
                         0x45FFAEEF53695A86)
        self.assertEqual(bindings[make_child._short_hash("texture_map_8bf37d8e")],
                         0xA4215592F6297E57)

    def test_make_spliced_laurel_whisker_child_preserves_contract(self):
        laurel_child = build_material_payload([
            ("texture_map_59cd86b9", 0xCDA03B9B0226037A),
            ("texture_map_b788717c", 0xD3FD8377A3DE498A),
            ("texture_map_c0ba2942", 0xC9CF19C214612D75),
        ], variables=[("alpha_threshold", (0.5,))], size=128,
            parent=0xF85B289742D5D69A)
        extracted = self.dir / "laurel.material"
        extracted.write_bytes(bytes(laurel_child))
        out = self.dir / "whisker.bin"

        rc = self.run_main(make_child, [
            "make_spliced_child.py", "--extracted", str(extracted),
            "--resource", "hash:C70B1AAD3B363E24", "--expect-size", "128",
            "--expect-parent", "F85B289742D5D69A",
            "--map", "C9CF19C214612D75=7F060B4938ADCF12",
            "--map", "CDA03B9B0226037A=950FC5950CCEBCD0",
            "--map", "D3FD8377A3DE498A=BEB4D8D9891A6D4A",
            "--expect-texture", "texture_map_c0ba2942=7F060B4938ADCF12",
            "--expect-texture", "texture_map_59cd86b9=950FC5950CCEBCD0",
            "--expect-texture", "texture_map_b788717c=BEB4D8D9891A6D4A",
            "--out", str(out),
        ])

        self.assertEqual(rc, 0)
        patched = out.read_bytes()
        self.assertEqual(len(patched), 128)
        self.assertEqual(struct.unpack_from("<Q", patched, 28)[0],
                         0xF85B289742D5D69A)
        alpha_offset = make_child.read_variable_bindings(patched)[
            make_child._short_hash("alpha_threshold")][1]
        self.assertAlmostEqual(struct.unpack_from("<f", patched, alpha_offset)[0],
                               0.5)

    def test_make_spliced_child_rejects_wrong_parent(self):
        child = build_material_payload([
            ("texture_map_c0ba2942", 0xC9CF19C214612D75),
        ], size=128, parent=0xF85B289742D5D69A)
        extracted = self.dir / "child.material"
        extracted.write_bytes(bytes(child))

        rc = self.run_main(make_child, [
            "make_spliced_child.py", "--extracted", str(extracted),
            "--resource", "hash:C70B1AAD3B363E24",
            "--expect-parent", "0000000000000001",
            "--map", "C9CF19C214612D75=7F060B4938ADCF12",
            "--out", str(self.dir / "payload.bin"),
        ])
        self.assertEqual(rc, 1)

    def test_make_spliced_child_rejects_wrong_channel_binding(self):
        game_child = build_material_payload([
            ("texture_map_02af90f8", 0xDD74D8319F514D96),
        ])
        extracted = self.dir / "child.material"
        extracted.write_bytes(bytes(game_child))
        rc = self.run_main(make_child, [
            "make_spliced_child.py", "--extracted", str(extracted),
            "--resource", "hash:90BDF3BAC6F81BA8",
            "--map", "DD74D8319F514D96=C263ECB79A8DCEC0",
            "--expect-texture", "texture_map_27b67fd2=45FFAEEF53695A86",
            "--out", str(self.dir / "payload.bin"),
        ])
        self.assertEqual(rc, 1)

    def test_make_spliced_child_sets_reflected_vector(self):
        game_child = build_material_payload(
            [("texture_map_02af90f8", 0xDD74D8319F514D96)],
            [("emissive_color", (14.2, 25.3, 2.0))])
        extracted = self.dir / "child.material"
        extracted.write_bytes(bytes(game_child))
        out = self.dir / "payload.bin"
        rc = self.run_main(make_child, [
            "make_spliced_child.py", "--extracted", str(extracted),
            "--resource", "hash:90BDF3BAC6F81BA8",
            "--map", "DD74D8319F514D96=C263ECB79A8DCEC0",
            "--set-variable", "emissive_color=0,0,0",
            "--out", str(out),
        ])
        self.assertEqual(rc, 0)
        patched = out.read_bytes()
        variables = make_child.read_variable_bindings(patched)
        components, offset = variables[make_child._short_hash("emissive_color")]
        self.assertEqual(components, 3)
        self.assertEqual(struct.unpack_from("<fff", patched, offset),
                         (0.0, 0.0, 0.0))

    def test_eight_character_variable_name_is_not_parsed_as_hex(self):
        game_child = build_material_payload(
            [("texture_map_02af90f8", 0xDD74D8319F514D96)],
            [("tint_fur", (0.1, 0.2, 0.3))])
        extracted = self.dir / "child.material"
        extracted.write_bytes(bytes(game_child))
        out = self.dir / "payload.bin"
        rc = self.run_main(make_child, [
            "make_spliced_child.py", "--extracted", str(extracted),
            "--resource", "hash:90BDF3BAC6F81BA8",
            "--map", "DD74D8319F514D96=C263ECB79A8DCEC0",
            "--set-variable", "tint_fur=0,0,1",
            "--out", str(out),
        ])
        self.assertEqual(rc, 0)
        variables = make_child.read_variable_bindings(out.read_bytes())
        components, offset = variables[make_child._short_hash("tint_fur")]
        self.assertEqual(components, 3)
        self.assertEqual(struct.unpack_from("<fff", out.read_bytes(), offset),
                         (0.0, 0.0, 1.0))

    def test_make_spliced_child_rejects_wrong_variable_shape(self):
        game_child = build_material_payload(
            [("texture_map_02af90f8", 0xDD74D8319F514D96)],
            [("emissive_color", (14.2, 25.3, 2.0))])
        extracted = self.dir / "child.material"
        extracted.write_bytes(bytes(game_child))
        rc = self.run_main(make_child, [
            "make_spliced_child.py", "--extracted", str(extracted),
            "--resource", "hash:90BDF3BAC6F81BA8",
            "--map", "DD74D8319F514D96=C263ECB79A8DCEC0",
            "--set-variable", "emissive_color=0",
            "--out", str(self.dir / "payload.bin"),
        ])
        self.assertEqual(rc, 1)

    def test_make_spliced_child_rejects_ambiguous_id(self):
        game_child = bytearray(64)
        struct.pack_into("<Q", game_child, 8, 0xDD74D8319F514D96)
        struct.pack_into("<Q", game_child, 24, 0xDD74D8319F514D96)
        extracted = self.dir / "child.material"
        extracted.write_bytes(bytes(game_child))
        rc = self.run_main(make_child, [
            "make_spliced_child.py", "--extracted", str(extracted),
            "--resource", "hash:90BDF3BAC6F81BA8",
            "--map", "DD74D8319F514D96=C263ECB79A8DCEC0",
            "--out", str(self.dir / "payload.bin"),
        ])
        self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
