"""Report Blender material, mesh, rig, and action contracts as JSON.

Run with Blender 5.2:
    blender --background --factory-startup --disable-autoexec \
        --python tools/audit_blend_contract.py -- INPUT.blend OUTPUT.json
"""

from __future__ import annotations

import json
import os
import sys

import bpy


def matrix_rows(matrix):
    return [[round(value, 8) for value in row] for row in matrix]


def socket_value(socket):
    if not hasattr(socket, "default_value"):
        return None
    value = socket.default_value
    if isinstance(value, (int, float, bool, str)):
        return value
    try:
        return [round(float(component), 8) for component in value]
    except (TypeError, ValueError):
        return str(value)


def image_record(image):
    return {
        "alpha_mode": image.alpha_mode,
        "colorspace": image.colorspace_settings.name,
        "filepath": bpy.path.abspath(image.filepath),
        "name": image.name,
        "packed": image.packed_file is not None,
        "size": list(image.size),
        "source": image.source,
    }


def material_record(material):
    result = {
        "diffuse_color": [round(value, 8) for value in material.diffuse_color],
        "name": material.name,
        "use_nodes": material.use_nodes,
    }
    if not material.use_nodes or material.node_tree is None:
        return result

    nodes = []
    for node in material.node_tree.nodes:
        record = {
            "inputs": {
                socket.name: socket_value(socket)
                for socket in node.inputs
                if not socket.is_linked and socket_value(socket) is not None
            },
            "label": node.label,
            "name": node.name,
            "type": node.bl_idname,
        }
        image = getattr(node, "image", None)
        if image is not None:
            record["image"] = image_record(image)
        nodes.append(record)

    result["links"] = [
        {
            "from_node": link.from_node.name,
            "from_socket": link.from_socket.name,
            "to_node": link.to_node.name,
            "to_socket": link.to_socket.name,
        }
        for link in material.node_tree.links
    ]
    result["nodes"] = nodes
    return result


def bounds(values):
    if not values:
        return None
    return {
        "min": [round(min(value[index] for value in values), 8) for index in range(2)],
        "max": [round(max(value[index] for value in values), 8) for index in range(2)],
    }


def mesh_record(obj):
    material_names = [
        slot.material.name if slot.material is not None else None
        for slot in obj.material_slots
    ]
    polygons_by_material = {
        name or f"<slot:{index}>": 0 for index, name in enumerate(material_names)
    }
    uv_by_material = {
        name or f"<slot:{index}>": [] for index, name in enumerate(material_names)
    }
    active_uv = obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        material_name = (
            material_names[polygon.material_index]
            if polygon.material_index < len(material_names)
            else None
        )
        key = material_name or f"<slot:{polygon.material_index}>"
        polygons_by_material[key] = polygons_by_material.get(key, 0) + 1
        if active_uv is not None:
            uv_by_material.setdefault(key, []).extend(
                tuple(active_uv.data[index].uv) for index in polygon.loop_indices
            )

    return {
        "armature": next(
            (
                modifier.object.name
                for modifier in obj.modifiers
                if modifier.type == "ARMATURE" and modifier.object is not None
            ),
            None,
        ),
        "materials": material_names,
        "matrix_world": matrix_rows(obj.matrix_world),
        "name": obj.name,
        "polygon_count": len(obj.data.polygons),
        "polygons_by_material": polygons_by_material,
        "uv_bounds_by_material": {
            name: bounds(values) for name, values in uv_by_material.items()
        },
        "uv_layers": [layer.name for layer in obj.data.uv_layers],
        "vertex_count": len(obj.data.vertices),
        "vertex_groups": [group.name for group in obj.vertex_groups],
    }


def action_fcurves(action):
    if hasattr(action, "layers"):
        return [
            curve
            for layer in action.layers
            for strip in layer.strips
            for channelbag in strip.channelbags
            for curve in channelbag.fcurves
        ]
    return list(action.fcurves)


def action_record(action):
    frame_start, frame_end = action.frame_range
    result = {
        "frame_range": [float(frame_start), float(frame_end)],
        "frame_range_manual": bool(action.use_frame_range),
        "name": action.name,
    }
    if action.use_frame_range:
        result["manual_range"] = [action.frame_start, action.frame_end]

    curves = action_fcurves(action)
    result["curves"] = len(curves)
    result["curve_paths"] = sorted({curve.data_path for curve in curves})
    result["keyframe_range"] = (
        [
            min(point.co.x for curve in curves for point in curve.keyframe_points),
            max(point.co.x for curve in curves for point in curve.keyframe_points),
        ]
        if any(curve.keyframe_points for curve in curves)
        else None
    )
    result["modifiers"] = sorted(
        {
            modifier.type
            for curve in curves
            for modifier in curve.modifiers
        }
    )
    return result


def armature_record(obj):
    animation = obj.animation_data
    return {
        "action": animation.action.name if animation and animation.action else None,
        "bones": {
            bone.name: {
                "matrix_local": matrix_rows(bone.matrix_local),
                "parent": bone.parent.name if bone.parent else None,
                "use_deform": bone.use_deform,
            }
            for bone in obj.data.bones
        },
        "constraints": {
            bone.name: [constraint.type for constraint in bone.constraints]
            for bone in obj.pose.bones
            if bone.constraints
        },
        "drivers": len(animation.drivers) if animation else 0,
        "matrix_world": matrix_rows(obj.matrix_world),
        "name": obj.name,
        "nla_strips": [
            {
                "action": strip.action.name if strip.action else None,
                "frame_end": strip.frame_end,
                "frame_start": strip.frame_start,
                "name": strip.name,
            }
            for track in (animation.nla_tracks if animation else ())
            for strip in track.strips
        ],
        "pose_basis_non_identity": [
            bone.name for bone in obj.pose.bones if not bone.matrix_basis.is_identity
        ],
    }


def main(input_path, output_path):
    bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    report = {
        "actions": [action_record(action) for action in bpy.data.actions],
        "armatures": [
            armature_record(obj)
            for obj in bpy.context.scene.objects
            if obj.type == "ARMATURE"
        ],
        "blender_version": bpy.app.version_string,
        "input": input_path,
        "materials": [
            material_record(material) for material in bpy.data.materials
        ],
        "meshes": [
            mesh_record(obj)
            for obj in bpy.context.scene.objects
            if obj.type == "MESH"
        ],
    }
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as output_file:
        json.dump(report, output_file, indent=2, sort_keys=True)
        output_file.write("\n")
    print("PUSFUME_BLEND_AUDIT=" + json.dumps({
        "actions": len(report["actions"]),
        "armatures": len(report["armatures"]),
        "materials": len(report["materials"]),
        "meshes": len(report["meshes"]),
        "output": output_path,
    }, sort_keys=True))


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) != 2:
    raise SystemExit("usage: audit_blend_contract.py -- INPUT.blend OUTPUT.json")
main(*(os.path.abspath(argument) for argument in arguments))
