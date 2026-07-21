"""Prepare Janfon's first-person Pusfume arms for the VT2 asset compiler.

Run through Blender 5.2:
    blender --background --factory-startup --disable-autoexec \
        --python tools/prepare_pusfume_1p_blend.py -- \
        INPUT.blend DONOR.unit OUTPUT.fbx

The source blend is opened read-only from this script's perspective and is never saved.
"""

import json
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stingray_unit_scene import read_scene_graph, short_hash


MAXIMUM_INFLUENCES = 4
MAXIMUM_ORPHAN_WEIGHT = 0.05
REQUIRED_GROUPS = {"j_leftarm", "j_rightarm", "j_lefthand", "j_righthand"}
REQUIRED_DONOR_BONES = {
    "j_leftarm",
    "j_leftforearm",
    "j_lefthand",
    "j_rightarm",
    "j_rightforearm",
    "j_righthand",
}
DONOR_NAME_OVERRIDES = {"j_spine1": "j_spine2"}


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
    """Record every vertex group with no matching bone, including weightless ones.

    Janfon's human rig ships a stray j_lefthandpinky4 group whose bone stops at
    pinky3; a weightless orphan is pruned, a weighted one is a hard error.
    """
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
        stats[group.name] = {
            "vertices": len(weights),
            "maximum_weight": max(weights) if weights else 0.0,
        }
    return stats


