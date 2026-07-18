"""Bake Janfon's original walk onto the new untouched Skaven skeleton."""

from __future__ import annotations

import json
import os
import sys

import bpy
from mathutils import Matrix


SIDE_STEMS = {
    "arm": "arm",
    "ear": "ear",
    "eyebrow1": "eyebrow1",
    "eyebrow2": "eyebrow2",
    "eyebrow3": "eyebrow3",
    "eyelidbottom": "eyelidbottom",
    "eyelidtop": "eyelidtop",
    "foot": "foot",
    "forearm": "forearm",
    "forearmroll": "forearmroll",
    "hand": "hand",
    "handindex1": "handindex1",
    "handindex2": "handindex2",
    "handindex3": "handindex3",
    "handmiddle1": "handmiddle1",
    "handmiddle2": "handmiddle2",
    "handmiddle3": "handmiddle3",
    "handpinky1": "handpinky1",
    "handpinky2": "handpinky2",
    "handpinky3": "handpinky3",
    "handring1": "handring1",
    "handring2": "handring2",
    "handring3": "handring3",
    "handthumb1": "handthumb1",
    "handthumb2": "handthumb2",
    "infootindex": "infootindex",
    "inhandthumb": "inhandthumb",
    "leg": "leg",
    "shoulder": "shoulder",
    "toebase": "toebase",
    "upleg": "upleg",
    "weaponattach": "weaponattach",
}
EXPLICIT_NAMES = {
    "j_lip__L": "j_lip_left",
    "j_lip__R": "j_lip_right",
    "j_lip_up_L": "j_lip_upleft",
    "j_lip_up_R": "j_lip_upright",
}
EXPECTED_UNMAPPED = {"j_eye_l", "j_eye_r", "j_hipbag"}


def mapped_name(source_name, target_names):
    if source_name in target_names:
        return source_name
    if source_name in EXPLICIT_NAMES:
        return EXPLICIT_NAMES[source_name]
    for suffix, side in (("_L", "left"), ("_R", "right")):
        if source_name.startswith("j_") and source_name.endswith(suffix):
            stem = source_name[2 : -2]
            target = "j_" + side + SIDE_STEMS.get(stem, "")
            return target if target in target_names else None
    return None


def sample_mesh(mesh, frame):
    bpy.context.scene.frame_set(frame)
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [evaluated.matrix_world @ vertex.co for vertex in evaluated.data.vertices]


def local_rest_matrix(bone):
    if bone.parent is None:
        return bone.matrix_local.copy()
    return bone.parent.matrix_local.inverted() @ bone.matrix_local


