"""Merge Janfon's skinned model and baked walk into a Stingray character FBX.

Run this script through Blender. It leaves both source FBXs unchanged and refuses
to export unless the transferred action moves the armature and deforms the mesh.
"""

import json
import os
import sys

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from pusfume_atlas_layout import ATLAS_REGIONS, ATLAS_SIZE


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


def mesh_bvh(mesh_object):
    vertices = [mesh_object.matrix_world @ vertex.co for vertex in mesh_object.data.vertices]
    polygons = [tuple(polygon.vertices) for polygon in mesh_object.data.polygons]
    return BVHTree.FromPolygons(vertices, polygons, all_triangles=False)


def surface_distances(source_object, target_tree):
    distances = []
    for vertex in source_object.data.vertices:
        nearest = target_tree.find_nearest(source_object.matrix_world @ vertex.co)
        if nearest:
            distances.append(nearest[3])
    distances.sort()
    return {
        "mean": sum(distances) / len(distances),
        "p90": distances[int(len(distances) * 0.9)],
        "max": distances[-1],
    }


def connected_vertex_islands(mesh):
    adjacency = [set() for _ in mesh.vertices]
    for edge in mesh.edges:
        first, second = edge.vertices
        adjacency[first].add(second)
        adjacency[second].add(first)

    unseen = set(range(len(mesh.vertices)))
    islands = []
    while unseen:
        seed = unseen.pop()
        pending = [seed]
        island = [seed]
        while pending:
            vertex_index = pending.pop()
            for neighbor in adjacency[vertex_index]:
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    pending.append(neighbor)
                    island.append(neighbor)
        islands.append(island)
    return islands


def edge_lengths(mesh_object):
    matrix = mesh_object.matrix_world
    lengths = {}
    for edge in mesh_object.data.edges:
        first = matrix @ mesh_object.data.vertices[edge.vertices[0]].co
        second = matrix @ mesh_object.data.vertices[edge.vertices[1]].co
        lengths[tuple(sorted(edge.vertices))] = (first - second).length
    return lengths


def retarget_fur_surface(fur_mesh, legacy_body_mesh, model_mesh):
    legacy_tree = mesh_bvh(legacy_body_mesh)
    model_tree = mesh_bvh(model_mesh)
    before = surface_distances(fur_mesh, model_tree)
    legacy_fit = surface_distances(fur_mesh, legacy_tree)
    fur_inverse = fur_mesh.matrix_world.inverted()
    islands = connected_vertex_islands(fur_mesh.data)
    original_edges = edge_lengths(fur_mesh)
    movements = []

    # Preserve each authored fur card while moving it from the legacy body to
    # the nearest corresponding surface on Janfon's current body.
    for island in islands:
        world_positions = [
            fur_mesh.matrix_world @ fur_mesh.data.vertices[index].co
            for index in island
        ]
        centroid = sum(world_positions, Vector()) / len(world_positions)
        legacy_nearest = legacy_tree.find_nearest(centroid)
        if not legacy_nearest:
            raise RuntimeError("Legacy body has no nearest point for a fur island")
        legacy_anchor = legacy_nearest[0]
        model_nearest = model_tree.find_nearest(legacy_anchor)
        if not model_nearest:
            raise RuntimeError("Current body has no nearest point for a fur island")
        movement = model_nearest[0] - legacy_anchor
        for vertex_index, world_position in zip(island, world_positions):
            fur_mesh.data.vertices[vertex_index].co = fur_inverse @ (
                world_position + movement
            )
        movements.append(movement.length)

    fur_mesh.data.update()
    retargeted_edges = edge_lengths(fur_mesh)
    max_edge_error = max(
        abs(retargeted_edges[key] - original_length)
        for key, original_length in original_edges.items()
    )
    if max_edge_error > 1e-5:
        raise RuntimeError(
            "Rigid fur-island retarget changed authored card geometry: "
            f"max_edge_error={max_edge_error}"
        )

    after = surface_distances(fur_mesh, model_tree)
    if legacy_fit["mean"] > 0.06:
        raise RuntimeError(f"Legacy fur no longer fits its source body: {legacy_fit}")
    if after["mean"] >= before["mean"] * 0.65 or after["mean"] > 0.07:
        raise RuntimeError(
            "Legacy fur surface retarget did not improve the current-body fit: "
            f"before={before} after={after}"
        )

    return {
        "after": after,
        "before": before,
        "islands": len(islands),
        "largest_island_vertices": max(len(island) for island in islands),
        "legacy": legacy_fit,
        "max_edge_error": max_edge_error,
        "max_movement": max(movements),
        "mean_movement": sum(movements) / len(movements),
    }


