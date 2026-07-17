"""Pure-Python VT2 authoring contracts shared by Blender and unit tests."""

from __future__ import annotations

import re


VERSION = (0, 3, 0)
VERSION_STRING = ".".join(str(part) for part in VERSION)
SAFE_NAME_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
POSE_PATH_PATTERN = re.compile(
    r'^pose\.bones\["(?P<bone>(?:\\.|[^"\\])+)"\]\.'
    r"(?P<channel>location|rotation_euler|rotation_quaternion|scale)$"
)
MIRROR_MARKERS = (
    ("j_left", "j_right"),
    ("_left", "_right"),
    (".L", ".R"),
    ("_L", "_R"),
    ("-L", "-R"),
)


def safe_name(value, fallback="vt2_asset"):
    name = re.sub(r"[^A-Za-z0-9_]", "_", (value or "").strip())
    name = re.sub(r"_+", "_", name).strip("_")
    if not name:
        name = fallback
    if name[0].isdigit():
        name = "_" + name
    return name


def is_safe_name(value):
    return bool(SAFE_NAME_PATTERN.fullmatch(value or ""))


def export_filename(asset_name, kind, clip_name=None):
    asset = safe_name(asset_name)
    if kind == "model":
        return f"{asset}_3p.fbx"
    if kind == "animation":
        return f"{asset}_{safe_name(clip_name, 'clip')}.fbx"
    raise ValueError(f"Unsupported VT2 export kind: {kind}")


def mirrored_bone_name(name, direction):
    if direction not in {"LEFT_TO_RIGHT", "RIGHT_TO_LEFT"}:
        raise ValueError(f"Unsupported mirror direction: {direction}")
    for left_marker, right_marker in MIRROR_MARKERS:
        source, target = (
            (left_marker, right_marker)
            if direction == "LEFT_TO_RIGHT"
            else (right_marker, left_marker)
        )
        if source in name:
            return name.replace(source, target, 1)
    return None


def mirrored_bone_pairs(bone_names, direction, selected_names=None):
    names = set(bone_names)
    selected = set(selected_names) if selected_names is not None else None
    pairs = []
    for source in sorted(names):
        if selected is not None and source not in selected:
            continue
        target = mirrored_bone_name(source, direction)
        if target in names and target != source:
            pairs.append((source, target))
    return pairs


def analyze_weight_rows(
    rows,
    maximum_influences=4,
    epsilon=1e-6,
    normalization_tolerance=1e-3,
):
    unweighted = []
    over_limit = []
    not_normalized = []
    maximum = 0

    for vertex_index, row in enumerate(rows):
        active = [float(weight) for weight in row if float(weight) > epsilon]
        maximum = max(maximum, len(active))
        if not active:
            unweighted.append(vertex_index)
            continue
        if len(active) > maximum_influences:
            over_limit.append(vertex_index)
        if abs(sum(active) - 1.0) > normalization_tolerance:
            not_normalized.append(vertex_index)

    return {
        "max_influences": maximum,
        "not_normalized": not_normalized,
        "over_limit": over_limit,
        "unweighted": unweighted,
        "vertices": len(rows),
    }


def parse_pose_path(data_path):
    match = POSE_PATH_PATTERN.fullmatch(data_path or "")
    if not match:
        return None
    bone = match.group("bone").replace(r'\"', '"').replace(r"\\", "\\")
    return bone, match.group("channel")


def classify_action_paths(data_paths, bone_names, root_bones):
    bones = set(bone_names)
    roots = set(root_bones)
    result = {
        "non_root_location": [],
        "other": [],
        "rotation": [],
        "scale": [],
        "unknown_bones": [],
    }

    for data_path in sorted(set(data_paths)):
        parsed = parse_pose_path(data_path)
        if not parsed:
            result["other"].append(data_path)
            continue
        bone, channel = parsed
        if bone not in bones:
            result["unknown_bones"].append(bone)
        if channel == "location" and bone not in roots:
            result["non_root_location"].append(bone)
        elif channel == "scale":
            result["scale"].append(bone)
        elif channel.startswith("rotation_"):
            result["rotation"].append(bone)

    for key in result:
        result[key] = sorted(set(result[key]))
    return result


def issue(severity, code, message, object_name=None):
    item = {"severity": severity, "code": code, "message": message}
    if object_name:
        item["object"] = object_name
    return item
