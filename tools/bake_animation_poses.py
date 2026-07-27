"""Bake compiled eye-frame Assassin clips into a Lua pose module.

Every engine playback path re-anchors this unit's animated bones at the
world origin (issue #46, v0.6.90-96 telemetry: crossfade "normal",
crossfade "offset", and state-machine playback all measured). The one
composition path proven live (v0.6.95) is per-frame Lua control of the
unit followed by World.update_unit. This tool therefore bakes the compiled
clips into plain pose data the runtime replays bone by bone.

Positions in these clips are static or near-static (Janfon's authored
pose translations, e.g. the upper-arm socket offsets, plus a small
animated spine sway that collapses to its last key); rotations carry the
motion. The module stores, per clip: duration, per-bone static local
position, and per-bone sparse rotation keys (time + quaternion) that the
runtime nlerps between.

Usage:
  py bake_animation_poses.py -- BONES_FILE UNIT_FILE OUTPUT.lua CLIP=PATH [CLIP=PATH ...]

Self-gate: forward kinematics at mid-clip must place j_righthand within
1.2 m of the rig root or the bake fails.
"""

import importlib.util
import math
import pathlib
import struct
import sys

_SCENE = pathlib.Path(__file__).resolve().parent / "stingray_unit_scene.py"
_spec = importlib.util.spec_from_file_location("stingray_unit_scene", _SCENE)
_scene = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_scene)

PACKED_RANGE = 10.0
PACKED_STEP = 20.0 / (2**16)


def unpack_pos(buf, at):
    x, y, z = struct.unpack_from("<HHH", buf, at)
    return (x * PACKED_STEP - PACKED_RANGE, y * PACKED_STEP - PACKED_RANGE,
            z * PACKED_STEP - PACKED_RANGE)


def unpack_quat(buf, at):
    (dword,) = struct.unpack_from("<I", buf, at)
    biggest = dword & 3
    c1 = (((dword >> 2) & 0x3FF) * 0.0014648438) - 0.75
    c2 = (((dword >> 12) & 0x3FF) * 0.0014648438) - 0.75
    c3 = ((dword >> 22) * 0.0014648438) - 0.75
    q = [0.0, 0.0, 0.0, 0.0]
    q[biggest] = math.sqrt(max(0.0, 1 - c1 * c1 - c2 * c2 - c3 * c3))
    q[(biggest + 1) & 3] = c1
    q[(biggest + 2) & 3] = c2
    q[(biggest + 3) & 3] = c3
    # stored order x,y,z,w
    return (q[0], q[1], q[2], q[3])


def read_bones(path):
    data = pathlib.Path(path).read_bytes()
    bone_count, lod_count = struct.unpack_from("<II", data, 0)
    hashes = list(struct.unpack_from("<%dI" % bone_count, data, 8))
    blob = data[8 + bone_count * 4 + lod_count * 4:]
    names = [n.decode() for n in blob.split(b"\x00") if n][:bone_count]
    return names, hashes


