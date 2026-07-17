"""Blender properties for the VT2 Content Tools panel."""

import bpy


class VT2ContentToolsSettings(bpy.types.PropertyGroup):
    asset_name: bpy.props.StringProperty(
        name="Asset Name",
        description="Safe base name used for exported VT2 source files",
        default="character",
    )
    export_directory: bpy.props.StringProperty(
        name="Handoff Folder",
        description="Folder that receives FBX files, textures, and the report",
        default="//vt2_handoff/",
        subtype="DIR_PATH",
    )
    scope: bpy.props.EnumProperty(
        name="Scope",
        items=(
            ("ALL", "Whole Scene", "Validate and export all scene meshes and armatures"),
            ("SELECTED", "Selected", "Use selected meshes and their armatures"),
            ("ACTIVE", "Active Character", "Use the active mesh or armature hierarchy"),
        ),
        default="ALL",
    )
    export_mode: bpy.props.EnumProperty(
        name="Export",
        items=(
            ("MODEL", "Model", "Export the skinned model without animation"),
            ("ANIMATION", "Active Clip", "Export the active armature action"),
            ("BOTH", "Model + Active Clip", "Export both handoff files"),
        ),
        default="BOTH",
    )
    clip_name: bpy.props.StringProperty(
        name="Clip Name",
        description="VT2-safe name for the active animation clip",
        default="idle",
    )
    bone_prefix: bpy.props.StringProperty(
        name="Bone Prefix",
        description="Recommended deform-bone prefix; leave empty to disable",
        default="j_",
    )
    maximum_influences: bpy.props.IntProperty(
        name="Max Weights",
        description="Maximum exported bone influences per vertex",
        default=4,
        min=1,
        max=4,
    )
    include_textures: bpy.props.BoolProperty(
        name="Collect Textures",
        description="Copy external images referenced by exported materials",
        default=True,
    )
    allow_warnings: bpy.props.BoolProperty(
        name="Export With Warnings",
        description="Allow export when validation has warnings but no errors",
        default=True,
    )
    material_surface: bpy.props.EnumProperty(
        name="VT2 Surface",
        items=(
            ("OPAQUE", "Opaque Skinned", "Standard skinned character surface"),
            ("CUTOUT", "Skinned Cutout", "Alpha-card fur, whiskers, or feathers"),
            ("EYE", "Eye / Emissive", "Eye or controlled emissive surface"),
        ),
        default="OPAQUE",
    )
    mirror_direction: bpy.props.EnumProperty(
        name="Direction",
        items=(
            ("LEFT_TO_RIGHT", "Left to Right", "Copy j_left poses onto j_right partners"),
            ("RIGHT_TO_LEFT", "Right to Left", "Copy j_right poses onto j_left partners"),
        ),
        default="LEFT_TO_RIGHT",
    )
    mirror_axis: bpy.props.EnumProperty(
        name="Mirror Axis",
        description="Armature-local axis separating left and right",
        items=(
            ("X", "X", "Mirror across the armature-local X axis"),
            ("Y", "Y", "Mirror across the armature-local Y axis"),
            ("Z", "Z", "Mirror across the armature-local Z axis"),
        ),
        default="X",
    )
    mirror_selected_only: bpy.props.BoolProperty(
        name="Selected Source Bones Only",
        description="Mirror only selected bones on the source side",
        default=True,
    )
    mirror_insert_keyframes: bpy.props.BoolProperty(
        name="Insert Keyframes",
        description="Key mirrored destination pose channels at the current frame",
        default=False,
    )
    last_errors: bpy.props.IntProperty(default=0, options={"HIDDEN"})
    last_warnings: bpy.props.IntProperty(default=0, options={"HIDDEN"})
    last_report: bpy.props.StringProperty(default="Not validated", options={"HIDDEN"})
    last_output: bpy.props.StringProperty(default="", options={"HIDDEN"})


CLASSES = (VT2ContentToolsSettings,)
