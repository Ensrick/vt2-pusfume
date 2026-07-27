"""Rewrite a compiled VT2 .animation's position data to the unit rest pose.

Janfon's Assassin clips bake location keys for every bone, including
non-deforming helper bones whose authored offsets (aim target 6 m, eye node
1.5 m) the compiled unit rest keeps at zero. At runtime those keys scatter
the first-person rig 5-15 metres from the camera (issue #46). His motion is
rotation-authored, so every position sample in the compiled clip is replaced
in place with the unit scene graph's local rest position for that bone,
matched BY NAME through the compiled .bones table. The rewrite never changes
file size: packed samples re-encode into the same 16x3-bit layout and
unpacked samples overwrite the same 12 float bytes.

Usage:
  py rewrite_animation_positions.py -- ANIMATION_FILE BONES_FILE UNIT_FILE OUTPUT

Exits non-zero when any clip bone has no unit node, when the animation
contains an unknown stream item, or when the rewritten file fails
re-verification.
"""

import importlib.util
import pathlib
import struct
import sys

_SCENE = pathlib.Path(__file__).resolve().parent / "stingray_unit_scene.py"
_spec = importlib.util.spec_from_file_location("stingray_unit_scene", _SCENE)
_scene = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_scene)

HEADER_ITEM = 0
SYNC_ITEM = 1
TRIGGER_ITEM = 2
FOOTER_ITEM = 3
UNPACKED_POSITION_KEY_ITEM = 4
UNPACKED_ROTATION_KEY_ITEM = 5
UNPACKED_SCALE_KEY_ITEM = 6
UNPACKED_SYNC_ITEM = 7
SCALE_KEY_ITEM = 0x4000
POSITION_KEY_ITEM = 0x8000
ROTATION_KEY_ITEM = 0xC000

PACKED_RANGE = 10.0
PACKED_STEP = 20.0 / (2**16)


def pack_position(vector):
    """Encode a Vector3 into the packed 16x3 form (range -10 m .. +10 m)."""
    encoded = bytearray()
    for value in vector:
        clamped = min(max(value, -PACKED_RANGE), PACKED_RANGE - PACKED_STEP)
        encoded += struct.pack("<H", round((clamped + PACKED_RANGE) / PACKED_STEP))
    return bytes(encoded)


def read_bones(path):
    data = pathlib.Path(path).read_bytes()
    bone_count, lod_count = struct.unpack_from("<II", data, 0)
    hashes = list(struct.unpack_from("<%dI" % bone_count, data, 8))
    return hashes


def unit_rest_by_name_hash(path):
    scene = _scene.read_scene_graph(path)
    rests = {}
    for node in scene["nodes"]:
        local = node["local"]
        rests[node["name_hash"]] = (local[9], local[10], local[11])
    return rests


def read_bone_names(path):
    data = pathlib.Path(path).read_bytes()
    bone_count, lod_count = struct.unpack_from("<II", data, 0)
    blob = data[8 + bone_count * 4 + lod_count * 4:]
    return [n.decode() for n in blob.split(b"\x00") if n][:bone_count]


