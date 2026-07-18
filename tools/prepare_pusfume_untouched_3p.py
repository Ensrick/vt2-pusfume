"""Prepare Janfon's untouched-rig Pusfume body for the VT2 DCC pipeline."""

from __future__ import annotations

import json
import os
import sys

import bpy
from mathutils.kdtree import KDTree


MAXIMUM_INFLUENCES = 4
EXPECTED_UNWEIGHTED = {"p_glob": 670, "p_main": 12}
ORPHAN_TRANSFERS = {"j_lefthandpinky4": "j_lefthandpinky3"}


def vertex_materials(mesh):
    result = [set() for _vertex in mesh.data.vertices]
    names = [material.name if material else "" for material in mesh.data.materials]
    for polygon in mesh.data.polygons:
        name = names[polygon.material_index]
        for vertex_index in polygon.vertices:
            result[vertex_index].add(name)
    return result


def assignments(vertex):
    return [item for item in vertex.groups if item.weight > 0.000001]


def transfer_orphan_groups(mesh, bone_names):
    transferred = {}
    for source_name, target_name in ORPHAN_TRANSFERS.items():
        source = mesh.vertex_groups.get(source_name)
        if source is None or source_name in bone_names:
            continue
        target = mesh.vertex_groups.get(target_name)
        if target is None or target_name not in bone_names:
            raise RuntimeError(f"Missing orphan transfer target {target_name}")
        count = 0
        for vertex in mesh.data.vertices:
            membership = next(
                (item for item in vertex.groups if item.group == source.index), None
            )
            if membership and membership.weight > 0.000001:
                target.add([vertex.index], membership.weight, "ADD")
                count += 1
        mesh.vertex_groups.remove(source)
        transferred[f"{source_name}->{target_name}"] = count

    remaining = []
    for group in mesh.vertex_groups:
        if group.name in bone_names:
            continue
        if any(
            item.group == group.index and item.weight > 0.000001
            for vertex in mesh.data.vertices
            for item in vertex.groups
        ):
            remaining.append(group.name)
    if remaining:
        raise RuntimeError(f"Unmapped weighted groups remain: {sorted(remaining)}")
    return transferred


def repair_known_unweighted(mesh):
    material_sets = vertex_materials(mesh)
    unweighted = [
        vertex.index for vertex in mesh.data.vertices if not assignments(vertex)
    ]
    by_material = {}
    for vertex_index in unweighted:
        names = material_sets[vertex_index]
        if len(names) != 1:
            raise RuntimeError(
                f"Unweighted vertex {vertex_index} spans materials {sorted(names)}"
            )
        name = next(iter(names))
        by_material.setdefault(name, []).append(vertex_index)
    counts = {name: len(indices) for name, indices in sorted(by_material.items())}
    if counts != EXPECTED_UNWEIGHTED:
        raise RuntimeError(
            f"Untouched-rig unweighted contract changed: {counts}"
        )

    backpack = mesh.vertex_groups.get("j_backpack")
    if backpack is None:
        raise RuntimeError("Untouched rig has no j_backpack group for p_glob")
    backpack.add(by_material["p_glob"], 1.0, "REPLACE")

    weighted = [
        vertex.index for vertex in mesh.data.vertices if assignments(vertex)
    ]
    tree = KDTree(len(weighted))
    for vertex_index in weighted:
        tree.insert(mesh.data.vertices[vertex_index].co, vertex_index)
    tree.balance()
    copied = []
    for vertex_index in by_material["p_main"]:
        _co, source_index, distance = tree.find(mesh.data.vertices[vertex_index].co)
        if distance > 0.00001:
            raise RuntimeError(
                f"Tail repair vertex {vertex_index} has no coincident donor: {distance}"
            )
        source_assignments = assignments(mesh.data.vertices[source_index])
        for item in source_assignments:
            mesh.vertex_groups[item.group].add(
                [vertex_index], item.weight, "REPLACE"
            )
        copied.append((vertex_index, source_index, distance))
    return {"by_material": counts, "tail_copies": copied}


def normalize_weights(mesh):
    pruned = 0
    for vertex in mesh.data.vertices:
        items = sorted(assignments(vertex), key=lambda item: item.weight, reverse=True)
        if len(items) > MAXIMUM_INFLUENCES:
            for item in items[MAXIMUM_INFLUENCES:]:
                mesh.vertex_groups[item.group].remove([vertex.index])
            items = items[:MAXIMUM_INFLUENCES]
            pruned += 1
        total = sum(item.weight for item in items)
        if total <= 0:
            raise RuntimeError(f"Vertex {vertex.index} remains unweighted")
        for item in items:
            mesh.vertex_groups[item.group].add(
                [vertex.index], item.weight / total, "REPLACE"
            )
    return pruned


def main(arguments):
    if len(arguments) != 2:
        raise SystemExit(
            "Usage: prepare_pusfume_untouched_3p.py INPUT.(blend|fbx) OUTPUT.fbx"
        )
    input_path, output_path = (os.path.abspath(value) for value in arguments)
    if input_path.lower().endswith(".blend"):
        bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    elif input_path.lower().endswith(".fbx"):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=input_path, automatic_bone_orientation=False)
    else:
        raise RuntimeError("Untouched Pusfume input must be a .blend or .fbx file")
    mesh = bpy.data.objects.get("p_mainbody")
    armature = bpy.data.objects.get("pusfume_slaverat_untouched")
    if mesh is None or mesh.type != "MESH" or armature is None or armature.type != "ARMATURE":
        raise RuntimeError("Untouched Pusfume mesh/game-rig pair is missing")
    modifiers = [item for item in mesh.modifiers if item.type == "ARMATURE"]
    if len(modifiers) != 1 or modifiers[0].object is not armature:
        raise RuntimeError("p_mainbody is not bound exclusively to the untouched game rig")

    bone_names = {bone.name for bone in armature.data.bones}
    orphan_transfers = transfer_orphan_groups(mesh, bone_names)
    repaired = repair_known_unweighted(mesh)
    pruned = normalize_weights(mesh)
    action = armature.animation_data and armature.animation_data.action
    if action is None:
        raise RuntimeError("Untouched game rig has no assigned idle action")
    frame_start = int(round(action.frame_range[0]))
    frame_end = int(round(action.frame_range[1]))

    for obj in list(bpy.context.scene.objects):
        if obj not in (mesh, armature):
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    bpy.context.scene.render.fps = 30
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="OFF",
        axis_forward="-Y",
        axis_up="Z",
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        bake_anim=True,
        bake_anim_use_all_actions=False,
        bake_anim_use_nla_strips=False,
        bake_anim_simplify_factor=0.0,
        path_mode="AUTO",
        embed_textures=False,
    )
    print(
        "PUSFUME_UNTOUCHED_3P="
        + json.dumps(
            {
                "action": action.name,
                "bones": len(armature.data.bones),
                "frame_end": frame_end,
                "frame_start": frame_start,
                "materials": [material.name for material in mesh.data.materials],
                "orphan_transfers": orphan_transfers,
                "output": output_path,
                "pruned_vertices": pruned,
                "repaired": repaired,
                "vertices": len(mesh.data.vertices),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    separator = sys.argv.index("--") if "--" in sys.argv else len(sys.argv)
    main(sys.argv[separator + 1 :])
