"""Forward-kinematics a compiled clip over the compiled unit hierarchy.

Reproduces what the engine computes for j_righthand so clip-space defects
can be measured offline instead of via live tests.
"""
import math
import struct
import sys

sys.path.insert(0, r"C:\Users\danjo\source\repos\vt2-pusfume-1p\tools")
from stingray_unit_scene import read_scene_graph

C = r"C:\Users\danjo\source\repos\vt2-pusfume-1p\.build\native-workshop\.temp\pusfumeV2\compile"
BONES = C + r"\data\69\697ebad1532817f0"
UNIT = C + r"\data\f9\f98764bf2b682b0d"
CLIPS = {
    "rewritten_equip": r"C:\Users\danjo\source\repos\vt2-pusfume-1p\.build\generated-native\rewritten_claws_equip.animation",
    "rewritten_idle": r"C:\Users\danjo\source\repos\vt2-pusfume-1p\.build\generated-native\rewritten_claws_idle.animation",
}
SAMPLE_T = 0.9


def quat_mul(a, b):
    aw, ax, ay, az = a
    bw, bx, by, bz = b
    return (
        aw * bw - ax * bx - ay * by - az * bz,
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
    )


def quat_rot(q, v):
    qw, qx, qy, qz = q
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


def mat_to_quat(m):
    # m = row-major 3x3 (rows 0..2 of the 15-float local)
    t = m[0] + m[4] + m[8]
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        return (0.25 * s, (m[7] - m[5]) / s, (m[2] - m[6]) / s, (m[3] - m[1]) / s)
    if m[0] > m[4] and m[0] > m[8]:
        s = math.sqrt(1.0 + m[0] - m[4] - m[8]) * 2
        return ((m[7] - m[5]) / s, 0.25 * s, (m[1] + m[3]) / s, (m[2] + m[6]) / s)
    if m[4] > m[8]:
        s = math.sqrt(1.0 + m[4] - m[0] - m[8]) * 2
        return ((m[2] - m[6]) / s, (m[1] + m[3]) / s, 0.25 * s, (m[5] + m[7]) / s)
    s = math.sqrt(1.0 + m[8] - m[0] - m[4]) * 2
    return ((m[3] - m[1]) / s, (m[2] + m[6]) / s, (m[5] + m[7]) / s, 0.25 * s)


# --- bones table (clip bone index -> name) ---
data = open(BONES, "rb").read()
bone_count, lod_count = struct.unpack_from("<II", data, 0)
hashes = list(struct.unpack_from("<%dI" % bone_count, data, 8))
names_blob = data[8 + bone_count * 4 + lod_count * 4:]
names = [n.decode() for n in names_blob.split(b"\x00") if n][:bone_count]

# --- unit hierarchy ---
scene = read_scene_graph(UNIT)
nodes = scene["nodes"]
by_hash = {}
for node in nodes:
    by_hash.setdefault(node["name_hash"], node)

# clip bone -> unit node
clip_to_node = [by_hash[h] for h in hashes]
node_index_by_hash = {n["name_hash"]: n["index"] for n in nodes}

STEP = 20.0 / (2**16)


def unpack_pos(buf, at):
    x, y, z = struct.unpack_from("<HHH", buf, at)
    return (x * STEP - 10, y * STEP - 10, z * STEP - 10)


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
    # stored order x,y,z,w -> (w,x,y,z)
    return (q[3], q[0], q[1], q[2])


for label, path in CLIPS.items():
    clip = open(path, "rb").read()
    num_bones = struct.unpack_from("<I", clip, 4)[0]
    num_beats = struct.unpack_from("<I", clip, 16)[0]
    off = 20 + num_beats * 8
    marker = struct.unpack_from("<H", clip, off)[0]
    off += 2
    pose_pos = {}
    pose_rot = {}
    if marker == 1:
        for i in range(num_bones):
            pose_pos[i] = unpack_pos(clip, off)
            pose_rot[i] = unpack_quat(clip, off + 6)
            off += 16
    elif marker == 7:
        for i in range(num_bones):
            pose_pos[i] = struct.unpack_from("<fff", clip, off)
            x, y, z, w = struct.unpack_from("<ffff", clip, off + 12)
            pose_rot[i] = (w, x, y, z)
            off += 40
    else:
        raise SystemExit(f"unexpected sync marker {marker}")

    # stream: latest key at or before SAMPLE_T wins
    while off < len(clip):
        short1 = struct.unpack_from("<H", clip, off)[0]
        item = (short1 & 0xC000) if short1 & 0xC000 else short1
        if item in (0x4000, 0x8000, 0xC000):
            short2 = struct.unpack_from("<H", clip, off + 2)[0]
            combined = (short1 << 16) | short2
            bone_id = (combined >> 20) & 0x3FF
            t = (combined & 0xFFFFF) * 0.001
            if item == 0x8000:
                if t <= SAMPLE_T:
                    pose_pos[bone_id] = unpack_pos(clip, off + 4)
                off += 10
            elif item == 0xC000:
                if t <= SAMPLE_T:
                    pose_rot[bone_id] = unpack_quat(clip, off + 4)
                off += 8
            else:
                off += 10
        elif item == 4:
            bone_id = struct.unpack_from("<H", clip, off + 2)[0]
            t = struct.unpack_from("<f", clip, off + 4)[0]
            if t <= SAMPLE_T:
                pose_pos[bone_id] = struct.unpack_from("<fff", clip, off + 8)
            off += 20
        elif item == 5:
            bone_id = struct.unpack_from("<H", clip, off + 2)[0]
            t = struct.unpack_from("<f", clip, off + 4)[0]
            if t <= SAMPLE_T:
                x, y, z, w = struct.unpack_from("<ffff", clip, off + 8)
                pose_rot[bone_id] = (w, x, y, z)
            off += 24
        elif item == 6:
            off += 20
        elif item == 2:
            off += 10
        elif item == 3:
            break
        else:
            raise SystemExit(f"unknown item {item} at {off}")

    # local transforms per unit node: clip-driven where a track exists,
    # unit rest otherwise
    local_pos = {}
    local_rot = {}
    for node in nodes:
        local = node["local"]
        local_pos[node["index"]] = (local[9], local[10], local[11])
        local_rot[node["index"]] = mat_to_quat(local[0:9])
    for bone_id in range(num_bones):
        node = clip_to_node[bone_id]
        local_pos[node["index"]] = pose_pos[bone_id]
        local_rot[node["index"]] = pose_rot[bone_id]

    # FK
    world_pos = {}
    world_rot = {}
    for node in nodes:  # parser returns nodes in index order; parents precede
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
            world_rot[index] = quat_mul(
                world_rot[parent_index], local_rot[index])

    print(f"===== {label} @ t={SAMPLE_T}s =====")
    for target in ("j_righthand", "j_lefthand", "camera_node", "j_rightforearm", "j_spine1", "root_point"):
        found = None
        for i, name in enumerate(names):
            if name == target:
                found = clip_to_node[i]["index"]
                break
        if found is None:
            print(f"  {target}: not in bones table")
            continue
        p = world_pos[found]
        print("  %-16s world=(%.3f, %.3f, %.3f) |%.3f m|"
              % (target, p[0], p[1], p[2], math.sqrt(sum(c * c for c in p))))