def main(model_path, walk_path, output_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=model_path, automatic_bone_orientation=False)
    model_armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    model_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(model_armatures) != 1 or len(model_meshes) != 1:
        raise RuntimeError("Retarget model must contain one armature and one mesh")
    model_armature = model_armatures[0]
    model_mesh = model_meshes[0]

    existing = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=walk_path, automatic_bone_orientation=False)
    imported = [obj for obj in bpy.context.scene.objects if obj not in existing]
    walk_armatures = [obj for obj in imported if obj.type == "ARMATURE"]
    if len(walk_armatures) != 1:
        raise RuntimeError("Original walk must contain one armature")
    walk_armature = walk_armatures[0]
    walk_action = walk_armature.animation_data and walk_armature.animation_data.action
    if walk_action is None:
        raise RuntimeError("Original walk assigned no armature action")

    target_names = {bone.name for bone in model_armature.data.bones}
    mapping = {
        bone.name: mapped_name(bone.name, target_names)
        for bone in walk_armature.data.bones
    }
    mapping = {source: target for source, target in mapping.items() if target}
    unmapped_source = sorted(
        bone.name for bone in walk_armature.data.bones if bone.name not in mapping
    )
    if len(mapping) < 75:
        raise RuntimeError(f"Original walk mapped only {len(mapping)} bones")
    if set(unmapped_source) != EXPECTED_UNMAPPED:
        raise RuntimeError(f"Original walk unmapped-bone contract changed: {unmapped_source}")

    source_local_rest = {
        source: local_rest_matrix(walk_armature.data.bones[source])
        for source in mapping
    }
    target_local_rest = {
        target: local_rest_matrix(model_armature.data.bones[target])
        for target in mapping.values()
    }

    model_armature.animation_data_clear()
    for action in list(bpy.data.actions):
        if action != walk_action:
            bpy.data.actions.remove(action)
    model_armature.animation_data_create()
    frame_start = int(round(walk_action.frame_range[0]))
    frame_end = int(round(walk_action.frame_range[1]))
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end

    for frame in range(frame_start, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        for pose_bone in model_armature.pose.bones:
            pose_bone.matrix_basis = Matrix.Identity(4)
        for source_name, target_name in mapping.items():
            # The rigs have different bind orientations. Copying world matrices folds
            # those differences into the animation and explosively deforms the mesh;
            # retain only local rotation because Stingray drives locomotion itself.
            source_basis = walk_armature.pose.bones[source_name].matrix_basis
            source_rest = source_local_rest[source_name]
            target_rest = target_local_rest[target_name]
            parent_space_delta = source_rest @ source_basis @ source_rest.inverted()
            target_basis = target_rest.inverted() @ parent_space_delta @ target_rest
            model_armature.pose.bones[target_name].matrix_basis = (
                target_basis.to_quaternion().to_matrix().to_4x4()
            )
        bpy.context.view_layer.update()

        for pose_bone in model_armature.pose.bones:
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.keyframe_insert("location", frame=frame)
            pose_bone.keyframe_insert("rotation_quaternion", frame=frame)
            pose_bone.keyframe_insert("scale", frame=frame)

    action = model_armature.animation_data.action
    action.name = "pusfume_walk"
    first_vertices = sample_mesh(model_mesh, frame_start)
    first_pose = {bone.name: bone.matrix.copy() for bone in model_armature.pose.bones}
    middle = (frame_start + frame_end) // 2
    middle_vertices = sample_mesh(model_mesh, middle)
    vertex_deltas = [
        (left - right).length for left, right in zip(first_vertices, middle_vertices)
    ]
    maximum_vertex_delta = max(vertex_deltas)
    maximum_vertex_index = vertex_deltas.index(maximum_vertex_delta)
    pose_deltas = {
        bone.name: max(
            abs(first_pose[bone.name][row][column] - bone.matrix[row][column])
            for row in range(4)
            for column in range(4)
        )
        for bone in model_armature.pose.bones
    }
    maximum_pose_bone = max(pose_deltas, key=pose_deltas.get)
    maximum_pose_delta = pose_deltas[maximum_pose_bone]
    if maximum_vertex_delta < 0.001 or maximum_pose_delta < 0.001:
        raise RuntimeError("Retargeted walk did not deform the new body")
    if maximum_vertex_delta > 1.0:
        raise RuntimeError(
            f"Retargeted walk deformed the body by {maximum_vertex_delta:.3f}m"
        )

    for obj in list(bpy.context.scene.objects):
        if obj is not model_armature:
            bpy.data.objects.remove(obj, do_unlink=True)
    for candidate in list(bpy.data.actions):
        if candidate != action:
            bpy.data.actions.remove(candidate)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=False,
        axis_forward="-Y",
        axis_up="Z",
        object_types={"ARMATURE"},
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        bake_anim=True,
        bake_anim_use_all_bones=True,
        bake_anim_use_nla_strips=False,
        bake_anim_use_all_actions=False,
        bake_anim_force_startend_keying=True,
        bake_anim_simplify_factor=0.0,
    )
    print(
        "PUSFUME_RETARGETED_WALK="
        + json.dumps(
            {
                "action": action.name,
                "bones": len(model_armature.data.bones),
                "frame_end": frame_end,
                "frame_start": frame_start,
                "mapped_bones": len(mapping),
                "maximum_pose_delta": maximum_pose_delta,
                "maximum_pose_bone": maximum_pose_bone,
                "maximum_vertex_delta": maximum_vertex_delta,
                "maximum_vertex_index": maximum_vertex_index,
                "output": output_path,
                "output_bytes": os.path.getsize(output_path),
                "unmapped_source": unmapped_source,
            },
            sort_keys=True,
        )
    )


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) != 3:
    raise SystemExit(
        "usage: retarget_pusfume_walk.py -- MODEL.fbx ORIGINAL_WALK.fbx OUTPUT.fbx"
    )
main(*(os.path.abspath(argument) for argument in arguments))
