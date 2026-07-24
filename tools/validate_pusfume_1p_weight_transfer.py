"""Compare original and native-transferred Pusfume weights under test poses."""

from __future__ import annotations

import json
import math
import os
import sys

import bpy
from mathutils import Euler, Vector
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prepare_pusfume_1p_blend as preparation  # noqa: E402


def arguments_after_separator():
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def append_donor(path):
    with bpy.data.libraries.load(path, link=False) as (data_from, data_to):
        data_to.objects = data_from.objects
    meshes = [
        obj
        for obj in data_to.objects
        if obj is not None and obj.type == "MESH" and obj.vertex_groups
    ]
    if len(meshes) != 1:
        raise RuntimeError("Expected one weighted donor mesh; found %d" % len(meshes))
    donor = meshes[0]
    bpy.context.scene.collection.objects.link(donor)
    return donor


def nearest_mapping(target_positions, donor_positions, neighbors=8):
    tree = KDTree(len(donor_positions))
    for index, position in enumerate(donor_positions):
        tree.insert(position, index)
    tree.balance()
    result = []
    for position in target_positions:
        matches = tree.find_n(position, neighbors)
        weights = [1.0 / max(match[2], 0.0001) ** 2 for match in matches]
        total = sum(weights)
        result.append(
            [(matches[index][1], weight / total) for index, weight in enumerate(weights)]
        )
    return result


def motion_error(rest, posed, donor_rest, donor_posed, mapping):
    errors = []
    for index, neighbors in enumerate(mapping):
        expected = sum(
            (
                (donor_posed[donor_index] - donor_rest[donor_index]) * weight
                for donor_index, weight in neighbors
            ),
            Vector((0, 0, 0)),
        )
        actual = posed[index] - rest[index]
        errors.append((actual - expected).length)
    return {
        "maximum": max(errors, default=0.0),
        "mean": sum(errors) / len(errors),
        "rms": math.sqrt(sum(error * error for error in errors) / len(errors)),
    }


def main():
    arguments = arguments_after_separator()
    if len(arguments) != 3:
        raise SystemExit(
            "Usage: validate_pusfume_1p_weight_transfer.py -- "
            "CUSTOM.blend DONOR.unit DONOR.blend"
        )
    custom_path, donor_unit_path, donor_blend_path = (
        os.path.abspath(value) for value in arguments
    )
    bpy.ops.wm.open_mainfile(filepath=custom_path, load_ui=False)
    original, armature = preparation.find_arms_and_rig()
    preparation.reset_bind_pose(original, armature)
    preparation.conform_mesh_to_donor_rest(original, armature, donor_unit_path)
    preparation.rebind_to_donor_rest(original, armature, donor_unit_path)

    transferred = original.copy()
    transferred.data = original.data.copy()
    transferred.name = "pusfume_native_weight_transfer"
    bpy.context.scene.collection.objects.link(transferred)
    preparation.transfer_weights_from_native_surface(
        transferred, armature, donor_blend_path
    )

    donor = append_donor(donor_blend_path)
    modifier = donor.modifiers.new(name="native_test_armature", type="ARMATURE")
    modifier.object = armature
    bpy.context.view_layer.update()

    armature.data.pose_position = "REST"
    original_rest = preparation.evaluated_vertex_positions(original)
    transferred_rest = preparation.evaluated_vertex_positions(transferred)
    donor_rest = preparation.evaluated_vertex_positions(donor)
    mapping = nearest_mapping(original_rest, donor_rest)

    test_rotations = {
        "j_leftarm": (0.20, -0.35, 0.15),
        "j_leftarmroll": (-0.25, 0.10, 0.20),
        "j_leftforearm": (0.45, 0.10, -0.30),
        "j_lefthand": (-0.20, 0.35, 0.15),
        "j_rightarm": (-0.15, 0.30, -0.25),
        "j_rightarmroll": (0.30, -0.10, -0.15),
        "j_rightforearm": (-0.40, -0.15, 0.35),
        "j_righthand": (0.25, -0.30, -0.10),
    }
    armature.data.pose_position = "POSE"
    for name, rotation in test_rotations.items():
        pose_bone = armature.pose.bones[name]
        pose_bone.matrix_basis = Euler(rotation, "XYZ").to_matrix().to_4x4()
    bpy.context.view_layer.update()

    donor_posed = preparation.evaluated_vertex_positions(donor)
    original_posed = preparation.evaluated_vertex_positions(original)
    transferred_posed = preparation.evaluated_vertex_positions(transferred)
    original_error = motion_error(
        original_rest, original_posed, donor_rest, donor_posed, mapping
    )
    transferred_error = motion_error(
        transferred_rest, transferred_posed, donor_rest, donor_posed, mapping
    )
    if transferred_error["rms"] >= original_error["rms"] * 0.75:
        raise RuntimeError(
            "Native weight transfer did not materially improve posed motion: %s -> %s"
            % (original_error, transferred_error)
        )

    print(
        "PUSFUME_1P_WEIGHT_TRANSFER_VALIDATION="
        + json.dumps(
            {
                "improvement": original_error["rms"] / transferred_error["rms"],
                "original": original_error,
                "rotations": test_rotations,
                "transferred": transferred_error,
                "vertices": len(original_rest),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
