"""Merge Janfon's skinned model and baked walk into a Stingray character FBX.

Run this script through Blender. It leaves both source FBXs unchanged and refuses
to export unless the transferred action moves the armature and deforms the mesh.
"""

import json
import os
import sys

import bpy


def scene_objects(object_type):
    return [obj for obj in bpy.context.scene.objects if obj.type == object_type]


def sample_mesh(mesh, frame):
    bpy.context.scene.frame_set(frame)
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [evaluated.matrix_world @ vertex.co for vertex in evaluated.data.vertices]


def transfer_action(model_armature, walk_armature):
    if walk_armature.animation_data is None or walk_armature.animation_data.action is None:
        raise RuntimeError("The walk FBX did not assign an action to its armature")

    action = walk_armature.animation_data.action
    if model_armature.animation_data is None:
        model_armature.animation_data_create()

    model_armature.animation_data.action = action
    if hasattr(action, "slots") and len(action.slots):
        model_armature.animation_data.action_slot = action.slots[0]

    action.name = "pusfume_walk"
    return action


def main(model_path, walk_path, output_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=model_path, automatic_bone_orientation=False)

    model_armatures = scene_objects("ARMATURE")
    model_meshes = scene_objects("MESH")
    if len(model_armatures) != 1 or len(model_meshes) != 1:
        raise RuntimeError(
            "The model FBX must contain exactly one armature and one mesh: "
            f"armatures={len(model_armatures)} meshes={len(model_meshes)}"
        )

    model_armature = model_armatures[0]
    model_mesh = model_meshes[0]
    model_object_names = {obj.name for obj in bpy.context.scene.objects}

    bpy.ops.import_scene.fbx(filepath=walk_path, automatic_bone_orientation=False)
    walk_armatures = [
        obj for obj in scene_objects("ARMATURE") if obj is not model_armature
    ]
    if len(walk_armatures) != 1:
        raise RuntimeError(
            f"The walk FBX must contain exactly one armature: {len(walk_armatures)}"
        )

    walk_armature = walk_armatures[0]
    model_bones = {bone.name for bone in model_armature.data.bones}
    walk_bones = {bone.name for bone in walk_armature.data.bones}
    if model_bones != walk_bones:
        raise RuntimeError(
            "Model/walk skeleton mismatch: "
            f"model_only={sorted(model_bones - walk_bones)} "
            f"walk_only={sorted(walk_bones - model_bones)}"
        )

    action = transfer_action(model_armature, walk_armature)

    for obj in list(bpy.context.scene.objects):
        if obj.name not in model_object_names:
            bpy.data.objects.remove(obj, do_unlink=True)

    for candidate in list(bpy.data.actions):
        if candidate != action:
            bpy.data.actions.remove(candidate)

    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 25

    first_vertices = sample_mesh(model_mesh, 1)
    first_pose = {bone.name: bone.matrix.copy() for bone in model_armature.pose.bones}
    middle_vertices = sample_mesh(model_mesh, 13)
    max_vertex_delta = max(
        (first - middle).length
        for first, middle in zip(first_vertices, middle_vertices)
    )
    max_pose_delta = max(
        abs(first_pose[bone.name][row][column] - bone.matrix[row][column])
        for bone in model_armature.pose.bones
        for row in range(4)
        for column in range(4)
    )
    if max_pose_delta < 0.001:
        raise RuntimeError(
            f"Transferred action did not animate the armature: delta={max_pose_delta}"
        )
    if max_vertex_delta < 0.001:
        raise RuntimeError(
            f"Transferred action did not deform the mesh: delta={max_vertex_delta}"
        )

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=False,
        axis_forward="-Y",
        axis_up="Z",
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        bake_anim=True,
        bake_anim_use_all_bones=True,
        bake_anim_use_nla_strips=False,
        bake_anim_use_all_actions=False,
        bake_anim_force_startend_keying=True,
    )

    result = {
        "action": action.name,
        "bones": len(model_bones),
        "frame_end": bpy.context.scene.frame_end,
        "frame_start": bpy.context.scene.frame_start,
        "max_pose_delta": max_pose_delta,
        "max_vertex_delta": max_vertex_delta,
        "output": output_path,
        "output_bytes": os.path.getsize(output_path),
        "vertices": len(model_mesh.data.vertices),
    }
    print("PUSFUME_ANIMATED_FBX=" + json.dumps(result, sort_keys=True))


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) != 3:
    raise SystemExit(
        "usage: prepare_animated_pusfume_fbx.py -- MODEL_FBX WALK_FBX OUTPUT_FBX"
    )

main(*(os.path.abspath(argument) for argument in arguments))