def parse_clip(path, num_expected):
    clip = pathlib.Path(path).read_bytes()
    num_bones = struct.unpack_from("<I", clip, 4)[0]
    duration = struct.unpack_from("<f", clip, 8)[0]
    num_beats = struct.unpack_from("<I", clip, 16)[0]
    if num_bones != num_expected:
        raise SystemExit(f"{path}: {num_bones} bones, expected {num_expected}")
    offset = 20 + num_beats * 8
    marker = struct.unpack_from("<H", clip, offset)[0]
    offset += 2
    positions = {}
    rotations = {}
    if marker == 1:
        for i in range(num_bones):
            positions[i] = unpack_pos(clip, offset)
            rotations[i] = [(0.0, unpack_quat(clip, offset + 6))]
            offset += 16
    elif marker == 7:
        for i in range(num_bones):
            positions[i] = struct.unpack_from("<fff", clip, offset)
            x, y, z, w = struct.unpack_from("<ffff", clip, offset + 12)
            rotations[i] = [(0.0, (x, y, z, w))]
            offset += 40
    else:
        raise SystemExit(f"{path}: unknown sync marker {marker}")

    while offset < len(clip):
        short1 = struct.unpack_from("<H", clip, offset)[0]
        item = (short1 & 0xC000) if short1 & 0xC000 else short1
        if item in (0x4000, 0x8000, 0xC000):
            short2 = struct.unpack_from("<H", clip, offset + 2)[0]
            combined = (short1 << 16) | short2
            bone_id = (combined >> 20) & 0x3FF
            t = (combined & 0xFFFFF) * 0.001
            if item == 0x8000:
                positions[bone_id] = unpack_pos(clip, offset + 4)
                offset += 10
            elif item == 0xC000:
                rotations[bone_id].append((t, unpack_quat(clip, offset + 4)))
                offset += 8
            else:
                offset += 10
        elif item == 4:
            bone_id = struct.unpack_from("<H", clip, offset + 2)[0]
            positions[bone_id] = struct.unpack_from("<fff", clip, offset + 8)
            offset += 20
        elif item == 5:
            bone_id = struct.unpack_from("<H", clip, offset + 2)[0]
            t = struct.unpack_from("<f", clip, offset + 4)[0]
            x, y, z, w = struct.unpack_from("<ffff", clip, offset + 8)
            rotations[bone_id].append((t, (x, y, z, w)))
            offset += 24
        elif item == 6:
            offset += 20
        elif item == 2:
            offset += 10
        elif item == 3:
            break
        else:
            raise SystemExit(f"{path}: unknown item {item} at {offset}")

    for keys in rotations.values():
        keys.sort(key=lambda entry: entry[0])
    return duration, positions, rotations


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def quat_rot(q, v):
    qx, qy, qz, qw = q
    uvx = qy * v[2] - qz * v[1]
    uvy = qz * v[0] - qx * v[2]
    uvz = qx * v[1] - qy * v[0]
    uuvx = qy * uvz - qz * uvy
    uuvy = qz * uvx - qx * uvz
    uuvz = qx * uvy - qy * uvx
    return (
        v[0] + 2 * (qw * uvx + uuvx),
        v[1] + 2 * (qw * uvy + uuvy),
        v[2] + 2 * (qw * uvz + uuvz),
    )


def sample_rotation(keys, t):
    if t <= keys[0][0]:
        return keys[0][1]
    for index in range(1, len(keys)):
        if keys[index][0] >= t:
            t0, q0 = keys[index - 1]
            t1, q1 = keys[index]
            alpha = 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
            dot = sum(a * b for a, b in zip(q0, q1))
            sign = 1.0 if dot >= 0 else -1.0
            blended = tuple(
                (1 - alpha) * a + alpha * sign * b for a, b in zip(q0, q1))
            norm = math.sqrt(sum(c * c for c in blended)) or 1.0
            return tuple(c / norm for c in blended)
    return keys[-1][1]


def fk_hand(names, hashes, unit_path, positions, rotations, t):
    scene = _scene.read_scene_graph(unit_path)
    nodes = scene["nodes"]
    by_hash = {}
    for node in nodes:
        by_hash.setdefault(node["name_hash"], node)
    local_pos = {}
    local_rot = {}
    for node in nodes:
        local = node["local"]
        local_pos[node["index"]] = (local[9], local[10], local[11])
        m = local[0:9]
        # matrix->quat (w last)
        tr = m[0] + m[4] + m[8]
        if tr > 0:
            s = math.sqrt(tr + 1.0) * 2
            local_rot[node["index"]] = (
                (m[7] - m[5]) / s, (m[2] - m[6]) / s, (m[3] - m[1]) / s, 0.25 * s)
        else:
            local_rot[node["index"]] = (0.0, 0.0, 0.0, 1.0)
    for bone_id in range(len(names)):
        node = by_hash[hashes[bone_id]]
        local_pos[node["index"]] = positions[bone_id]
        local_rot[node["index"]] = sample_rotation(rotations[bone_id], t)
    by_index = {n["index"]: n for n in nodes}
    world_pos = {}
    world_rot = {}
    for node in nodes:
        index = node["index"]
        parent_type, parent_index = node["parent"]
        if parent_type == 0:
            world_pos[index] = local_pos[index]
            world_rot[index] = local_rot[index]
        else:
            world_pos[index] = tuple(
                p + q for p, q in zip(
                    world_pos[parent_index],
                    quat_rot(world_rot[parent_index], local_pos[index])))
            world_rot[index] = quat_mul(world_rot[parent_index], local_rot[index])
    hand_index = by_hash[hashes[names.index("j_righthand")]]["index"]
    return world_pos[hand_index]


