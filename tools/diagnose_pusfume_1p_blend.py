"""Measure Janfon's first-person rig and skin deformation in Blender 5.2.

Usage:
    blender --background --factory-startup --disable-autoexec \
        --python tools/diagnose_pusfume_1p_blend.py -- INPUT.blend|INPUT.fbx
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector


IMPORTANT_PREFIXES = (
    "j_leftarm",
    "j_leftforearm",
    "j_lefthand",
    "j_rightarm",
    "j_rightforearm",
    "j_righthand",
)


def arguments_after_separator():
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def find_mesh_and_armature():
    candidates = []
    for mesh in bpy.context.scene.objects:
        if mesh.type != "MESH":
            continue
        modifiers = [
            modifier
            for modifier in mesh.modifiers
            if modifier.type == "ARMATURE" and modifier.object is not None
        ]
        if len(modifiers) == 1:
            candidates.append((mesh, modifiers[0].object))
    if len(candidates) != 1:
        raise RuntimeError("Expected one skinned mesh, found %d" % len(candidates))
    return candidates[0]


def vector_list(value):
    return [round(component, 6) for component in value]


def bounds(points):
    if not points:
        return None
    minimum = Vector((math.inf, math.inf, math.inf))
    maximum = Vector((-math.inf, -math.inf, -math.inf))
    for point in points:
        minimum.x = min(minimum.x, point.x)
        minimum.y = min(minimum.y, point.y)
        minimum.z = min(minimum.z, point.z)
        maximum.x = max(maximum.x, point.x)
        maximum.y = max(maximum.y, point.y)
        maximum.z = max(maximum.z, point.z)
    return {
        "maximum": vector_list(maximum),
        "minimum": vector_list(minimum),
        "size": vector_list(maximum - minimum),
    }


def evaluated_points(mesh, frame):
    bpy.context.scene.frame_set(frame)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh.evaluated_get(depsgraph)
    evaluated_mesh = evaluated.to_mesh()
    try:
        return [evaluated.matrix_world @ vertex.co for vertex in evaluated_mesh.vertices]
    finally:
        evaluated.to_mesh_clear()


def edge_stretch(mesh, rest_points, posed_points):
    ratios = []
    for edge in mesh.data.edges:
        rest_length = (rest_points[edge.vertices[0]] - rest_points[edge.vertices[1]]).length
        posed_length = (posed_points[edge.vertices[0]] - posed_points[edge.vertices[1]]).length
        if rest_length > 1e-8:
            ratios.append(posed_length / rest_length)
    ratios.sort()
    return {
        "maximum": round(max(ratios, default=1), 6),
        "minimum": round(min(ratios, default=1), 6),
        "p99": round(ratios[min(len(ratios) - 1, int(len(ratios) * 0.99))], 6)
        if ratios
        else 1,
    }


def main():
    arguments = arguments_after_separator()
    if len(arguments) != 1:
        raise SystemExit("Usage: diagnose_pusfume_1p_blend.py -- INPUT.blend|INPUT.fbx")
    input_path = os.path.abspath(arguments[0])
    if input_path.lower().endswith(".blend"):
        bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    elif input_path.lower().endswith(".fbx"):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=input_path, use_anim=True)
    else:
        raise SystemExit("Input must be a .blend or .fbx file.")
    mesh, armature = find_mesh_and_armature()
    action = armature.animation_data and armature.animation_data.action
    nla_strips = [
        strip
        for track in (armature.animation_data.nla_tracks if armature.animation_data else [])
        for strip in track.strips
    ]
    frame_start = int(
        action.frame_range[0]
        if action
        else min((strip.frame_start for strip in nla_strips), default=bpy.context.scene.frame_start)
    )
    frame_end = int(
        action.frame_range[1]
        if action
        else max((strip.frame_end for strip in nla_strips), default=bpy.context.scene.frame_end)
    )

    armature.data.pose_position = "REST"
    bpy.context.scene.frame_set(frame_start)
    rest_points = evaluated_points(mesh, frame_start)
    armature.data.pose_position = "POSE"
    frames = sorted({frame_start, (frame_start + frame_end) // 2, frame_end})
    deformation = []
    for frame in frames:
        posed_points = evaluated_points(mesh, frame)
        deformation.append(
            {
                "bounds": bounds(posed_points),
                "edge_stretch": edge_stretch(mesh, rest_points, posed_points),
                "frame": frame,
                "maximum_vertex_delta": round(
                    max(
                        (
                            (posed_points[index] - rest_points[index]).length
                            for index in range(len(rest_points))
                        ),
                        default=0,
                    ),
                    6,
                ),
            }
        )

    group_names = {group.index: group.name for group in mesh.vertex_groups}
    group_vertices = {}
    for vertex in mesh.data.vertices:
        for assignment in vertex.groups:
            name = group_names[assignment.group]
            if assignment.weight >= 0.05:
                group_vertices.setdefault(name, []).append(mesh.matrix_world @ vertex.co)

    bones = {}
    for bone in armature.data.bones:
        if bone.name.startswith(IMPORTANT_PREFIXES):
            bones[bone.name] = {
                "children": [child.name for child in bone.children],
                "head": vector_list(armature.matrix_world @ bone.head_local),
                "length": round(bone.length, 6),
                "parent": bone.parent.name if bone.parent else None,
                "tail": vector_list(armature.matrix_world @ bone.tail_local),
                "weighted_vertices": len(group_vertices.get(bone.name, [])),
                "weighted_bounds": bounds(group_vertices.get(bone.name, [])),
            }

    pose_transforms = {}
    for pose_bone in armature.pose.bones:
        translation, rotation, scale = pose_bone.matrix_basis.decompose()
        translation_length = translation.length
        rotation_angle = abs(rotation.angle)
        scale_delta = max(abs(component - 1) for component in scale)
        if translation_length > 1e-6 or rotation_angle > 1e-6 or scale_delta > 1e-6:
            pose_transforms[pose_bone.name] = {
                "rotation_angle": round(rotation_angle, 6),
                "scale": vector_list(scale),
                "translation": vector_list(translation),
            }

    result = {
        "action": {
            "frame_end": frame_end,
            "frame_start": frame_start,
            "name": action.name if action else None,
            "nla_strips": [
                {
                    "action": strip.action.name if strip.action else None,
                    "frame_end": strip.frame_end,
                    "frame_start": strip.frame_start,
                    "name": strip.name,
                }
                for strip in nla_strips
            ],
        },
        "armature": {
            "bones": len(armature.data.bones),
            "location": vector_list(armature.location),
            "name": armature.name,
            "rotation_euler": vector_list(armature.rotation_euler),
            "scale": vector_list(armature.scale),
        },
        "bones": bones,
        "deformation": deformation,
        "mesh": {
            "bounds": bounds(rest_points),
            "location": vector_list(mesh.location),
            "name": mesh.name,
            "rotation_euler": vector_list(mesh.rotation_euler),
            "scale": vector_list(mesh.scale),
            "vertices": len(mesh.data.vertices),
        },
        "nonidentity_pose_bones": pose_transforms,
        "source": input_path,
        "vertex_groups_without_bones": sorted(
            group.name for group in mesh.vertex_groups if group.name not in armature.data.bones
        ),
    }
    print("PUSFUME_1P_DIAGNOSTIC=" + json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