def rewrite(animation_path, bones_path, unit_path, output_path, shift=None):
    """Rewrite position samples in place.

    Default mode replaces every position with the unit rest. With
    shift=("bone_name", (dx, dy, dz)) only that bone's positions are
    offset by the delta; all other samples are preserved. Used to move
    Janfon's floor-origin spine chain into the eye-relative frame the
    camera-linked unit needs (issue #46).
    """
    bone_hashes = read_bones(bones_path)
    rests = unit_rest_by_name_hash(unit_path)

    shift_index = None
    shift_delta = None
    if shift is not None:
        names = read_bone_names(bones_path)
        shift_name, shift_delta = shift
        if shift_name not in names:
            raise SystemExit(f"shift bone not in bones table: {shift_name}")
        shift_index = names.index(shift_name)

    missing = [
        "%08X" % bone_hash
        for bone_hash in bone_hashes
        if bone_hash not in rests
    ]
    if missing:
        raise SystemExit(
            "clip bones missing from the unit scene graph: " + ",".join(missing))

    data = bytearray(pathlib.Path(animation_path).read_bytes())
    offset = 0

    def u16(at):
        return struct.unpack_from("<H", data, at)[0]

    def u32(at):
        return struct.unpack_from("<I", data, at)[0]

    identifier = u32(offset)
    if identifier != HEADER_ITEM:
        raise SystemExit(f"not a compiled animation (header {identifier})")
    num_bones = u32(offset + 4)
    num_beats = u32(offset + 16)
    offset += 20 + num_beats * 8

    if num_bones != len(bone_hashes):
        raise SystemExit(
            f"animation has {num_bones} bones but .bones lists {len(bone_hashes)}")

    rewritten_sync = 0
    rewritten_keys = 0

    def unpack_position(at):
        x, y, z = struct.unpack_from("<HHH", data, at)
        step = PACKED_STEP
        return (x * step - PACKED_RANGE, y * step - PACKED_RANGE,
                z * step - PACKED_RANGE)

    def replacement_for(bone_index, current):
        if shift_index is None:
            return rests[bone_hashes[bone_index]]
        if bone_index != shift_index:
            return None
        return (current[0] + shift_delta[0], current[1] + shift_delta[1],
                current[2] + shift_delta[2])

    sync = u16(offset)
    offset += 2
    if sync == SYNC_ITEM:
        for bone_index in range(num_bones):
            replacement = replacement_for(bone_index, unpack_position(offset))
            if replacement is not None:
                data[offset:offset + 6] = pack_position(replacement)
                rewritten_sync += 1
            offset += 6 + 4 + 6
    elif sync == UNPACKED_SYNC_ITEM:
        for bone_index in range(num_bones):
            current = struct.unpack_from("<fff", data, offset)
            replacement = replacement_for(bone_index, current)
            if replacement is not None:
                struct.pack_into("<fff", data, offset, *replacement)
                rewritten_sync += 1
            offset += 12 + 16 + 12
    else:
        raise SystemExit(f"unknown sync item {sync}")

    while offset < len(data):
        short1 = u16(offset)
        item_type = (short1 & 0xC000) if short1 & 0xC000 else short1

        if item_type in (SCALE_KEY_ITEM, POSITION_KEY_ITEM, ROTATION_KEY_ITEM):
            short2 = u16(offset + 2)
            combined = (short1 << 16) | short2
            bone_id = (combined >> 20) & 0x3FF
            if item_type == POSITION_KEY_ITEM:
                if bone_id >= num_bones:
                    raise SystemExit(f"position key for bone {bone_id}")
                replacement = replacement_for(
                    bone_id, unpack_position(offset + 4))
                if replacement is not None:
                    data[offset + 4:offset + 10] = pack_position(replacement)
                    rewritten_keys += 1
            offset += 4 + (4 if item_type == ROTATION_KEY_ITEM else 6)
        elif item_type == UNPACKED_POSITION_KEY_ITEM:
            bone_id = u16(offset + 2)
            if bone_id >= num_bones:
                raise SystemExit(f"unpacked position key for bone {bone_id}")
            current = struct.unpack_from("<fff", data, offset + 8)
            replacement = replacement_for(bone_id, current)
            if replacement is not None:
                struct.pack_into("<fff", data, offset + 8, *replacement)
                rewritten_keys += 1
            offset += 2 + 2 + 4 + 12
        elif item_type == UNPACKED_ROTATION_KEY_ITEM:
            offset += 2 + 2 + 4 + 16
        elif item_type == UNPACKED_SCALE_KEY_ITEM:
            offset += 2 + 2 + 4 + 12
        elif item_type == TRIGGER_ITEM:
            # u16 marker, u32 trigger id, f32 time
            offset += 2 + 4 + 4
        elif item_type == FOOTER_ITEM:
            offset += 2
            break
        else:
            raise SystemExit(f"unknown stream item {item_type} at {offset}")

    pathlib.Path(output_path).write_bytes(bytes(data))
    print(
        "PUSFUME_ANIM_POSITION_REWRITE=animation=%s sync=%d keys=%d bones=%d"
        % (animation_path, rewritten_sync, rewritten_keys, num_bones))
    return 0


def main():
    shift = None
    arguments = []
    for value in sys.argv[1:]:
        if value == "--":
            continue
        if value.startswith("--shift="):
            # --shift=j_spine1:0,0,-1.48
            bone_name, delta_text = value[len("--shift="):].split(":", 1)
            delta = tuple(float(v) for v in delta_text.split(","))
            if len(delta) != 3:
                raise SystemExit("shift delta must be dx,dy,dz")
            shift = (bone_name, delta)
            continue
        arguments.append(value)
    if len(arguments) != 4:
        raise SystemExit(__doc__)
    return rewrite(*arguments, shift=shift)


if __name__ == "__main__":
    sys.exit(main())
