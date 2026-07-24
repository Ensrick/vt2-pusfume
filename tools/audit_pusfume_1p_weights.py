"""Report deform-group coverage and hierarchy for a first-person Blender skin."""

from __future__ import annotations

import json
import os
import sys

import bpy


def arguments_after_separator():
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def main():
    arguments = arguments_after_separator()
    if len(arguments) != 1:
        raise SystemExit("Usage: audit_pusfume_1p_weights.py -- INPUT.blend")

    input_path = os.path.abspath(arguments[0])
    bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    meshes = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH" and obj.vertex_groups
    ]
    if len(meshes) != 1:
        raise RuntimeError("Expected one weighted mesh; found %d" % len(meshes))
    mesh = meshes[0]
    armatures = [
        modifier.object
        for modifier in mesh.modifiers
        if modifier.type == "ARMATURE" and modifier.object is not None
    ]
    if len(armatures) > 1:
        raise RuntimeError("Expected at most one armature modifier; found %d" % len(armatures))
    armature = armatures[0] if armatures else None

    group_names = {group.index: group.name for group in mesh.vertex_groups}
    groups = {
        group.name: {"vertices": 0, "weight": 0.0}
        for group in mesh.vertex_groups
    }
    for vertex in mesh.data.vertices:
        for assignment in vertex.groups:
            if assignment.weight <= 0.000001:
                continue
            group = groups[group_names[assignment.group]]
            group["vertices"] += 1
            group["weight"] += assignment.weight

    weighted_groups = {
        name: {
            "parent": (
                armature.data.bones[name].parent.name
                if armature
                and name in armature.data.bones
                and armature.data.bones[name].parent
                else None
            ),
            "vertices": values["vertices"],
            "weight": round(values["weight"], 6),
        }
        for name, values in groups.items()
        if values["weight"] > 0.000001
    }
    print(
        "PUSFUME_1P_WEIGHT_AUDIT="
        + json.dumps(
            {
                "armature": armature and armature.name,
                "bones": armature and len(armature.data.bones) or 0,
                "mesh": mesh.name,
                "source": input_path,
                "vertices": len(mesh.data.vertices),
                "weighted_groups": weighted_groups,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
