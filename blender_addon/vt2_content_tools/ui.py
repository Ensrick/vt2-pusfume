"""VT2 Content Tools sidebar UI."""

import bpy


class VT2_PT_content_tools(bpy.types.Panel):
    bl_label = "VT2 Content Tools"
    bl_idname = "VT2_PT_content_tools"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "VT2"

    def draw(self, context):
        layout = self.layout
        settings = context.scene.vt2_content_tools

        project = layout.box()
        project.label(text="Handoff", icon="PACKAGE")
        project.prop(settings, "asset_name")
        project.prop(settings, "scope")
        project.prop(settings, "export_directory")

        validation = layout.box()
        validation.label(text="Validation", icon="CHECKMARK")
        row = validation.row(align=True)
        row.prop(settings, "maximum_influences")
        row.prop(settings, "bone_prefix")
        validation.operator("vt2.validate", icon="VIEWZOOM")
        validation.operator("vt2.repair_weights", icon="MOD_VERTEX_WEIGHT")
        status = validation.row()
        status.alert = settings.last_errors > 0
        status.label(
            text=f"{settings.last_errors} errors, {settings.last_warnings} warnings"
        )
        validation.label(text=settings.last_report)

        material = layout.box()
        material.label(text="Active Material", icon="MATERIAL")
        material.prop(settings, "material_surface")
        material.operator("vt2.tag_material", icon="BOOKMARKS")

        mirror = layout.box()
        mirror.label(text="Pose Mirroring", icon="ARROW_LEFTRIGHT")
        mirror.prop(settings, "mirror_direction", expand=True)
        row = mirror.row(align=True)
        row.prop(settings, "mirror_axis", expand=True)
        mirror.prop(settings, "mirror_selected_only")
        mirror.prop(settings, "mirror_insert_keyframes")
        live = mirror.row()
        live.prop(settings, "live_mirror_enabled", toggle=True, icon="CONSTRAINT_BONE")
        if settings.live_mirror_enabled:
            mirror.label(text="Live mirror follows the selected source side.", icon="INFO")
        mirror.operator("vt2.mirror_pose", icon="MOD_MIRROR")

        export = layout.box()
        export.label(text="Export", icon="EXPORT")
        export.prop(settings, "export_mode")
        if settings.export_mode in {"ANIMATION", "BOTH"}:
            export.prop_search(settings, "clip_action", bpy.data, "actions")
            export.prop(settings, "clip_name")
        export.prop(settings, "include_textures")
        export.prop(settings, "allow_warnings")
        export.operator("vt2.export_handoff", icon="FILE_TICK")
        if settings.last_output:
            export.label(text=settings.last_output, icon="FOLDER_REDIRECT")

        note = layout.box()
        note.label(text="Blender prepares source assets.", icon="INFO")
        note.label(text="VT2 SDK/VMB compiles the final unit.")


CLASSES = (VT2_PT_content_tools,)
