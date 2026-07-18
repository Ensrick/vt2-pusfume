"""Live Pose Mode mirroring for VT2 j_left/j_right bone names."""

import bpy
from bpy.app.handlers import persistent

from . import core
from .operators import _matrix_error, apply_pose_pairs


_UPDATING = False
_POSE_CACHE = {}


def _cache_key(armature):
    return armature.as_pointer()


def _pose_snapshot(armature):
    return {bone.name: bone.matrix.copy() for bone in armature.pose.bones}


def reset_live_mirror_state(armature=None):
    """Forget prior poses so enabling the tool never moves a bone immediately."""
    if armature is None:
        _POSE_CACHE.clear()
    else:
        _POSE_CACHE.pop(_cache_key(armature), None)


def apply_live_pose_mirror(context):
    """Mirror whichever selected side changed since the previous update."""
    armature = context.object
    current = _pose_snapshot(armature)
    key = _cache_key(armature)
    previous = _POSE_CACHE.get(key)
    if previous is None:
        _POSE_CACHE[key] = current
        return {"pairs": 0, "changed": 0, "constrained": 0, "keyed": 0}

    active = context.active_pose_bone
    active_name = active.name if active else None
    candidates = {}
    bone_names = set(current)
    for bone in armature.pose.bones:
        if not bone.select or bone.name not in previous:
            continue
        partner = core.mirrored_partner_name(bone.name)
        if partner not in bone_names:
            continue
        error = _matrix_error(current[bone.name], previous[bone.name])
        if error <= 1e-6:
            continue
        pair_key = tuple(sorted((bone.name, partner)))
        existing = candidates.get(pair_key)
        if (
            existing is None
            or bone.name == active_name
            or (existing[0] != active_name and error > existing[2])
        ):
            candidates[pair_key] = (bone.name, partner, error)

    pairs = [(source, target) for source, target, _error in candidates.values()]
    result = apply_pose_pairs(
        context,
        pairs,
        axis="X",
        insert_keyframes=context.scene.tool_settings.use_keyframe_insert_auto,
    )
    _POSE_CACHE[key] = _pose_snapshot(armature)
    return result


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
        if armature is not None and armature.type == "ARMATURE":
            reset_live_mirror_state(armature)
        return

    if context.screen is not None and context.screen.is_animation_playing:
        reset_live_mirror_state(armature)
        return

    _UPDATING = True
    try:
        apply_live_pose_mirror(context)
    finally:
        _UPDATING = False


def register_handlers():
    if _live_mirror_handler not in bpy.app.handlers.depsgraph_update_post:
        bpy.app.handlers.depsgraph_update_post.append(_live_mirror_handler)


def unregister_handlers():
    if _live_mirror_handler in bpy.app.handlers.depsgraph_update_post:
        bpy.app.handlers.depsgraph_update_post.remove(_live_mirror_handler)
    reset_live_mirror_state()
