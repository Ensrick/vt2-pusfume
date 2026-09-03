"""Measure whether Janfon's authored 1P rig can fit the VT2 donor rigidly.

Run through Blender:
    blender --background --factory-startup --disable-autoexec \
        --python tools/analyze_pusfume_1p_alignment.py -- INPUT.blend DONOR.unit
"""

from __future__ import annotations

import json
import os
import sys

import bpy
import numpy as np


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prepare_pusfume_1p_blend import (  # noqa: E402
    DONOR_NAME_FALLBACKS,
    blender_matrix_from_stingray,
    find_arms_and_rig,
    reset_bind_pose,
)
from stingray_unit_scene import read_scene_graph, short_hash  # noqa: E402


FIT_BONES = (
    "j_spine1",
    "j_leftshoulder",
    "j_leftarm",
    "j_leftforearm",
    "j_lefthand",
    "j_rightshoulder",
    "j_rightarm",
    "j_rightforearm",
    "j_righthand",
)


def arguments_after_separator():
    separator = sys.argv.index("--") if "--" in sys.argv else len(sys.argv)
    return sys.argv[separator + 1 :]


def solve_similarity(source, target):
    """Return scale, rotation and translation mapping source onto target."""
    source_center = source.mean(axis=0)
    target_center = target.mean(axis=0)
    source_zero = source - source_center
    target_zero = target - target_center
    covariance = target_zero.T @ source_zero / len(source)
    left, singular, right = np.linalg.svd(covariance)
    sign = np.ones(3)
    if np.linalg.det(left) * np.linalg.det(right) < 0:
        sign[-1] = -1
    rotation = left @ np.diag(sign) @ right
    variance = np.sum(source_zero * source_zero) / len(source)
    scale = float(np.sum(singular * sign) / variance)
    translation = target_center - scale * (rotation @ source_center)
    return scale, rotation, translation


def transformed(points, scale, rotation, translation):
    return (scale * (rotation @ points.T)).T + translation


def point_error(source, target):
    distances = np.linalg.norm(source - target, axis=1)
    return {
        "maximum": float(distances.max()),
        "mean": float(distances.mean()),
        "rms": float(np.sqrt(np.mean(distances * distances))),
    }


def main():
    arguments = arguments_after_separator()
    if len(arguments) != 2:
        raise SystemExit("Usage: analyze_pusfume_1p_alignment.py -- INPUT.blend DONOR.unit")
    blend_path, donor_path = (os.path.abspath(value) for value in arguments)
    bpy.ops.wm.open_mainfile(filepath=blend_path, load_ui=False)
    mesh, armature = find_arms_and_rig()
    reset_bind_pose(mesh, armature)

    donor_graph = read_scene_graph(donor_path)
    donor_by_hash = {node["name_hash"]: node for node in donor_graph["nodes"]}
    source_points = []
    target_points = []
    rows = []
    for bone_name in FIT_BONES:
        bone = armature.data.bones.get(bone_name)
        donor_name = bone_name
        donor = donor_by_hash.get(short_hash(donor_name))
        if donor is None:
            donor_name = DONOR_NAME_FALLBACKS.get(bone_name, bone_name)
            donor = donor_by_hash.get(short_hash(donor_name))
        if not bone or not donor:
            raise RuntimeError(f"Missing alignment pair {bone_name}->{donor_name}")
        source = (armature.matrix_world @ bone.matrix_local).translation
        target = blender_matrix_from_stingray(donor["world"]).translation
        source_points.append(tuple(source))
        target_points.append(tuple(target))
        rows.append({"source": bone_name, "target": donor_name})

    source_array = np.asarray(source_points, dtype=np.float64)
    target_array = np.asarray(target_points, dtype=np.float64)
    scale, rotation, translation = solve_similarity(source_array, target_array)
    fitted = transformed(source_array, scale, rotation, translation)
    for index, row in enumerate(rows):
        row["before"] = float(np.linalg.norm(source_array[index] - target_array[index]))
        row["after"] = float(np.linalg.norm(fitted[index] - target_array[index]))

    result = {
        "bones": rows,
        "fit": {
            "after": point_error(fitted, target_array),
            "before": point_error(source_array, target_array),
            "rotation": rotation.tolist(),
            "scale": scale,
            "translation": translation.tolist(),
        },
        "source": blend_path,
        "target": donor_path,
    }
    print("PUSFUME_1P_ALIGNMENT=" + json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