def remove_orphan_groups(mesh_object, orphan_stats):
    removed = []
    for name, stats in orphan_stats.items():
        if stats["maximum_weight"] > MAXIMUM_ORPHAN_WEIGHT:
            raise RuntimeError(
                "Vertex group '%s' has no matching armature bone but carries deform "
                "weight up to %.6f. Add the bone or remove the weight (asset fix)."
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


def blender_matrix_from_stingray(values):
    matrix = Matrix(
        (
            (values[0], values[4], values[8], values[12]),
            (values[1], values[5], values[9], values[13]),
            (values[2], values[6], values[10], values[14]),
            (0, 0, 0, 1),
        )
    )
    # DCC object scale can be baked into compiled node axes. Bone rest matrices
    # need only the orthonormal basis and world-space translation.
    for column in range(3):
        axis = Vector((matrix[0][column], matrix[1][column], matrix[2][column]))
        if axis.length <= 0.000001:
            raise RuntimeError("Donor scene graph contains a zero-length bone axis")
        axis.normalize()
        matrix[0][column], matrix[1][column], matrix[2][column] = axis
    return matrix


def donor_rest_matrices(armature, donor_unit_path):
    """Resolve donor-compatible armature-space matrices for every source bone."""
    old_world = {bone.name: bone.matrix_local.copy() for bone in armature.data.bones}
    bone_order = [bone.name for bone in armature.data.bones]
    parent_names = {
        bone.name: bone.parent.name if bone.parent else None
        for bone in armature.data.bones
    }
    donor_graph = read_scene_graph(donor_unit_path)
    donor_by_hash = {node["name_hash"]: node for node in donor_graph["nodes"]}
    expected = {}
    missing = []
    for bone in armature.data.bones:
        donor_name = DONOR_NAME_OVERRIDES.get(bone.name, bone.name)
        donor_node = donor_by_hash.get(short_hash(donor_name))
        if donor_node:
            expected[bone.name] = (
                armature.matrix_world.inverted()
                @ blender_matrix_from_stingray(donor_node["world"])
            )
        elif bone.name in REQUIRED_DONOR_BONES:
            missing.append(bone.name)
    if missing:
        raise RuntimeError("Donor unit is missing required bones: %s" % sorted(missing))

    resolved = {}
    for name in bone_order:
        parent_name = parent_names[name]
        if name in expected:
            matrix = expected[name]
        elif parent_name:
            source_local = old_world[parent_name].inverted() @ old_world[name]
            matrix = resolved[parent_name] @ source_local
        else:
            matrix = old_world[name]
        resolved[name] = matrix.copy()
    return donor_graph, expected, resolved


def conform_mesh_to_donor_rest(mesh_object, armature, donor_unit_path):
    """Bake Janfon's weighted mesh into the donor skeleton's rest shape.

    Moving only edit bones preserves the old vertex shape around new pivots,
    which looks fine at rest but tears under gameplay rotations. Evaluate the
    existing skin weights at the donor pose first, then make that pose the bind.
    """
    donor_graph, expected, resolved = donor_rest_matrices(armature, donor_unit_path)
    source_positions = evaluated_vertex_positions(mesh_object)
    source_rest = {bone.name: bone.matrix_local.copy() for bone in armature.data.bones}
    conformance_pose = {}
    for bone_name, source_matrix in source_rest.items():
        matrix = source_matrix.copy()
        matrix.translation = resolved[bone_name].translation
        conformance_pose[bone_name] = matrix

    armature.data.pose_position = "POSE"
    bone_depth = {}
    for bone in armature.data.bones:
        depth = 0
        parent = bone.parent
        while parent:
            depth += 1
            parent = parent.parent
        bone_depth[bone.name] = depth
    for bone_name in sorted(conformance_pose, key=lambda name: bone_depth[name]):
        armature.pose.bones[bone_name].matrix = conformance_pose[bone_name]
        bpy.context.view_layer.update()
    maximum_pose_delta = max(
        (
            max(
                abs(
                    armature.pose.bones[name].matrix[row][column]
                    - conformance_pose[name][row][column]
                )
                for row in range(4)
                for column in range(4)
            )
            for name in conformance_pose
        ),
        default=0,
    )
    if maximum_pose_delta > 0.0001:
        raise RuntimeError(
            "Donor position conformance pose error is %.8f" % maximum_pose_delta
        )
    conformed_positions = evaluated_vertex_positions(mesh_object)

    mesh_inverse = mesh_object.matrix_world.inverted()
    armature.data.pose_position = "REST"
    for index, position in enumerate(conformed_positions):
        mesh_object.data.vertices[index].co = mesh_inverse @ position
    for pose_bone in armature.pose.bones:
        pose_bone.matrix_basis.identity()
    bpy.context.view_layer.update()

    maximum_vertex_delta = max(
        (
            (conformed_positions[index] - source_positions[index]).length
            for index in range(len(source_positions))
        ),
        default=0,
    )
    # Janfon's human rig is already authored on the hero donor rest positions,
    # so a near-zero correction is the ideal result. The earlier Skaven-rig
    # pipeline required a visible correction and used a lower bound here, but
    # the matrix and post-rebind gates below are the actual no-op safeguards.
    if maximum_vertex_delta > 0.75:
        raise RuntimeError(
            "Donor position conformance produced an implausible mesh delta %.8f"
            % maximum_vertex_delta
        )
    return {
        "donor_nodes": len(donor_graph["nodes"]),
        "mapped_bones": len(expected),
        "maximum_pose_delta": maximum_pose_delta,
        "maximum_vertex_delta": maximum_vertex_delta,
    }


def rebind_to_donor_rest(mesh_object, armature, donor_unit_path):
    """Replace shared rest matrices while preserving Janfon's authored mesh."""
    armature.data.pose_position = "REST"
    bpy.context.view_layer.update()
    mesh_before = evaluated_vertex_positions(mesh_object)
    old_world = {bone.name: bone.matrix_local.copy() for bone in armature.data.bones}
    old_length = {bone.name: bone.length for bone in armature.data.bones}
    bone_order = [bone.name for bone in armature.data.bones]
    parent_names = {
        bone.name: bone.parent.name if bone.parent else None
        for bone in armature.data.bones
    }

    donor_graph, expected, rebound_world = donor_rest_matrices(
        armature, donor_unit_path
    )

    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = armature.data.edit_bones
    for edit_bone in edit_bones:
        edit_bone.use_connect = False

    for name in bone_order:
        matrix = rebound_world[name]
        edit_bones[name].matrix = matrix
        edit_bones[name].length = old_length[name]
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    maximum_matrix_delta = 0
    for name, matrix in expected.items():
        actual = armature.data.bones[name].matrix_local
        maximum_matrix_delta = max(
            maximum_matrix_delta,
            max(abs(actual[row][column] - matrix[row][column]) for row in range(4) for column in range(4)),
        )
    if maximum_matrix_delta > 0.0001:
        raise RuntimeError(
            "Donor rest rebind matrix error is %.8f" % maximum_matrix_delta
        )

    mesh_after = evaluated_vertex_positions(mesh_object)
    maximum_mesh_delta = max(
        ((mesh_after[index] - mesh_before[index]).length for index in range(len(mesh_before))),
        default=0,
    )
    if maximum_mesh_delta > 0.00001:
        raise RuntimeError(
            "Donor rest rebind changed Janfon's rest mesh by %.8f" % maximum_mesh_delta
        )

    return {
        "donor_nodes": len(donor_graph["nodes"]),
        "mapped_bones": len(expected),
        "maximum_matrix_delta": maximum_matrix_delta,
        "maximum_mesh_delta": maximum_mesh_delta,
    }


def apply_stingray_basis_counter_scale(mesh_object, armature, factor=100.0):
    """Pre-scale positions for a 0.01 FBX without scaling bone bases."""
    before_vertices = evaluated_vertex_positions(mesh_object)
    before_bone_positions = {
        bone.name: (armature.matrix_world @ bone.matrix_local).translation.copy()
        for bone in armature.data.bones
    }

    mesh_object.data.transform(Matrix.Scale(factor, 4))
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for edit_bone in armature.data.edit_bones:
        edit_bone.head *= factor
        edit_bone.tail *= factor
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    after_vertices = evaluated_vertex_positions(mesh_object)
    maximum_mesh_delta = max(
        (
            (after_vertices[index] - before_vertices[index] * factor).length
            for index in range(len(before_vertices))
        ),
        default=0,
    )
    maximum_bone_position_delta = max(
        (
            (
                (armature.matrix_world @ bone.matrix_local).translation
                - before_bone_positions[bone.name] * factor
            ).length
            for bone in armature.data.bones
        ),
        default=0,
    )
    # Scaling metre-space float coordinates by 100 amplifies the donor rebind's
    # sub-micrometre float noise. Keep the bound well below one millimetre.
    if maximum_mesh_delta > 0.0001 or maximum_bone_position_delta > 0.0001:
        raise RuntimeError(
            "Stingray FBX position pre-scale changed relative content: "
            "mesh=%.8f bones=%.8f"
            % (maximum_mesh_delta, maximum_bone_position_delta)
        )
    return {
        "factor": factor,
        "maximum_bone_position_delta": maximum_bone_position_delta,
        "maximum_mesh_delta": maximum_mesh_delta,
    }


def main():
    arguments = arguments_after_separator()
    if len(arguments) != 3:
        raise SystemExit(
            "Usage: prepare_pusfume_1p_blend.py -- INPUT.blend DONOR.unit OUTPUT.fbx"
        )

    input_path, donor_unit_path, output_path = (
        os.path.abspath(value) for value in arguments
    )
    if input_path == output_path:
        raise SystemExit("Input and output paths must differ; the source blend is never overwritten.")
    if not input_path.lower().endswith(".blend"):
        raise SystemExit("The first-person source must be a .blend file.")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    mesh, armature = find_arms_and_rig()
    bind_reset = reset_bind_pose(mesh, armature)
    donor_rebind = rebind_to_donor_rest(mesh, armature, donor_unit_path)
    stingray_counter_scale = apply_stingray_basis_counter_scale(mesh, armature)

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

    # Stingray's DCC importer multiplies Blender's unit-scale bone bases by 100.
    # Encode the FBX at 0.01 while pre-scaling positions by 100: translations
    # and mesh dimensions remain donor-sized, but compiled bone bases stay 1x.
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.length_unit = "METERS"
    bpy.context.scene.unit_settings.scale_length = 1.0
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
        global_scale=0.01,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        path_mode="AUTO",
        embed_textures=False,
    )

    print(
        "PUSFUME_1P_PREPARE_RESULT="
        + json.dumps(
            {
                "bind_reset": bind_reset,
                "bones": len(armature.data.bones),
                "donor_rebind": donor_rebind,
                "materials": material_names,
                "mesh": mesh.name,
                "orphan_groups": orphan_stats,
                "output": output_path,
                "pruned_vertices": pruned_vertices,
                "removed_groups": removed_groups,
                "removed_influences": removed_influences,
                "stingray_counter_scale": stingray_counter_scale,
                "vertices": len(mesh.data.vertices),
                "weights": stats,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