def add_legacy_fur(fur_path, legacy_body_path, model_armature, model_mesh):
    existing_objects = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=fur_path, automatic_bone_orientation=False)
    imported = [obj for obj in bpy.context.scene.objects if obj not in existing_objects]
    fur_meshes = [obj for obj in imported if obj.type == "MESH"]
    fur_armatures = [obj for obj in imported if obj.type == "ARMATURE"]
    if len(fur_meshes) != 1 or len(fur_armatures) != 1:
        raise RuntimeError(
            "The legacy fur FBX must contain exactly one armature and one mesh: "
            f"armatures={len(fur_armatures)} meshes={len(fur_meshes)}"
        )

    fur_mesh = fur_meshes[0]
    material_names = [material.name.split(".", 1)[0] for material in fur_mesh.data.materials]
    if "p_fur" not in material_names or "p_whiskers" not in material_names:
        raise RuntimeError(
            f"Legacy fur material contract changed: materials={material_names}"
        )

    fur_material_index = material_names.index("p_fur")
    mesh_data = fur_mesh.data
    mesh = bmesh.new()
    mesh.from_mesh(mesh_data)
    duplicate_whiskers = [face for face in mesh.faces if face.material_index != fur_material_index]
    if len(duplicate_whiskers) != 60:
        raise RuntimeError(
            "Legacy duplicate-whisker polygon contract changed: "
            f"expected=60 actual={len(duplicate_whiskers)}"
        )
    bmesh.ops.delete(mesh, geom=duplicate_whiskers, context="FACES")
    loose_vertices = [vertex for vertex in mesh.verts if not vertex.link_faces]
    if loose_vertices:
        bmesh.ops.delete(mesh, geom=loose_vertices, context="VERTS")
    mesh.to_mesh(mesh_data)
    mesh.free()
    mesh_data.update()

    before_legacy_body = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=legacy_body_path, automatic_bone_orientation=False)
    legacy_body_objects = list(set(bpy.context.scene.objects) - before_legacy_body)
    legacy_body_meshes = [obj for obj in legacy_body_objects if obj.type == "MESH"]
    legacy_body_matches = [
        obj for obj in legacy_body_meshes if obj.name.split(".", 1)[0] == "p_body"
    ]
    if len(legacy_body_matches) != 1:
        raise RuntimeError(
            "Legacy body FBX must contain exactly one p_body mesh: "
            f"matches={[obj.name for obj in legacy_body_matches]}"
        )
    alignment = retarget_fur_surface(fur_mesh, legacy_body_matches[0], model_mesh)
    for legacy_object in legacy_body_objects:
        bpy.data.objects.remove(legacy_object, do_unlink=True)

    for modifier in list(fur_mesh.modifiers):
        fur_mesh.modifiers.remove(modifier)
    fur_mesh.vertex_groups.clear()
    for source_group in model_mesh.vertex_groups:
        fur_mesh.vertex_groups.new(name=source_group.name)

    transfer = fur_mesh.modifiers.new("transfer_current_pusfume_weights", "DATA_TRANSFER")
    transfer.object = model_mesh
    transfer.use_vert_data = True
    transfer.data_types_verts = {"VGROUP_WEIGHTS"}
    transfer.vert_mapping = "POLYINTERP_NEAREST"
    transfer.layers_vgroup_select_src = "ALL"
    transfer.layers_vgroup_select_dst = "NAME"
    transfer.mix_mode = "REPLACE"
    transfer.use_object_transform = True
    bpy.context.view_layer.objects.active = fur_mesh
    fur_mesh.select_set(True)
    bpy.ops.object.modifier_apply(modifier=transfer.name)

    unweighted = []
    for vertex in fur_mesh.data.vertices:
        total = sum(group.weight for group in vertex.groups)
        if total <= 1e-6:
            unweighted.append(vertex.index)
            continue
        for membership in vertex.groups:
            fur_mesh.vertex_groups[membership.group].add(
                [vertex.index], membership.weight / total, "REPLACE"
            )
    if unweighted:
        raise RuntimeError(
            f"Legacy fur weight transfer left {len(unweighted)} unweighted vertices"
        )

    world_transform = fur_mesh.matrix_world.copy()
    fur_mesh.parent = model_armature
    fur_mesh.matrix_world = world_transform
    armature_modifier = fur_mesh.modifiers.new("pusfume_armature", "ARMATURE")
    armature_modifier.object = model_armature
    armature_modifier.use_deform_preserve_volume = False

    fur_material = bpy.data.materials.get("p_fur") or bpy.data.materials.new("p_fur")
    fur_mesh.data.materials.clear()
    fur_mesh.data.materials.append(fur_material)
    for polygon in fur_mesh.data.polygons:
        polygon.material_index = 0
    fur_mesh.name = "p_fur"
    fur_mesh.data.name = "p_fur"

    bpy.data.objects.remove(fur_armatures[0], do_unlink=True)
    return fur_mesh, alignment