EXPECTED_HAND_TOLERANCE = 0.06


def main():
    arguments = [a for a in sys.argv[1:] if a != "--"]
    # --expect=CLIP:x,y,z pins the compiled mid-clip j_righthand world
    # position (already shifted into the eye frame by the caller) against
    # Janfon's authored pose. This is the end-to-end fidelity gate: the
    # v0.6.8x-98 exports silently splayed the arms 0.18 m wide and every
    # per-stage audit passed.
    expected_hands = {}
    remaining = []
    for argument in arguments:
        if argument.startswith("--expect="):
            spec = argument[len("--expect="):]
            clip_name, coordinates = spec.split(":", 1)
            expected_hands[clip_name] = tuple(
                float(value) for value in coordinates.split(","))
        else:
            remaining.append(argument)
    arguments = remaining
    if len(arguments) < 4:
        raise SystemExit(__doc__)
    bones_path, unit_path, output_path = arguments[:3]
    names, hashes = read_bones(bones_path)

    lines = ["-- GENERATED by tools/bake_animation_poses.py - do not edit.",
             "-- Per-bone local poses baked from the compiled eye-frame clips",
             "-- (issue #46: engine playback re-anchors this unit at the",
             "-- world origin; the runtime replays these poses in Lua).",
             "return {"]
    for spec in arguments[3:]:
        clip_name, clip_path = spec.split("=", 1)
        duration, positions, rotations = parse_clip(clip_path, len(names))
        hand = fk_hand(names, hashes, unit_path, positions, rotations,
                       duration * 0.5)
        magnitude = math.sqrt(sum(c * c for c in hand))
        if magnitude > 1.2:
            raise SystemExit(
                f"{clip_name}: FK hand {magnitude:.3f} m from root - bake gate failed")
        total_keys = sum(len(keys) for keys in rotations.values())
        print(f"BAKE {clip_name}: duration={duration:.3f} rot_keys={total_keys} "
              f"fk_hand=({hand[0]:.3f}, {hand[1]:.3f}, {hand[2]:.3f})")
        expected = expected_hands.get(clip_name)
        if expected:
            # Compare the settled END pose: fast clips lose mid-swing
            # peaks to compile rotation culling, but systematic pose
            # corruption shifts every frame including the settled one.
            end_hand = fk_hand(names, hashes, unit_path, positions,
                               rotations, duration)
            distance = math.sqrt(sum(
                (a - b) ** 2 for a, b in zip(end_hand, expected)))
            print(f"EXPECT {clip_name}: end_fk=({end_hand[0]:.3f}, "
                  f"{end_hand[1]:.3f}, {end_hand[2]:.3f}) authored=({expected[0]:.3f}, "
                  f"{expected[1]:.3f}, {expected[2]:.3f}) error={distance:.4f} m")
            if distance > EXPECTED_HAND_TOLERANCE:
                raise SystemExit(
                    f"{clip_name}: compiled end-of-clip hand {distance:.4f} m from "
                    f"the authored pose - fidelity gate failed")
        lines.append(f"    {clip_name} = {{")
        lines.append(f"        duration = {duration:.6f},")
        lines.append("        bones = {")
        for bone_id, name in enumerate(names):
            pos = positions[bone_id]
            keys = rotations[bone_id]
            key_text = ", ".join(
                "{%.4f, %.6f, %.6f, %.6f, %.6f}" % (t, q[0], q[1], q[2], q[3])
                for t, q in keys)
            lines.append(
                '            ["%s"] = { p = {%.6f, %.6f, %.6f}, k = {%s} },'
                % (name, pos[0], pos[1], pos[2], key_text))
        lines.append("        },")
        lines.append("    },")
    lines.append("}")
    pathlib.Path(output_path).write_text("\n".join(lines) + "\n",
                                         encoding="utf-8")
    print(f"BAKE OUTPUT {output_path} ({pathlib.Path(output_path).stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
