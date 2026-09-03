"""Compare world-space mesh bounds between two Blender files."""

from __future__ import annotations

import json
import math
import os
import sys

import bpy
from mathutils import Vector


def arguments_after_separator() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def vector_list(value: Vector) -> list[float]:
    return [round(component, 8) for component in value]


def read_bounds(path: str) -> dict:
    bpy.ops.wm.open_mainfile(filepath=path, load_ui=False)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No meshes in {path}")

    minimum = Vector((math.inf, math.inf, math.inf))
    maximum = Vector((-math.inf, -math.inf, -math.inf))
    rows = []
    for mesh in meshes:
        points = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
        mesh_minimum = Vector(
            tuple(min(point[axis] for point in points) for axis in range(3))
        )
        mesh_maximum = Vector(
            tuple(max(point[axis] for point in points) for axis in range(3))
        )
        for axis in range(3):
            minimum[axis] = min(minimum[axis], mesh_minimum[axis])
            maximum[axis] = max(maximum[axis], mesh_maximum[axis])
        rows.append(
            {
                "center": vector_list((mesh_minimum + mesh_maximum) * 0.5),
                "maximum": vector_list(mesh_maximum),
                "minimum": vector_list(mesh_minimum),
                "name": mesh.name,
                "size": vector_list(mesh_maximum - mesh_minimum),
                "vertices": len(points),
            }
        )

    return {
        "center": vector_list((minimum + maximum) * 0.5),
        "maximum": vector_list(maximum),
        "meshes": rows,
        "minimum": vector_list(minimum),
        "path": path,
        "size": vector_list(maximum - minimum),
        "vertices": sum(row["vertices"] for row in rows),
    }


def main() -> None:
    arguments = arguments_after_separator()
    if len(arguments) != 2:
        raise SystemExit(
            "Usage: compare_first_person_mesh_bounds.py -- CUSTOM.blend DONOR.blend"
        )
    custom_path, donor_path = map(os.path.abspath, arguments)
    custom = read_bounds(custom_path)
    donor = read_bounds(donor_path)
    custom_center = Vector(custom["center"])
    donor_center = Vector(donor["center"])
    custom_size = Vector(custom["size"])
    donor_size = Vector(donor["size"])
    report = {
        "center_delta_custom_to_donor": vector_list(donor_center - custom_center),
        "custom": custom,
        "donor": donor,
        "size_ratio_donor_over_custom": vector_list(
            Vector(
                tuple(
                    donor_size[axis] / custom_size[axis]
                    for axis in range(3)
                )
            )
        ),
    }
    print("PUSFUME_1P_MESH_BOUNDS=" + json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