def remap_material_uvs_to_atlas(mesh_object):
    uv_layer = mesh_object.data.uv_layers.active
    if uv_layer is None:
        raise RuntimeError("The model FBX has no active UV layer")

    material_names = [material.name for material in mesh_object.data.materials]
    # Some meshes omit optional material slots such as the old glowing-eye
    # duplicate. Every present atlas material is still remapped and validated.
    required = set(ATLAS_REGIONS) - {"p_eye_g"}
    missing = sorted(required - set(material_names))
    if missing:
        raise RuntimeError(f"The model FBX is missing atlas material slots: {missing}")

    remapped = {}
    for polygon in mesh_object.data.polygons:
        material_name = material_names[polygon.material_index]
        region = ATLAS_REGIONS.get(material_name)
        if region is None:
            continue

        loops = [uv_layer.data[index] for index in polygon.loop_indices]
        if region.get("repeat"):
            anchor = loops[0].uv
            shift_u = int(anchor.x // 1)
            shift_v = int(anchor.y // 1)
            origin_x, origin_y = region["center"]
        else:
            shift_u = 0
            shift_v = 0
            origin_x, origin_y = region["origin"]

        width, height = region["size"]
        for loop in loops:
            loop.uv.x = (origin_x + (loop.uv.x - shift_u) * width) / ATLAS_SIZE
            loop.uv.y = (origin_y + (loop.uv.y - shift_v) * height) / ATLAS_SIZE
            if not (0 <= loop.uv.x <= 1 and 0 <= loop.uv.y <= 1):
                raise RuntimeError(
                    f"Atlas UV escaped for {material_name}: "
                    f"({loop.uv.x:.6f}, {loop.uv.y:.6f})"
                )

        remapped[material_name] = remapped.get(material_name, 0) + len(loops)

    return remapped


def main(model_path, walk_path, output_path, fur_path=None, legacy_body_path=None):
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
    if bool(fur_path) != bool(legacy_body_path):
        raise RuntimeError("Legacy fur and legacy body paths must be supplied together")
    fur_result = (
        add_legacy_fur(fur_path, legacy_body_path, model_armature, model_mesh)
        if fur_path
        else None
    )
    fur_mesh, fur_alignment = fur_result if fur_result else (None, None)
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
    atlas_loops = remap_material_uvs_to_atlas(model_mesh)

    for obj in list(bpy.context.scene.objects):
        if obj.name not in model_object_names:
            bpy.data.objects.remove(obj, do_unlink=True)

    for candidate in list(bpy.data.actions):
        if candidate != action:
            bpy.data.actions.remove(candidate)

    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = int(round(action.frame_range[0]))
    bpy.context.scene.frame_end = int(round(action.frame_range[1]))

    sample_start = bpy.context.scene.frame_start
    sample_middle = (sample_start + bpy.context.scene.frame_end) // 2
    first_vertices = sample_mesh(model_mesh, sample_start)
    first_pose = {bone.name: bone.matrix.copy() for bone in model_armature.pose.bones}
    middle_vertices = sample_mesh(model_mesh, sample_middle)
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

    fur_vertex_delta = None
    if fur_mesh:
        first_fur_vertices = sample_mesh(fur_mesh, sample_start)
        middle_fur_vertices = sample_mesh(fur_mesh, sample_middle)
        fur_vertex_delta = max(
            (first - middle).length
            for first, middle in zip(first_fur_vertices, middle_fur_vertices)
        )
        if fur_vertex_delta < 0.001:
            raise RuntimeError(
                f"Transferred action did not deform legacy fur: delta={fur_vertex_delta}"
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
        "atlas_loops": atlas_loops,
        "atlas_size": ATLAS_SIZE,
        "bones": len(model_bones),
        "frame_end": bpy.context.scene.frame_end,
        "frame_start": bpy.context.scene.frame_start,
        "fur_max_vertex_delta": fur_vertex_delta,
        "fur_surface_alignment": fur_alignment,
        "fur_polygons": len(fur_mesh.data.polygons) if fur_mesh else 0,
        "fur_vertices": len(fur_mesh.data.vertices) if fur_mesh else 0,
        "max_pose_delta": max_pose_delta,
        "max_vertex_delta": max_vertex_delta,
        "output": output_path,
        "output_bytes": os.path.getsize(output_path),
        "vertices": len(model_mesh.data.vertices),
    }
    print("PUSFUME_ANIMATED_FBX=" + json.dumps(result, sort_keys=True))


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) not in (3, 5):
    raise SystemExit(
        "usage: prepare_animated_pusfume_fbx.py -- MODEL_FBX WALK_FBX OUTPUT_FBX "
        "[LEGACY_FUR_FBX LEGACY_BODY_FBX]"
    )

main(*(os.path.abspath(argument) for argument in arguments))
