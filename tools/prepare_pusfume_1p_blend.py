"""Prepare Janfon's first-person Pusfume arms for the VT2 asset compiler.

Run through Blender 5.2:
    blender --background --factory-startup --disable-autoexec \
        --python tools/prepare_pusfume_1p_blend.py -- INPUT.blend OUTPUT.fbx

The source blend is opened read-only from this script's perspective and is never saved.
"""

import json
import os
import sys

import bpy


MAXIMUM_INFLUENCES = 4
MAXIMUM_ORPHAN_WEIGHT = 0.05
REQUIRED_GROUPS = {"j_leftarm", "j_rightarm", "j_lefthand", "j_righthand"}


def arguments_after_separator():
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def skinned_armature(mesh_object):
    modifiers = [
        modifier
        for modifier in mesh_object.modifiers
        if modifier.type == "ARMATURE" and modifier.object is not None
    ]
    if len(modifiers) != 1:
        return None
    return modifiers[0].object


def find_arms_and_rig():
    candidates = []
    for mesh_object in bpy.context.scene.objects:
        if mesh_object.type != "MESH":
            continue
        group_names = {group.name for group in mesh_object.vertex_groups}
        armature = skinned_armature(mesh_object)
        if armature and REQUIRED_GROUPS.issubset(group_names):
            candidates.append((mesh_object, armature))

    if len(candidates) != 1:
        names = [mesh.name for mesh, _armature in candidates]
        raise RuntimeError(
            "Expected exactly one skinned left/right arms mesh; found %d: %s"
            % (len(candidates), names)
        )
    return candidates[0]


def evaluated_vertex_positions(mesh_object):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated_object = mesh_object.evaluated_get(depsgraph)
    evaluated_mesh = evaluated_object.to_mesh()
    try:
        return [
            evaluated_object.matrix_world @ vertex.co
            for vertex in evaluated_mesh.vertices
        ]
    finally:
        evaluated_object.to_mesh_clear()


def reset_bind_pose(mesh_object, armature):
    """Remove saved animation without changing Janfon's authored rest mesh."""
    armature.data.pose_position = "REST"
    bpy.context.view_layer.update()
    rest_positions = evaluated_vertex_positions(mesh_object)

    animation_data = armature.animation_data
    action_name = animation_data.action.name if animation_data and animation_data.action else None
    nla_strips = (
        sum(len(track.strips) for track in animation_data.nla_tracks)
        if animation_data
        else 0
    )
    if animation_data:
        armature.animation_data_clear()

    reset_bones = 0
    for pose_bone in armature.pose.bones:
        if not pose_bone.matrix_basis.is_identity:
            reset_bones += 1
        pose_bone.matrix_basis.identity()

    armature.data.pose_position = "POSE"
    bpy.context.scene.frame_set(bpy.context.scene.frame_start)
    bpy.context.view_layer.update()
    posed_positions = evaluated_vertex_positions(mesh_object)
    maximum_delta = max(
        (
            (posed_positions[index] - rest_positions[index]).length
            for index in range(len(rest_positions))
        ),
        default=0,
    )
    if maximum_delta > 0.00001:
        raise RuntimeError(
            "First-person bind reset still deforms the rest mesh by %.8f"
            % maximum_delta
        )

    return {
        "action_removed": action_name,
        "maximum_rest_delta": maximum_delta,
        "nla_strips_removed": nla_strips,
        "pose_bones_reset": reset_bones,
    }


def orphan_group_stats(mesh_object, bone_names):
    stats = {}
    for group in mesh_object.vertex_groups:
        if group.name in bone_names:
            continue
        weights = []
        for vertex in mesh_object.data.vertices:
            for assignment in vertex.groups:
                if assignment.group == group.index and assignment.weight > 0.000001:
                    weights.append(assignment.weight)
                    break
        if weights:
            stats[group.name] = {
                "vertices": len(weights),
                "maximum_weight": max(weights),
            }
    return stats


def remove_orphan_groups(mesh_object, orphan_stats):
    removed = []
    for name, stats in orphan_stats.items():
        if stats["maximum_weight"] > MAXIMUM_ORPHAN_WEIGHT:
            raise RuntimeError(
                "Refusing to remove meaningful non-bone group %s (maximum weight %.6f)"
                % (name, stats["maximum_weight"])
            )
        mesh_object.vertex_groups.remove(mesh_object.vertex_groups[name])
        removed.append(name)
    return sorted(removed)


