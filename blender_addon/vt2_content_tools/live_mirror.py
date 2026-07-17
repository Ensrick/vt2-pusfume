"""Live Pose Mode mirroring for VT2 j_left/j_right bone names."""

import bpy
from bpy.app.handlers import persistent

from .operators import apply_pose_mirror


_UPDATING = False


@persistent
def _live_mirror_handler(scene, _depsgraph):
    global _UPDATING
    if _UPDATING:
        return

    settings = getattr(scene, "vt2_content_tools", None)
    context = bpy.context
    armature = context.object
    if (
        settings is None
        or not settings.live_mirror_enabled
        or context.mode != "POSE"
        or armature is None
        or armature.type != "ARMATURE"
    ):
        return

    _UPDATING = True
    try:
        apply_pose_mirror(context, settings, changed_only=True)
    finally:
        _UPDATING = False


def register_handlers():
    if _live_mirror_handler not in bpy.app.handlers.depsgraph_update_post:
        bpy.app.handlers.depsgraph_update_post.append(_live_mirror_handler)


def unregister_handlers():
    if _live_mirror_handler in bpy.app.handlers.depsgraph_update_post:
        bpy.app.handlers.depsgraph_update_post.remove(_live_mirror_handler)

