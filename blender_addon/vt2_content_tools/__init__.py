"""VT2 Content Tools Blender extension."""

bl_info = {
    "name": "VT2 Content Tools",
    "author": "Ensrick and contributors",
    "version": (0, 1, 0),
    "blender": (4, 3, 0),
    "location": "View3D > Sidebar > VT2",
    "description": "Validate and export Blender assets for Vermintide 2",
    "category": "Import-Export",
}

try:
    import bpy
except ModuleNotFoundError:  # Allows pure contract tests without Blender.
    bpy = None

if bpy is not None:
    from .operators import CLASSES as OPERATOR_CLASSES
    from .properties import CLASSES as PROPERTY_CLASSES
    from .properties import VT2ContentToolsSettings
    from .ui import CLASSES as UI_CLASSES

    CLASSES = PROPERTY_CLASSES + OPERATOR_CLASSES + UI_CLASSES
else:
    CLASSES = ()


def register():
    if bpy is None:
        raise RuntimeError("VT2 Content Tools can only register inside Blender")
    for cls in CLASSES:
        bpy.utils.register_class(cls)
    bpy.types.Scene.vt2_content_tools = bpy.props.PointerProperty(
        type=VT2ContentToolsSettings
    )


def unregister():
    if bpy is None:
        return
    del bpy.types.Scene.vt2_content_tools
    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)
