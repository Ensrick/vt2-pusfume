"""Audit Pusfume material UVs against the native texture-atlas layout.

Run through Blender so the report uses the same FBX importer as the native build.
This tool is read-only and does not save or modify the source FBX.
"""

import json
import os
import sys

import bpy

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from pusfume_atlas_layout import ATLAS_REGIONS, ATLAS_SIZE


def outside(value, lower, upper, epsilon=1e-6):
    return value < lower - epsilon or value > upper + epsilon


def audit_mesh(mesh_object, atlas_size, regions):
    uv_layer = mesh_object.data.uv_layers.active
    if uv_layer is None:
        raise RuntimeError("The model FBX has no active UV layer")

    material_names = [material.name for material in mesh_object.data.materials]
    report = {}
    for material_name, region in regions.items():
        source_uvs = []
        atlas_uvs = []
        escaped_loops = 0
        polygon_count = 0

        if material_name not in material_names:
            report[material_name] = {"missing": True}
            continue

        material_index = material_names.index(material_name)
        for polygon in mesh_object.data.polygons:
            if polygon.material_index != material_index:
                continue

            polygon_count += 1
            loops = [uv_layer.data[index] for index in polygon.loop_indices]
            if region.get("repeat"):
                shift_u = int(loops[0].uv.x // 1)
                shift_v = int(loops[0].uv.y // 1)
                origin_x, origin_y = region["center"]
            else:
                shift_u = 0
                shift_v = 0
                origin_x, origin_y = region["origin"]
            allowed_min = region["allowed_min"]
            allowed_max = region["allowed_max"]

            width, height = region["size"]
            for loop in loops:
                source_u = float(loop.uv.x)
                source_v = float(loop.uv.y)
                local_u = source_u - shift_u
                local_v = source_v - shift_v
                atlas_u = (origin_x + local_u * width) / atlas_size
                atlas_v = (origin_y + local_v * height) / atlas_size
                source_uvs.append((source_u, source_v))
                atlas_uvs.append((atlas_u, atlas_v))
                if outside(local_u, allowed_min[0], allowed_max[0]) or outside(
                    local_v, allowed_min[1], allowed_max[1]
                ):
                    escaped_loops += 1

        def bounds(values):
            return {
                "min": [min(value[0] for value in values), min(value[1] for value in values)],
                "max": [max(value[0] for value in values), max(value[1] for value in values)],
            }

        report[material_name] = {
            "polygons": polygon_count,
            "loops": len(source_uvs),
            "source_bounds": bounds(source_uvs),
            "simulated_atlas_bounds": bounds(atlas_uvs),
            "escaped_loops": escaped_loops,
        }

    return report


def main(fbx_path, output_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx_path, automatic_bone_orientation=False)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError(f"Expected exactly one mesh, found {len(meshes)}")

    report = audit_mesh(meshes[0], ATLAS_SIZE, ATLAS_REGIONS)
    with open(output_path, "w", encoding="utf-8") as output_file:
        json.dump(report, output_file, indent=2, sort_keys=True)
        output_file.write("\n")

    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :]
    if len(args) != 2:
        raise SystemExit(
            "Usage: blender --background --python audit_pusfume_uvs.py -- "
            "MODEL_FBX OUTPUT_JSON"
        )
    main(*(os.path.abspath(path) for path in args))
