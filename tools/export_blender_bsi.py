"""Export a Blender FBX as a compiler-readable static Bitsquid scene.

This is the account-free Pusfume exporter. Static and skinned output are SDK
compiler-verified. Skinned output includes rest-pose animation channels for the
full scene graph so the engine creates animation-blender bones for linked skin.

Run through Blender:
    blender --background --factory-startup --disable-autoexec \
        --python tools/export_blender_bsi.py -- INPUT.fbx OUTPUT.bsi
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

import bpy


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsi_format  # noqa: E402


IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def parse_arguments():
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Clean FBX input")
    parser.add_argument("output", help="BSI output")
    parser.add_argument("--compress", action="store_true", help="Write a bsiz container")
    parser.add_argument(
        "--skin",
        action="store_true",
        help="Include the experimental armature and four-weight skin",
    )
    return parser.parse_args(raw)


def safe_name(value, fallback):
    name = re.sub(r"[^A-Za-z0-9_]", "_", value.strip())
    if not name:
        name = fallback
    if name[0].isdigit():
        name = "_" + name
    return name


def stream(name, channel_type, width, data):
    return {
        "channels": [{"index": 0, "name": name, "type": channel_type}],
        "data": data,
        "size": len(data) // width,
        "stride": width * 4,
    }


def append_vector(target, value, width):
    target.extend(float(value[index]) for index in range(width))


def matrix_values(matrix):
    """Flatten a Blender matrix in the column order used by BSI."""
    return [float(matrix[row][column]) for column in range(4) for row in range(4)]


def weight_stats(mesh_object):
    counts = [
        sum(1 for assignment in vertex.groups if assignment.weight > 0.000001)
        for vertex in mesh_object.data.vertices
    ]
    return {
        "max_influences": max(counts, default=0),
        "over_four_influences": sum(count > 4 for count in counts),
        "unweighted_vertices": sum(count == 0 for count in counts),
    }


def vertex_skin(mesh_object, vertex_index, bone_indices):
    assignments = []
    for assignment in mesh_object.data.vertices[vertex_index].groups:
        group_name = mesh_object.vertex_groups[assignment.group].name
        if assignment.weight > 0.000001 and group_name in bone_indices:
            assignments.append((assignment.weight, bone_indices[group_name]))

    assignments.sort(reverse=True)
    assignments = assignments[:4]
    total = sum(weight for weight, _ in assignments)
    if total <= 0:
        raise RuntimeError(f"Vertex {vertex_index} has no weight on an exported bone")

    weights = [weight / total for weight, _ in assignments]
    indices = [bone_index for _, bone_index in assignments]
    while len(weights) < 4:
        weights.append(0.0)
        indices.append(0)
    return indices, weights


def build_geometry(mesh_object, bone_indices=None, skin_name=None):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh_object.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh(preserve_all_data_layers=True, depsgraph=depsgraph)

    try:
        mesh.calc_loop_triangles()
        if not mesh.uv_layers.active:
            raise RuntimeError("The mesh has no active UV map")
        mesh.calc_tangents(uvmap=mesh.uv_layers.active.name)

        positions = []
        normals = []
        texcoords = []
        binormals = []
        tangents = []
        blendindices = []
        blendweights = []
        indices = []
        smoothing = []
        material_triangles = {}
        uv_data = mesh.uv_layers.active.data

        for triangle_index, triangle in enumerate(mesh.loop_triangles):
            material_index = triangle.material_index
            material_triangles.setdefault(material_index, []).append(triangle_index)
            smoothing.append(1 if mesh.polygons[triangle.polygon_index].use_smooth else 0)

            for loop_index in triangle.loops:
                loop = mesh.loops[loop_index]
                vertex = mesh.vertices[loop.vertex_index]
                normal = mesh.corner_normals[loop_index].vector
                tangent = loop.tangent
                binormal = normal.cross(tangent) * loop.bitangent_sign

                append_vector(positions, vertex.co, 3)
                append_vector(normals, normal, 3)
                append_vector(texcoords, uv_data[loop_index].uv, 2)
                append_vector(binormals, binormal, 3)
                append_vector(tangents, tangent, 3)
                if bone_indices is not None:
                    corner_indices, corner_weights = vertex_skin(
                        mesh_object, loop.vertex_index, bone_indices
                    )
                    blendindices.extend(corner_indices)
                    blendweights.extend(corner_weights)
                indices.append(len(indices))

        material_records = []
        for material_index, primitives in sorted(material_triangles.items()):
            material = (
                mesh.materials[material_index]
                if material_index < len(mesh.materials)
                else None
            )
            material_records.append(
                {
                    "name": safe_name(
                        material.name if material else "default_material", "default_material"
                    ),
                    "primitives": primitives,
                }
            )

        streams = [
            stream("POSITION", "CT_FLOAT3", 3, positions),
            stream("NORMAL", "CT_FLOAT3", 3, normals),
            stream("TEXCOORD", "CT_FLOAT2", 2, texcoords),
            stream("BINORMAL", "CT_FLOAT3", 3, binormals),
            stream("TANGENT", "CT_FLOAT3", 3, tangents),
        ]
        index_streams = [indices] * len(streams)
        if bone_indices is not None:
            streams.extend(
                [
                    stream("BLENDWEIGHTS", "CT_FLOAT4", 4, blendweights),
                    stream("BLENDINDICES", "CT_FLOAT4", 4, blendindices),
                ]
            )
            index_streams.extend([indices, indices])

        geometry = {
            "indices": {
                "size": len(indices),
                "streams": index_streams,
                "type": "TRIANGLE_LIST",
            },
            "materials": material_records,
            "smoothing": smoothing,
            "streams": streams,
        }
        if skin_name:
            geometry["skin"] = skin_name
        return geometry, len(mesh.loop_triangles), len(indices)
    finally:
        evaluated.to_mesh_clear()


def import_fbx(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    result = bpy.ops.import_scene.fbx(filepath=path, use_anim=False)
    if "FINISHED" not in result:
        raise RuntimeError(f"FBX import failed: {sorted(result)}")


def build_bone_node(bone, armature, parent_name=None):
    if bone.parent:
        local = bone.parent.matrix_local.inverted() @ bone.matrix_local
    else:
        local = armature.matrix_world @ bone.matrix_local

    node = {"local": matrix_values(local)}
    if parent_name:
        node["parent"] = parent_name
    if bone.children:
        node["children"] = {
            child.name: build_bone_node(child, armature, bone.name) for child in bone.children
        }
    return node


def bone_local_matrix(bone, armature):
    if bone.parent:
        return bone.parent.matrix_local.inverted() @ bone.matrix_local
    return armature.matrix_world @ bone.matrix_local


def rest_pose_animation(node_name, local_matrix):
    return {
        "node": node_name,
        "parameter": "matrix",
        "stream": stream(
            "local_tm",
            "CT_MATRIX4x4",
            16,
            matrix_values(local_matrix),
        ),
        "times": [0],
    }


def build_skin_activation_animations(armature, mesh_object, geometry_name):
    animations = [
        rest_pose_animation(bone.name, bone_local_matrix(bone, armature))
        for bone in armature.data.bones
    ]
    root = next(bone for bone in armature.data.bones if bone.parent is None)
    root_world = armature.matrix_world @ root.matrix_local
    geometry_local = root_world.inverted() @ mesh_object.matrix_world
    animations.append(rest_pose_animation(geometry_name, geometry_local))

    return animations


def write_animation_bones(output_path, armature):
    bone_names = [bone.name for bone in armature.data.bones]
    bones_path = os.path.splitext(output_path)[0] + ".bones"
    bsi_format.write(
        bones_path,
        {
            "bones": bone_names,
            "lod_levels": [len(bone_names)],
        },
    )
    return bones_path


def build_skin(armature, mesh_object, geometry_name):
    bones = list(armature.data.bones)
    roots = [bone for bone in bones if bone.parent is None]
    if len(roots) != 1:
        raise RuntimeError(f"Expected one skeleton root, found {len(roots)}")
    if len(bones) > 255:
        raise RuntimeError("BSI four-byte blend indices support at most 255 exported bones")

    skin_name = geometry_name + "_skin"
    joints = []
    for bone in bones:
        world_bind = armature.matrix_world @ bone.matrix_local
        joints.append(
            {
                "name": bone.name,
                "inv_bind_matrix": matrix_values(world_bind.inverted()),
            }
        )

    root = roots[0]
    root_node = build_bone_node(root, armature)
    root_world = armature.matrix_world @ root.matrix_local
    root_node.setdefault("children", {})[geometry_name] = {
        "geometries": [geometry_name],
        "local": matrix_values(root_world.inverted() @ mesh_object.matrix_world),
        "parent": root.name,
    }
    return (
        skin_name,
        {bone.name: index for index, bone in enumerate(bones)},
        {skin_name: {"bind_matrix": matrix_values(mesh_object.matrix_world), "joints": joints}},
        {root.name: root_node},
    )


def main():
    args = parse_arguments()
    input_path = os.path.abspath(args.input)
    output_path = os.path.abspath(args.output)
    import_fbx(input_path)

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if not meshes:
        raise SystemExit("The FBX contains no mesh objects")

    mesh_object = max(meshes, key=lambda item: len(item.data.vertices))
    geometry_name = safe_name(mesh_object.name, "pusfume_3p")
    stats = weight_stats(mesh_object)
    if args.skin:
        if len(armatures) != 1:
            raise SystemExit(f"Skinned export requires one armature, found {len(armatures)}")
        if stats["unweighted_vertices"] or stats["over_four_influences"]:
            raise SystemExit(
                "Skinned export requires normalized weights with one to four influences: %s"
                % stats
            )
        skin_name, bone_indices, skins, nodes = build_skin(
            armatures[0], mesh_object, geometry_name
        )
        activation_animations = build_skin_activation_animations(
            armatures[0], mesh_object, geometry_name
        )
        bones_path = write_animation_bones(output_path, armatures[0])
    else:
        skin_name, bone_indices, skins = None, None, None
        activation_animations = None
        bones_path = None
        nodes = {
            "root_point": {
                "children": {
                    geometry_name: {
                        "geometries": [geometry_name],
                        "local": IDENTITY,
                        "parent": "root_point",
                    }
                },
                "local": IDENTITY,
            }
        }

    geometry, triangle_count, exported_vertices = build_geometry(
        mesh_object, bone_indices, skin_name
    )
    document = {
        "geometries": {geometry_name: geometry},
        "nodes": nodes,
        "source_path": os.path.basename(input_path),
    }
    if activation_animations:
        document["animations"] = activation_animations
    if skins:
        document["skins"] = skins
    bsi_format.write(output_path, document, compress=args.compress)

    print(
        "PUSFUME_BSI_EXPORT_RESULT="
        + json.dumps(
            {
                "armatures": len(armatures),
                "activation_nodes": len(activation_animations or []),
                "bones": sum(len(item.data.bones) for item in armatures),
                "bones_output": bones_path,
                "compressed": args.compress,
                "mesh": mesh_object.name,
                "output": output_path,
                "skin": args.skin,
                "source_vertices": len(mesh_object.data.vertices),
                "triangles": triangle_count,
                "vertices": exported_vertices,
                "weights": stats,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
