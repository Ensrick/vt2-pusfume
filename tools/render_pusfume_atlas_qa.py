"""Render the compiled Pusfume FBX with the exact generated diffuse atlas."""

from __future__ import annotations

import json
import os
import sys

import bpy
from mathutils import Vector


ATLAS_MATERIALS = {
    "p_main",
    "p_eye",
    "p_eye_g",
    "p_metal",
    "p_glob",
    "p_armor",
    "p_ammo_box_limited_a",
    "p_ammo_box_limited_b",
}


def bounds(meshes):
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    lower = Vector(min(point[index] for point in points) for index in range(3))
    upper = Vector(max(point[index] for point in points) for index in range(3))
    return lower, upper


def aim(camera, target):
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def configure_material(material, atlas_image):
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    shader.inputs["Roughness"].default_value = 0.7

    if material.name in ATLAS_MATERIALS:
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = atlas_image
        texture.interpolation = "Linear"
        material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    else:
        shader.inputs["Base Color"].default_value = (0.12, 0.12, 0.12, 1.0)


def main(fbx_path, atlas_path, output_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx_path, automatic_bone_orientation=False)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("The compiled FBX contains no meshes")

    atlas_image = bpy.data.images.load(atlas_path, check_existing=False)
    atlas_image.colorspace_settings.name = "sRGB"
    for mesh in meshes:
        for material in mesh.data.materials:
            configure_material(material, atlas_image)

    lower, upper = bounds(meshes)
    center = (lower + upper) * 0.5
    span = upper - lower
    distance = max(span) * 2.2
    camera_data = bpy.data.cameras.new("qa_camera")
    camera = bpy.data.objects.new("qa_camera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(span.x, span.z) * 1.15

    light_data = bpy.data.lights.new("qa_key", "AREA")
    light_data.energy = 1400
    light_data.shape = "DISK"
    light_data.size = max(span) * 1.5
    light = bpy.data.objects.new("qa_key", light_data)
    bpy.context.collection.objects.link(light)
    light.location = center + Vector((-distance, -distance, span.z))
    aim(light, center)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("qa_world")
    scene.world.color = (0.025, 0.025, 0.025)
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.frame_set(int(scene.frame_start))

    os.makedirs(output_dir, exist_ok=True)
    views = {
        "front": Vector((0.0, -distance, span.z * 0.05)),
        "side": Vector((distance, 0.0, span.z * 0.05)),
        "back": Vector((0.0, distance, span.z * 0.05)),
    }
    outputs = []
    for name, offset in views.items():
        camera.location = center + offset
        aim(camera, center)
        output_path = os.path.join(output_dir, f"atlas_{name}.png")
        scene.render.filepath = output_path
        bpy.ops.render.render(write_still=True)
        outputs.append(output_path)

    print(
        "PUSFUME_ATLAS_QA="
        + json.dumps(
            {
                "fbx": fbx_path,
                "atlas": atlas_path,
                "materials": sorted(ATLAS_MATERIALS),
                "outputs": outputs,
            },
            sort_keys=True,
        )
    )


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) != 3:
    raise SystemExit("usage: render_pusfume_atlas_qa.py -- MODEL.fbx ATLAS.png OUTPUT_DIR")
main(*(os.path.abspath(value) for value in arguments))
