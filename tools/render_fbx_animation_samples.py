"""Render front and side samples from an animated FBX for visual QA."""

from __future__ import annotations

import json
import os
import sys

import bpy
from mathutils import Vector


def mesh_bounds(meshes):
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    lower = Vector(min(point[index] for point in points) for index in range(3))
    upper = Vector(max(point[index] for point in points) for index in range(3))
    return lower, upper


def aim(camera, target):
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def main(input_path, output_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=input_path, automatic_bone_orientation=False)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if not meshes or len(armatures) != 1:
        raise RuntimeError("Animation preview requires meshes and one armature")

    action = armatures[0].animation_data and armatures[0].animation_data.action
    if action is None:
        raise RuntimeError("Animation preview FBX has no assigned action")

    lower, upper = mesh_bounds(meshes)
    center = (lower + upper) * 0.5
    span = upper - lower
    distance = max(span) * 2.2
    camera_data = bpy.data.cameras.new("qa_camera")
    camera = bpy.data.objects.new("qa_camera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(span.x, span.z) * 1.2

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.world = bpy.data.worlds.new("qa_world")
    scene.world.color = (0.03, 0.03, 0.03)

    start = int(round(action.frame_range[0]))
    end = int(round(action.frame_range[1]))
    middle = (start + end) // 2
    os.makedirs(output_dir, exist_ok=True)
    outputs = []
    for frame in (start, middle, end):
        scene.frame_set(frame)
        camera.location = center + Vector((0.0, -distance, span.z * 0.05))
        aim(camera, center)
        path = os.path.join(output_dir, f"frame_{frame:04d}_front.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        outputs.append(path)

        camera.location = center + Vector((distance, 0.0, span.z * 0.05))
        aim(camera, center)
        path = os.path.join(output_dir, f"frame_{frame:04d}_side.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        outputs.append(path)

    print(
        "PUSFUME_ANIMATION_SAMPLES="
        + json.dumps(
            {
                "action": action.name,
                "bounds": {"lower": list(lower), "upper": list(upper)},
                "frames": [start, middle, end],
                "outputs": outputs,
            },
            sort_keys=True,
        )
    )


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) != 2:
    raise SystemExit("usage: render_fbx_animation_samples.py -- INPUT.fbx OUTPUT_DIR")
main(os.path.abspath(arguments[0]), os.path.abspath(arguments[1]))