def prune_and_normalize_weights(mesh_object):
    pruned_vertices = 0
    removed_influences = 0
    for vertex in mesh_object.data.vertices:
        assignments = sorted(vertex.groups, key=lambda item: item.weight, reverse=True)
        if len(assignments) > MAXIMUM_INFLUENCES:
            pruned_vertices += 1
            removed_influences += len(assignments) - MAXIMUM_INFLUENCES
            for assignment in assignments[MAXIMUM_INFLUENCES:]:
                mesh_object.vertex_groups[assignment.group].remove([vertex.index])

        assignments = list(vertex.groups)
        total = sum(assignment.weight for assignment in assignments)
        if total <= 0:
            raise RuntimeError("Vertex %d has no deform weight" % vertex.index)
        for assignment in assignments:
            mesh_object.vertex_groups[assignment.group].add(
                [vertex.index], assignment.weight / total, "REPLACE"
            )
    return pruned_vertices, removed_influences


def weight_stats(mesh_object):
    counts = [
        sum(1 for assignment in vertex.groups if assignment.weight > 0.000001)
        for vertex in mesh_object.data.vertices
    ]
    totals = [sum(assignment.weight for assignment in vertex.groups) for vertex in mesh_object.data.vertices]
    return {
        "max_influences": max(counts, default=0),
        "over_four_influences": sum(1 for count in counts if count > MAXIMUM_INFLUENCES),
        "unnormalized_vertices": sum(1 for total in totals if abs(total - 1.0) > 0.0001),
        "unweighted_vertices": sum(1 for count in counts if count == 0),
    }


def main():
    arguments = arguments_after_separator()
    if len(arguments) != 2:
        raise SystemExit("Usage: prepare_pusfume_1p_blend.py -- INPUT.blend OUTPUT.fbx")

    input_path, output_path = (os.path.abspath(value) for value in arguments)
    if input_path == output_path:
        raise SystemExit("Input and output paths must differ; the source blend is never overwritten.")
    if not input_path.lower().endswith(".blend"):
        raise SystemExit("The first-person source must be a .blend file.")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    mesh, armature = find_arms_and_rig()
    bind_reset = reset_bind_pose(mesh, armature)

    bone_names = {bone.name for bone in armature.data.bones}
    orphan_stats = orphan_group_stats(mesh, bone_names)
    removed_groups = remove_orphan_groups(mesh, orphan_stats)
    pruned_vertices, removed_influences = prune_and_normalize_weights(mesh)
    stats = weight_stats(mesh)
    if (
        stats["over_four_influences"]
        or stats["unnormalized_vertices"]
        or stats["unweighted_vertices"]
    ):
        raise RuntimeError("Weight cleanup failed: %s" % stats)
    if len(armature.data.bones) > 255:
        raise RuntimeError("VT2 supports at most 255 bones; found %d" % len(armature.data.bones))

    material_names = [slot.material.name if slot.material else "" for slot in mesh.material_slots]
    mesh.name = "pusfume_1p_arms"
    mesh.data.name = "pusfume_1p_arms"
    armature.name = "pusfume_1p_rig"
    armature.data.name = "pusfume_1p_rig"

    # Remove references/effect planes from the in-memory copy so background
    # export is deterministic even when the saved UI has no active view layer.
    for scene_object in list(bpy.context.scene.objects):
        if scene_object not in (armature, mesh):
            bpy.data.objects.remove(scene_object, do_unlink=True)
    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=False,
        object_types={"ARMATURE", "MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="OFF",
        axis_forward="-Y",
        axis_up="Z",
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        bake_anim=False,
        path_mode="AUTO",
        embed_textures=False,
    )

    print(
        "PUSFUME_1P_PREPARE_RESULT="
        + json.dumps(
            {
                "bind_reset": bind_reset,
                "bones": len(armature.data.bones),
                "materials": material_names,
                "mesh": mesh.name,
                "orphan_groups": orphan_stats,
                "output": output_path,
                "pruned_vertices": pruned_vertices,
                "removed_groups": removed_groups,
                "removed_influences": removed_influences,
                "vertices": len(mesh.data.vertices),
                "weights": stats,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
