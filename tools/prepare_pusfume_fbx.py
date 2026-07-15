"""Clean a Pusfume FBX for the VT2 asset compiler.

Run this through Blender, not the system Python:
    blender --background --factory-startup --disable-autoexec \
        --python tools/prepare_pusfume_fbx.py -- INPUT.fbx OUTPUT.fbx
"""

import json
import os
import sys

import bpy


def arguments_after_separator():
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def prune_and_normalize_weights(mesh_object, maximum_influences=4):
    pruned_vertices = 0
    removed_influences = 0

    for vertex in mesh_object.data.vertices:
        assignments = sorted(vertex.groups, key=lambda item: item.weight, reverse=True)

        if len(assignments) > maximum_influences:
            pruned_vertices += 1
            removed_influences += len(assignments) - maximum_influences

            for assignment in assignments[maximum_influences:]:
                mesh_object.vertex_groups[assignment.group].remove([vertex.index])

        kept = list(vertex.groups)
        total = sum(assignment.weight for assignment in kept)

        if total > 0:
            for assignment in kept:
                mesh_object.vertex_groups[assignment.group].add(
                    [vertex.index], assignment.weight / total, "REPLACE"
                )

    return pruned_vertices, removed_influences


def weight_stats(mesh_object):
    counts = [
        sum(1 for assignment in vertex.groups if assignment.weight > 0.000001)
        for vertex in mesh_object.data.vertices
    ]
    return {
        "max_influences": max(counts),
        "over_four_influences": sum(1 for count in counts if count > 4),
        "unweighted_vertices": sum(1 for count in counts if count == 0),
    }


arguments = arguments_after_separator()
if len(arguments) != 2:
    raise SystemExit("Usage: prepare_pusfume_fbx.py -- INPUT.fbx OUTPUT.fbx")

input_path, output_path = (os.path.abspath(value) for value in arguments)
if input_path == output_path:
    raise SystemExit("Input and output paths must differ; the source FBX is never overwritten.")

os.makedirs(os.path.dirname(output_path), exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=input_path, use_anim=False)

armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
if len(armatures) != 1 or not meshes:
    raise SystemExit(
        "Expected one armature and at least one mesh; found %d armatures and %d meshes."
        % (len(armatures), len(meshes))
    )

armature = armatures[0]
mesh = max(meshes, key=lambda item: len(item.data.vertices))
for obj in list(bpy.context.scene.objects):
    if obj not in (armature, mesh):
        bpy.data.objects.remove(obj, do_unlink=True)

pruned_vertices, removed_influences = prune_and_normalize_weights(mesh)
stats = weight_stats(mesh)
if stats["unweighted_vertices"] or stats["over_four_influences"]:
    raise SystemExit("Weight cleanup failed: %s" % stats)

bpy.ops.object.select_all(action="DESELECT")
armature.select_set(True)
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh

bpy.ops.export_scene.fbx(
    filepath=output_path,
    use_selection=True,
    object_types={"ARMATURE", "MESH"},
    use_mesh_modifiers=True,
    mesh_smooth_type="OFF",
    axis_forward="-Y",
    axis_up="Z",
    add_leaf_bones=False,
    bake_anim=False,
    path_mode="AUTO",
    embed_textures=False,
)

print(
    "PUSFUME_PREPARE_RESULT="
    + json.dumps(
        {
            "armature": armature.name,
            "bones": len(armature.data.bones),
            "mesh": mesh.name,
            "output": output_path,
            "pruned_vertices": pruned_vertices,
            "removed_influences": removed_influences,
            "vertices": len(mesh.data.vertices),
            "weights": stats,
        },
        sort_keys=True,
    )
)
