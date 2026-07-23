local mod = get_mod("pusfume")

local M = {}

local SKAVEN_FIRST_PERSON_BASE =
    "units/beings/player/dark_pact_first_person_base/skaven_common/chr_first_person_base"
local SKAVEN_FIRST_PERSON_BOT_BASE =
    "units/beings/player/dark_pact_first_person_base/skaven_common/chr_first_person_bot_base"
local PACKMASTER_FIRST_PERSON_ARMS =
    "units/beings/player/dark_pact_skins/skaven_pack_master/skin_0000/first_person/chr_first_person_mesh"
local GUTTER_RUNNER_FIRST_PERSON_ARMS =
    "units/beings/player/dark_pact_skins/skaven_gutter_runner/skin_0000/first_person/chr_first_person_mesh"
local GLOBADIER_FIRST_PERSON_ARMS =
    "units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_0000/first_person/chr_first_person_mesh"
local WARPFIRE_FIRST_PERSON_ARMS =
    "units/beings/player/dark_pact_skins/skaven_warpfire_thrower/skin_0000/first_person/chr_first_person_mesh"
local RATLING_FIRST_PERSON_ARMS =
    "units/beings/player/dark_pact_skins/skaven_ratlinggunner/skin_0000/first_person/chr_first_person_mesh"
local SKAVEN_FIRST_PERSON_ARMS = {
    packmaster = PACKMASTER_FIRST_PERSON_ARMS,
    gutter_runner = GUTTER_RUNNER_FIRST_PERSON_ARMS,
    globadier = GLOBADIER_FIRST_PERSON_ARMS,
    warpfire_thrower = WARPFIRE_FIRST_PERSON_ARMS,
    ratling_gunner = RATLING_FIRST_PERSON_ARMS,
}
local SKAVEN_ROLE_BY_POSE = {
    to_packmaster = "packmaster",
    to_gutter_runner = "gutter_runner",
    to_globadier = "globadier",
    to_warpfire_thrower = "warpfire_thrower",
    to_ratling_gunner = "ratling_gunner",
}
local NATIVE_SKAVEN_FIRST_PERSON_PACKAGES = {
    SKAVEN_FIRST_PERSON_BASE,
    SKAVEN_FIRST_PERSON_BOT_BASE,
    PACKMASTER_FIRST_PERSON_ARMS,
    GUTTER_RUNNER_FIRST_PERSON_ARMS,
    GLOBADIER_FIRST_PERSON_ARMS,
    WARPFIRE_FIRST_PERSON_ARMS,
    RATLING_FIRST_PERSON_ARMS,
}
local NATIVE_SKAVEN_PACKAGE_REFERENCE = "pusfume_native_skaven_first_person"
local state = {
    cosmetic_registered = false,
    hook_installed = false,
    probe_hook_installed = false,
    preview_package_filter_installed = false,
    preview_package_filtered = false,
    resource_available = false,
    first_person_resource_available = false,
    first_person_hook_installed = false,
    first_person_material_package_requested = false,
    first_person_material_package_loaded = false,
    first_person_material_package_error_logged = false,
    first_person_material_error_logged = false,
    first_person_materials_applied = false,
    native_skaven_packages_requested = false,
    native_skaven_packages_loaded = false,
    native_skaven_skin_registered = false,
    dual_first_person_rigs_ready = false,
    hero_preview_enabled = false,
    donor_package_requested = false,
    donor_package_loaded = false,
    donor_package_error_logged = false,
    whisker_donor_package_requested = false,
    whisker_donor_package_loaded = false,
    whisker_donor_package_error_logged = false,
    child_package_requested = false,
    child_package_loaded = false,
    child_package_error_logged = false,
    shadow_package_requested = false,
    shadow_package_loaded = false,
    shadow_package_error_logged = false,
    material_probe_command_installed = false,
    material_probe_mode = nil,
    material_probe_units = setmetatable({}, { __mode = "k" }),
    donor_material_error_logged = false,
    donor_material_applied = false,
    whisker_material_applied = false,
    fur_material_applied = false,
    dialogue_voice_hook_installed = false,
    donor_texture_errors = {},
    donor_weapons_hidden = false,
    inactive_warpfire_units = setmetatable({}, { __mode = "k" }),
    particle_suppressed_units = setmetatable({}, { __mode = "k" }),
    locomotion_events_available = false,
}

local WALK_ENTER_SPEED = 0.5
local IDLE_ENTER_SPEED = 0.2
local FIRST_PERSON_WEAPON_HIDE_REASON = "pusfume_hands_diagnostic"
local PACKMASTER_WEAPON_HIDE_REASON = "catapulted"
local ASSASSIN_ROLE = "gutter_runner"
local WARPFIRE_ITEM_KEY = "pusfume_warpfire_thrower"
local PUSFUME_CHARACTER_VO = "vs_poison_wind_globadier"
local PUSFUME_SOUND_CHARACTER = "dwarf_slayer"

local installed_config

local function apply_pusfume_voice_switch(unit)
    if not unit or not Unit.alive(unit) then
        return false
    end

    Unit.set_flow_variable(unit, "character_vo", PUSFUME_CHARACTER_VO)
    Unit.set_flow_variable(unit, "sound_character", PUSFUME_SOUND_CHARACTER)
    Unit.flow_event(unit, "character_vo_set")

    return true
end

local function ensure_native_skaven_first_person_packages(config)
    if not config.native_skaven_first_person and not config.dual_first_person_rigs then
        return false
    end

    local all_loaded = true
    state.native_skaven_packages_requested = true

    for _, package_name in ipairs(NATIVE_SKAVEN_FIRST_PERSON_PACKAGES) do
        local package_available = Managers.package
            and Application.can_get("package", package_name)

        if package_available and not Managers.package:has_loaded(
                package_name, NATIVE_SKAVEN_PACKAGE_REFERENCE) then
            -- PackageManager's fourth argument is `asynchronous`; spawning
            -- immediately after a queued load recreates the nil-unit crash.
            Managers.package:load(package_name, NATIVE_SKAVEN_PACKAGE_REFERENCE, nil, false)
        end

        local loaded = package_available
            and Managers.package:has_loaded(package_name, NATIVE_SKAVEN_PACKAGE_REFERENCE)
            and Application.can_get("unit", package_name)
        all_loaded = all_loaded and loaded

        if not loaded then
            mod:error("[pusfume] Native Skaven first-person package failed residency: %s",
                package_name)
        end
    end

    state.native_skaven_packages_loaded = all_loaded

    if all_loaded and not state.native_skaven_packages_logged then
        state.native_skaven_packages_logged = true
        mod:info("[pusfume] Native Skaven first-person packages resident: %d",
            #NATIVE_SKAVEN_FIRST_PERSON_PACKAGES)
    end

    return all_loaded
end

local function unit_has_animation_event(unit, event_name)
    return type(event_name) == "string"
        and unit
        and Unit.alive(unit)
        and Unit.has_animation_state_machine(unit)
        and Unit.has_animation_event(unit, event_name)
end

local function play_first_person_pose(extension, event_name)
    if extension._pusfume_active_skaven_role == "gutter_runner"
            and type(installed_config and installed_config.assassin_first_person_clips) == "table" then
        -- Janfon's clips are driven directly below. Re-entering the native
        -- Gutter Runner state machine here would overwrite their bone output.
        return true
    end

    local first_person_unit = extension._pusfume_active_animation_unit
        or extension.first_person_unit

    if unit_has_animation_event(first_person_unit, event_name) then
        Unit.animation_event(first_person_unit, event_name)
        return true
    end

    return false
end

local ASSASSIN_CLIP_TARGET_DURATION = {
    claws_equip = 1.1,
    claws_light_attack_right_first = 0.7,
    claws_light_attack_right_second = 0.7,
    claws_light_attack_stab_left = 0.7,
    claws_light_attack_stab_left_hit = 0.7,
    claws_light_attack_last = 0.7,
}

local function play_custom_first_person_clip(extension, event_name)
    local clips = installed_config and installed_config.assassin_first_person_clips
    local clip = type(clips) == "table" and clips[event_name]

    if not clip or extension._pusfume_active_skaven_role ~= "gutter_runner" then
        return false
    end

    local animation_unit = extension._pusfume_active_animation_unit
    if not animation_unit or not Unit.alive(animation_unit) then
        return false
    end

    local previous = extension._pusfume_assassin_clip
    if previous and previous.event == event_name and clip.loop == true then
        return true
    end

    if not extension._pusfume_assassin_manual_driver then
        if Unit.has_animation_state_machine(animation_unit) then
            Unit.disable_animation_state_machine(animation_unit)
            extension._pusfume_assassin_disabled_state_machine_unit =
                animation_unit
        end
        extension._pusfume_assassin_manual_driver = true
        mod:info("[pusfume] Janfon assassin manual-time driver enabled")
    end

    local clip_id = Unit.crossfade_animation(
        animation_unit, clip.clip, 1, 0.08, clip.loop == true, "normal")
    Unit.crossfade_animation_set_speed(animation_unit, clip_id, 0)
    Unit.crossfade_animation_set_time(animation_unit, clip_id, 0, true)
    local target_duration = ASSASSIN_CLIP_TARGET_DURATION[event_name]
        or clip.duration
    extension._pusfume_assassin_clip = {
        animation_unit = animation_unit,
        event = event_name,
        id = clip_id,
        duration = clip.duration,
        loop = clip.loop == true,
        next_sample = 0.1,
        playback_rate = clip.duration / target_duration,
        started_at = Managers.time and Managers.time:time("game") or 0,
        target_duration = target_duration,
    }
    mod:info(
        "[pusfume] Janfon assassin 1P clip event=%s clip=%s id=%s duration=%.3f target=%.3f rate=%.3f loop=%s",
        event_name, clip.clip, tostring(clip_id), clip.duration or 0,
        target_duration, clip.duration / target_duration,
        tostring(clip.loop == true))

    return true
end

local function update_custom_first_person_clip(extension, t)
    local active = extension._pusfume_assassin_clip
    if not active or extension._pusfume_active_skaven_role ~= "gutter_runner"
            or not active.animation_unit or not Unit.alive(active.animation_unit) then
        return
    end

    local elapsed = math.max(0, t - active.started_at)
    local clip_time = elapsed * active.playback_rate
    if active.loop then
        clip_time = clip_time % active.duration
    else
        clip_time = math.min(clip_time, active.duration)
    end
    Unit.crossfade_animation_set_time(
        active.animation_unit, active.id, clip_time, true)

    if elapsed >= active.next_sample and active.next_sample <= 0.7 then
        mod:info(
            "[pusfume] Janfon assassin sample event=%s elapsed=%.3f clip_time=%.3f/%.3f bone_mode=%s",
            active.event, elapsed, clip_time, active.duration,
            Unit.animation_bone_mode(active.animation_unit))
        active.next_sample = active.next_sample + 0.2
    end
end

local function update_first_person_weapon_pose(extension, equipment)
    local wielded_slot = equipment and equipment.wielded_slot

    if extension._pusfume_weapon_pose_slot ~= wielded_slot then
        local item_template = extension.inventory_extension
            and extension.inventory_extension:get_wielded_slot_item_template()
        local role_event = item_template and item_template.pusfume_role_pose
            or wielded_slot == "slot_melee" and "to_packmaster"
            or wielded_slot == "slot_ranged" and "to_warpfire_thrower"

        extension._pusfume_weapon_pose_slot = wielded_slot

        if role_event and play_first_person_pose(extension, role_event) then
            mod:info("[pusfume] First-person role pose slot=%s event=%s",
                tostring(wielded_slot), role_event)
        end
    end
end

local function restore_first_person_weapons(extension)
    -- VT2 assigns inventory_extension in extensions_ready(), after init.
    -- Calling the native hide API during construction crashes before that
    -- lifecycle boundary, so leave the request pending until it is available.
    if not extension.inventory_extension then
        return false
    end

    local equipment = extension.inventory_extension:equipment()
    update_first_person_weapon_pose(extension, equipment)

    local right_weapon_unit = equipment and equipment.right_hand_wielded_unit
    local left_weapon_unit = equipment and equipment.left_hand_wielded_unit
    local weapon_unit = right_weapon_unit or left_weapon_unit
    local hide_reasons = extension.hide_weapon_reasons or {}
    local presentation_blocked = hide_reasons[PACKMASTER_WEAPON_HIDE_REASON]
        or hide_reasons[FIRST_PERSON_WEAPON_HIDE_REASON]
    local same_weapon_units =
        extension._pusfume_presented_right_weapon_unit == right_weapon_unit
        and extension._pusfume_presented_left_weapon_unit == left_weapon_unit

    if extension._pusfume_weapon_presentation_ready
            and same_weapon_units and not presentation_blocked then
        return true
    end

    -- Wait until vanilla has spawned and linked the selected first-person
    -- weapon. Otherwise the visibility call succeeds too early and the later
    -- wield flow can hide the Packmaster claw again.
    if not weapon_unit or not Unit.alive(weapon_unit) then
        return false
    end

    if extension._pusfume_active_skaven_role == ASSASSIN_ROLE then
        if right_weapon_unit and Unit.alive(right_weapon_unit) then
            Unit.set_unit_visibility(right_weapon_unit, false)
        end
        if left_weapon_unit and Unit.alive(left_weapon_unit) then
            Unit.set_unit_visibility(left_weapon_unit, false)
        end

        extension._pusfume_weapon_presentation_ready = true
        extension._pusfume_presented_right_weapon_unit = right_weapon_unit
        extension._pusfume_presented_left_weapon_unit = left_weapon_unit
        if not extension._pusfume_assassin_hands_only_logged then
            extension._pusfume_assassin_hands_only_logged = true
            mod:info(
                "[pusfume] Assassin hands-only prototype active; action units retained and claw geometry hidden")
        end

        return true
    end

    extension._pusfume_assassin_hands_only_logged = nil
    extension:unhide_weapons(PACKMASTER_WEAPON_HIDE_REASON)

    -- v0.6.19-v0.6.29 used this mod-owned reason while diagnosing Janfon's
    -- hands. Clear it after a hot reload without issuing a redundant show call
    -- in a clean process where it was never installed.
    if extension.hide_weapon_reasons
            and extension.hide_weapon_reasons[FIRST_PERSON_WEAPON_HIDE_REASON] then
        extension:unhide_weapons(FIRST_PERSON_WEAPON_HIDE_REASON)
    end

    local first_person_unit = extension.first_person_unit
    local armed_event = unit_has_animation_event(first_person_unit, "to_armed")
    local armed_variable = first_person_unit
        and Unit.animation_has_variable(first_person_unit, "armed")

    -- Fatshark performs this handshake in PackmasterStateEquipping after the
    -- claw is spawned. Pusfume is an Adventure hero and never enters that
    -- Pactsworn-only state, so reproduce only its presentation contract.
    if armed_event then
        extension:animation_event("to_armed")
    end

    if armed_variable then
        extension:animation_set_variable("armed", 1)
    end

    local remaining_reasons = {}
    for reason in pairs(extension.hide_weapon_reasons or {}) do
        remaining_reasons[#remaining_reasons + 1] = tostring(reason)
    end
    table.sort(remaining_reasons)

    extension._pusfume_weapons_hidden = false
    extension._pusfume_weapon_hide_pending = false
    extension._pusfume_weapon_presentation_ready = true
    extension._pusfume_presented_right_weapon_unit = right_weapon_unit
    extension._pusfume_presented_left_weapon_unit = left_weapon_unit

    if not same_weapon_units or presentation_blocked
            or not extension._pusfume_weapon_hide_logged then
        extension._pusfume_weapon_hide_logged = true
        mod:info(
            "[pusfume] First-person weapon armed slot=%s right=%s left=%s root=%s scale=%s claw_nodes=%s/%s event=%s variable=%s recovered_hidden=%s remaining_hide_reasons=%s",
            tostring(equipment.wielded_slot),
            tostring(right_weapon_unit),
            tostring(left_weapon_unit),
            tostring(Unit.local_position(weapon_unit, 0)),
            tostring(Unit.local_scale(weapon_unit, 0)),
            tostring(Unit.has_node(weapon_unit, "bottom_claw")),
            tostring(Unit.has_node(weapon_unit, "top_claw")),
            tostring(armed_event),
            tostring(armed_variable),
            tostring(presentation_blocked == true),
            #remaining_reasons > 0 and table.concat(remaining_reasons, ",") or "none")
    end

    return true
end

local DONOR_PACKAGE_REFERENCE = "pusfume_globadier_material"
local WHISKER_DONOR_PACKAGE_REFERENCE = "pusfume_laurel_material"
local DONOR_TEXTURE_CHANNELS = {
    color = "texture_map_02af90f8",
    normal = "texture_map_27b67fd2",
    response = "texture_map_8bf37d8e",
}
local DONOR_MATERIAL_SLOTS = {
    "p_main",
    "p_eye",
    "p_metal",
    "p_glob",
    "p_armor",
    "p_eye_g",
    "p_ammo_box_limited_a",
    "p_ammo_box_limited_b",
}
local WHISKER_MATERIAL_SLOT = "p_whiskers"
local FUR_MATERIAL_SLOT = "p_fur"
local DONOR_ATLAS_TEXTURES = {
    color = "pusfume_atlas_df",
    normal = "pusfume_atlas_nm",
    response = "pusfume_atlas_s",
}

local MATERIAL_PROBE_MODES = {
    child = true,
    donor_atlas = true,
    donor_raw = true,
    split = true,
}

local LEGACY_PROBE_LINKS = {
    { source = "j_hips", target = "j_hips" },
    { source = "j_lefthand", target = "j_hand_L" },
}

local NATIVE_PROBE_LINKS = {
    { source = "j_hips", target = "j_hips" },
    { source = "j_lefthand", target = "j_lefthand" },
}

local function can_get(resource_type, path)
    return path and Application.can_get(resource_type, path)
end

local function ensure_donor_package(config)
    if not config.donor_material_enabled then
        return false
    end

    if state.donor_package_loaded then
        return true
    end

    if not Managers.package or not can_get("package", config.donor_package) then
        if not state.donor_package_error_logged then
            state.donor_package_error_logged = true
            mod:error("[pusfume] Globadier donor package is unavailable: %s", config.donor_package)
        end

        return false
    end

    if not state.donor_package_requested then
        state.donor_package_requested = true
        Managers.package:load(config.donor_package, DONOR_PACKAGE_REFERENCE)
        mod:info("[pusfume] Requested Globadier donor package: %s", config.donor_package)
    end

    state.donor_package_loaded = Managers.package:has_loaded(
        config.donor_package,
        DONOR_PACKAGE_REFERENCE)

    return state.donor_package_loaded
end

local function ensure_whisker_donor_package(config)
    if type(config.whisker_child_material) ~= "string" then
        return true
    end
    if type(config.whisker_donor_package) ~= "string" then
        -- Spliced builds embed the complete Laurel-derived child payload.
        -- There is no remaining runtime dependency on the original hat unit.
        state.whisker_donor_package_loaded = true
        return true
    end

    if state.whisker_donor_package_loaded then
        return true
    end

    if not Managers.package or not can_get("package", config.whisker_donor_package) then
        if not state.whisker_donor_package_error_logged then
            state.whisker_donor_package_error_logged = true
            mod:error("[pusfume] Laurel whisker donor package is unavailable: %s",
                tostring(config.whisker_donor_package))
        end

        return false
    end

    if not state.whisker_donor_package_requested then
        state.whisker_donor_package_requested = true
        Managers.package:load(config.whisker_donor_package, WHISKER_DONOR_PACKAGE_REFERENCE)
        mod:info("[pusfume] Requested Laurel whisker donor package: %s",
            config.whisker_donor_package)
    end

    state.whisker_donor_package_loaded = Managers.package:has_loaded(
        config.whisker_donor_package,
        WHISKER_DONOR_PACKAGE_REFERENCE)

    return state.whisker_donor_package_loaded
end

local function ensure_first_person_material_package(config)
    if type(config.first_person_material_package) ~= "string" then
        return false
    end

    if state.first_person_material_package_loaded then
        return true
    end

    if not ensure_donor_package(config) or not mod.load_package or not mod.package_status then
        if not state.first_person_material_package_error_logged then
            state.first_person_material_package_error_logged = true
            mod:error("[pusfume] First-person material package loader is unavailable: %s",
                tostring(config.first_person_material_package))
        end

        return false
    end

    if not state.first_person_material_package_requested then
        state.first_person_material_package_requested = true
        mod:load_package(config.first_person_material_package, nil, true)
        mod:info("[pusfume] Requested first-person material package: %s",
            config.first_person_material_package)
    end

    state.first_person_material_package_loaded =
        mod:package_status(config.first_person_material_package) == "loaded"

    return state.first_person_material_package_loaded
end

-- The compiled child material inherits the donor parent by hash, so its
-- package must only ever load AFTER the donor package is resident.
local function ensure_child_package(config)
    if not config.parent_child_package then
        return true
    end

    if state.child_package_loaded then
        return true
    end

    if not state.donor_package_loaded or not state.whisker_donor_package_loaded
            or not mod.load_package or not mod.package_status then
        return false
    end

    if not state.child_package_requested then
        state.child_package_requested = true
        mod:load_package(config.parent_child_package, nil, true)
        mod:info("[pusfume] Requested native child material package: %s", config.parent_child_package)
    end

    state.child_package_loaded = mod:package_status(config.parent_child_package) == "loaded"

    if not state.child_package_loaded and not state.child_package_error_logged then
        state.child_package_error_logged = true
        mod:error("[pusfume] Native child material package did not load through the mod handle: %s",
            config.parent_child_package)
    end

    return state.child_package_loaded
end

-- Texture resources are resolved by package load order. The startup package
-- deliberately excludes the atlas, then this mod-owned package registers the
-- atlas under the donor texture ids only AFTER the donor package is resident.
local function ensure_shadow_package(config)
    if not config.donor_texture_shadow then
        return true
    end

    if state.shadow_package_loaded then
        return true
    end

    if type(config.donor_texture_shadow_package) ~= "string"
            or not state.donor_package_loaded or not mod.load_package or not mod.package_status then
        return false
    end

    if not state.shadow_package_requested then
        state.shadow_package_requested = true
        mod:load_package(config.donor_texture_shadow_package, nil, true)
        mod:info("[pusfume] Requested late donor texture shadow package: %s",
            config.donor_texture_shadow_package)
    end

    state.shadow_package_loaded =
        mod:package_status(config.donor_texture_shadow_package) == "loaded"

    if not state.shadow_package_loaded and not state.shadow_package_error_logged then
        state.shadow_package_error_logged = true
        mod:error("[pusfume] Late donor texture shadow package did not load: %s",
            config.donor_texture_shadow_package)
    end

    return state.shadow_package_loaded
end


-- The texture channels are Fatshark's literal generated slot names (present in
-- the community hash dictionary as real strings). What failed in live testing
-- was the material INSTANCE lookup: name-keyed access resolved the orphaned
-- pre-swap materials, so texture sets landed on materials that no longer
-- render. Setting the channels on every material BY INDEX (the engine's own
-- flow-callback pattern) reaches the donor instances regardless of naming;
-- with every opaque slot on one shared atlas, identical values are harmless.
local function set_material_texture(material, channel, texture_name)
    local texture_path = "textures/pusfume/" .. texture_name

    if not can_get("texture", texture_path) then
        if not state.donor_texture_errors[texture_path] then
            state.donor_texture_errors[texture_path] = true
            mod:error("[pusfume] Donor material texture is unavailable: %s", texture_path)
        end

        return false
    end

    Material.set_texture(material, channel, texture_path)

    return true
end


local function apply_donor_material_to_unit(unit, config)
    -- Menu preview units live outside the gameplay ALIVE registry. Unit.alive
    -- is the shared validity check for both preview-world and gameplay units.
    if not config.donor_material_enabled or not unit or not Unit.alive(unit)
            or not ensure_donor_package(config)
            or not ensure_whisker_donor_package(config) then
        return false
    end

    if not ensure_shadow_package(config) then
        return false
    end

    state.material_probe_units[unit] = true

    if not can_get("material", config.donor_material) then
        if not state.donor_material_error_logged then
            state.donor_material_error_logged = true
            mod:error("[pusfume] Globadier donor material is unavailable: %s", config.donor_material)
        end

        return false
    end

    local material_slots = 0
    local texture_assignments = 0
    local mode = state.material_probe_mode
        or (config.parent_child_material and "child" or "donor_atlas")

    if mode == "child" or mode == "split" then
        if type(config.parent_child_material) ~= "string" then
            mod:error("[pusfume] Material probe mode %s requires a parent-child test build", mode)
            return false
        end
        if not ensure_child_package(config) then
            return false
        end

        if not can_get("material", config.parent_child_material) then
            if not state.donor_material_error_logged then
                state.donor_material_error_logged = true
                mod:error("[pusfume] Compiled child material is unavailable: %s",
                    config.parent_child_material)
            end

            return false
        end

        local assignments = {}

        for slot_index, slot_name in ipairs(DONOR_MATERIAL_SLOTS) do
            local material = mode == "split" and slot_index % 2 == 0
                    and config.donor_material
                or config.parent_child_material

            Unit.set_material(unit, slot_name, material)
            material_slots = material_slots + 1
            assignments[#assignments + 1] = string.format(
                "%s=%s", slot_name,
                material == config.donor_material and "donor" or "outfit")
        end

        if type(config.whisker_child_material) == "string" then
            if can_get("material", config.whisker_child_material) then
                Unit.set_material(unit, WHISKER_MATERIAL_SLOT, config.whisker_child_material)
                state.whisker_material_applied = true
                material_slots = material_slots + 1
                assignments[#assignments + 1] = WHISKER_MATERIAL_SLOT .. "=pusfume_whiskers_child"
            else
                state.whisker_material_applied = false
                mod:error("[pusfume] Native whisker child material is unavailable: %s",
                    config.whisker_child_material)
            end
        end

        if type(config.fur_child_material) == "string" then
            if can_get("material", config.fur_child_material) then
                Unit.set_material(unit, FUR_MATERIAL_SLOT, config.fur_child_material)
                state.fur_material_applied = true
                material_slots = material_slots + 1
                assignments[#assignments + 1] = FUR_MATERIAL_SLOT .. "=pusfume_fur_child"
            else
                state.fur_material_applied = false
                mod:error("[pusfume] Native fur child material is unavailable: %s",
                    config.fur_child_material)
            end
        end

        mod:info(
            "[pusfume] Material probe applied slots=%d textures=baked mode=%s material=%s assignments=%s",
            material_slots,
            mode,
            config.parent_child_material,
            table.concat(assignments, ","))

        return material_slots > 0
    end

    for _, slot_name in ipairs(DONOR_MATERIAL_SLOTS) do
        Unit.set_material(unit, slot_name, config.donor_material)
        material_slots = material_slots + 1
    end

    -- With donor texture shadowing the build renamed the atlas identities to
    -- the donor texture ids: the donor material already binds Janfon's maps,
    -- and the atlas resources no longer exist under their original paths, so
    -- the runtime restore must not run (it would only log resource errors -
    -- live testing proved these calls never rebind character materials anyway).
    if mode == "donor_atlas" and not config.donor_texture_shadow then
        for mesh_index = 0, Unit.num_meshes(unit) - 1 do
            local mesh = Unit.mesh(unit, mesh_index)

            for material_index = 0, Mesh.num_materials(mesh) - 1 do
                local material = Mesh.material(mesh, material_index)

                texture_assignments = texture_assignments +
                    (set_material_texture(material, DONOR_TEXTURE_CHANNELS.color,
                        DONOR_ATLAS_TEXTURES.color) and 1 or 0)
                texture_assignments = texture_assignments +
                    (set_material_texture(material, DONOR_TEXTURE_CHANNELS.normal,
                        DONOR_ATLAS_TEXTURES.normal) and 1 or 0)
                texture_assignments = texture_assignments +
                    (set_material_texture(material, DONOR_TEXTURE_CHANNELS.response,
                        DONOR_ATLAS_TEXTURES.response) and 1 or 0)
            end
        end
    end

    mod:info(
        "[pusfume] Material probe applied slots=%d textures=%d mode=%s shadow=%s material=%s",
        material_slots,
        texture_assignments,
        mode,
        tostring(config.donor_texture_shadow or false),
        config.donor_material)

    return material_slots > 0
end

local function install_material_probe_command(config)
    if state.material_probe_command_installed then
        return
    end

    mod:command("pusfume_material_probe",
        "Switch live Pusfume materials: donor_raw, donor_atlas, child, or split.",
        function(mode)
            mode = string.lower(tostring(mode or ""))

            if not MATERIAL_PROBE_MODES[mode] then
                mod:echo("Pusfume material probe modes: donor_raw, donor_atlas, child, split")
                return
            end

            state.material_probe_mode = mode

            local applied = 0

            for unit in pairs(state.material_probe_units) do
                if ALIVE[unit] and apply_donor_material_to_unit(unit, config) then
                    applied = applied + 1
                    local animation_states = { Unit.animation_get_state(unit) }

                    mod:info(
                        "[pusfume] Material probe unit mode=%s meshes=%d controller_state=%s bone_mode=%s",
                        mode,
                        Unit.num_meshes(unit),
                        tostring(animation_states[1]),
                        Unit.animation_bone_mode(unit))
                end
            end

            mod:echo("Pusfume material probe mode=%s live_units=%d", mode, applied)
            mod:info("[pusfume] Material probe switched mode=%s live_units=%d", mode, applied)
        end)

    -- The Globadier's rendered green is NOT in its diffuse (decoded: 60% red /
    -- 30% orange, 0.6% green) - the character shader applies a gradient tint.
    -- This is the engine's OWN runtime tint path (CosmeticUtils.color_tint_unit
    -- sets these exact scalars on live character materials), so unlike
    -- Material.set_texture it is expected to take effect. Sweep values live to
    -- find the variation that neutralizes the green over Janfon's maps.
    mod:command("pusfume_tint",
        "Set gradient tint on live Pusfume materials: <gradient_variation> [tint_columns_pair]",
        function(variation, columns_pair)
            variation = tonumber(variation)
            columns_pair = tonumber(columns_pair)

            if not variation then
                mod:echo("Usage: /pusfume_tint <gradient_variation> [tint_columns_pair]")
                return
            end

            local touched = 0

            for unit in pairs(state.material_probe_units) do
                if ALIVE[unit] then
                    for mesh_index = 0, Unit.num_meshes(unit) - 1 do
                        local mesh = Unit.mesh(unit, mesh_index)

                        for material_index = 0, Mesh.num_materials(mesh) - 1 do
                            local material = Mesh.material(mesh, material_index)

                            Material.set_scalar(material, "gradient_variation", variation)

                            if columns_pair then
                                Material.set_scalar(material, "tint_columns_pair", columns_pair)
                            end

                            touched = touched + 1
                        end
                    end
                end
            end

            mod:echo("Pusfume tint variation=%s columns_pair=%s materials=%d",
                tostring(variation), tostring(columns_pair), touched)
            mod:info("[pusfume] Tint probe variation=%s columns_pair=%s materials=%d",
                tostring(variation), tostring(columns_pair), touched)
        end)

    state.material_probe_command_installed = true
end

local function apply_donor_material(extension, config)
    if extension._pusfume_donor_material_applied or not config.donor_material_enabled then
        return extension._pusfume_donor_material_applied == true
    end

    local applied = apply_donor_material_to_unit(extension._tp_unit_mesh, config)

    extension._pusfume_donor_material_applied = applied
    state.donor_material_applied = state.donor_material_applied or applied

    return applied
end

-- Pusfume rides on Ranger Veteran's animated base, so Bardin's third-person
-- weapon units still spawn and attach. Wield flow events re-show them, so the
-- hide is re-asserted every update rather than set once.
local function hide_donor_weapons(extension, unit, config)
    if not config.hide_donor_weapons or not ALIVE[unit] then
        return
    end

    local inventory = ScriptUnit.has_extension(unit, "inventory_system")

    if not inventory or not inventory.equipment then
        return
    end

    local equipment = inventory:equipment()

    if not equipment then
        return
    end

    local wielded_units = {
        equipment.right_hand_wielded_unit_3p,
        equipment.left_hand_wielded_unit_3p,
        equipment.right_hand_ammo_unit_3p,
        equipment.left_hand_ammo_unit_3p,
    }

    for i = 1, #wielded_units do
        local weapon_unit = wielded_units[i]

        if weapon_unit and ALIVE[weapon_unit] then
            Unit.set_unit_visibility(weapon_unit, false)
        end
    end

    local slots = equipment.slots

    if slots then
        for _, slot_data in pairs(slots) do
            if type(slot_data) == "table" then
                local slot_units = {
                    slot_data.right_unit_3p,
                    slot_data.left_unit_3p,
                    slot_data.right_ammo_unit_3p,
                    slot_data.left_ammo_unit_3p,
                }

                for i = 1, #slot_units do
                    local slot_unit = slot_units[i]

                    if slot_unit and ALIVE[slot_unit] then
                        Unit.set_unit_visibility(slot_unit, false)
                    end
                end
            end
        end
    end

    if not state.donor_weapons_hidden then
        state.donor_weapons_hidden = true
        mod:info("[pusfume] Donor third-person weapon units hidden")
    end
end

local function clear_linked_particle_metadata(world, unit)
    if not unit or not Unit.alive(unit) then
        return false
    end

    local has_particles = Unit.has_data(unit, "particles")
    local has_linked_particle = Unit.has_data(unit, "has_linked_particles")
    local particle_id = has_linked_particle
        and Unit.get_data(unit, "has_linked_particles")

    if particle_id and world then
        pcall(World.destroy_particles, world, particle_id)
    end
    if has_particles then
        Unit.set_data(unit, "particles", "node_part_pairs", 0)
    end
    Unit.set_data(unit, "has_linked_particles", nil)
    Unit.set_data(unit, "inactive_particles", false)

    return has_particles or has_linked_particle
end

local function suppress_inherited_equipment_particles(extension, unit)
    if not ALIVE[unit] or not extension.world then
        return
    end

    local inventory = ScriptUnit.has_extension(unit, "inventory_system")
    local equipment = inventory and inventory:equipment()
    local slots = equipment and equipment.slots

    if not slots then
        return
    end

    local suppressed = 0
    for _, slot_data in pairs(slots) do
        if type(slot_data) == "table" then
            for _, weapon_unit in pairs({
                    slot_data.right_unit_1p,
                    slot_data.left_unit_1p,
                    slot_data.right_unit_3p,
                    slot_data.left_unit_3p,
                    slot_data.right_ammo_unit_1p,
                    slot_data.left_ammo_unit_1p,
                    slot_data.right_ammo_unit_3p,
                    slot_data.left_ammo_unit_3p,
                }) do
                if weapon_unit and Unit.alive(weapon_unit)
                        and not state.particle_suppressed_units[weapon_unit]
                        and (Unit.has_data(weapon_unit, "particles")
                            or Unit.has_data(weapon_unit, "has_linked_particles")) then
                    -- Material-Hijack reads this native Versus metadata whenever
                    -- equipment spawns or visibility returns. Clear the source
                    -- count as well as the already-linked particle so it cannot
                    -- recreate the Globadier/Warpfire idle glow.
                    clear_linked_particle_metadata(extension.world, weapon_unit)
                    state.particle_suppressed_units[weapon_unit] = true
                    suppressed = suppressed + 1
                end
            end
        end
    end

    if suppressed > 0 then
        mod:info(
            "[pusfume] Suppressed inherited Versus equipment particles units=%d",
            suppressed)
    end
end

local function hide_assassin_third_person_weapons(unit)
    if not ALIVE[unit] then
        return
    end

    local inventory = ScriptUnit.has_extension(unit, "inventory_system")
    local item_template = inventory
        and type(inventory.get_wielded_slot_item_template) == "function"
        and inventory:get_wielded_slot_item_template()

    if not item_template or item_template.pusfume_role_pose ~= "to_gutter_runner" then
        return
    end

    local equipment = inventory:equipment()
    local hidden = 0
    for _, weapon_unit in pairs({
            equipment.right_hand_wielded_unit_3p,
            equipment.left_hand_wielded_unit_3p,
        }) do
        if weapon_unit and ALIVE[weapon_unit] then
            Unit.set_unit_visibility(weapon_unit, false)
            hidden = hidden + 1
        end
    end

    if hidden > 0 and not inventory._pusfume_assassin_3p_hands_only_logged then
        inventory._pusfume_assassin_3p_hands_only_logged = true
        mod:info(
            "[pusfume] Assassin third-person claw geometry hidden; Janfon hand animation remains active")
    end
end

local function articulation_vector(unit, hips_node, hand_node)
    if not Unit.has_node(unit, hips_node) or not Unit.has_node(unit, hand_node) then
        return nil
    end

    local hips_position = Unit.world_position(unit, Unit.node(unit, hips_node))
    local hand_position = Unit.world_position(unit, Unit.node(unit, hand_node))

    return hand_position - hips_position
end

local function apply_manual_skin_probe(extension, t)
    local probe = extension._pusfume_native_probe

    if not probe or not probe.manual_skin_probe or not ALIVE[probe.mesh] then
        return
    end

    probe.manual_started_at = probe.manual_started_at or t

    local elapsed = t - probe.manual_started_at
    local angle = math.sin(elapsed * math.pi) * 0.65
    local rotation_offset = Quaternion.axis_angle(Vector3.forward(), angle)
    local rotation = Quaternion.multiply(probe.manual_base_rotation:unbox(), rotation_offset)

    Unit.set_local_rotation(probe.mesh, probe.manual_node, rotation)

    probe.manual_angle = angle
end

local function apply_manual_clip_probe(extension, t)
    local probe = extension._pusfume_native_probe

    if not probe or not probe.manual_clip_id or not ALIVE[probe.mesh] then
        return
    end

    probe.manual_clip_started_at = probe.manual_clip_started_at or t
    probe.manual_clip_time = (t - probe.manual_clip_started_at) % probe.manual_clip_length

    Unit.crossfade_animation_set_time(
        probe.mesh,
        probe.manual_clip_id,
        probe.manual_clip_time,
        true)
end

local function sample_link_probe(extension, unit, t)
    local probe = extension._pusfume_native_probe

    if not probe or probe.complete or not ALIVE[unit] or not ALIVE[probe.mesh] then
        return
    end

    probe.started_at = probe.started_at or t

    local elapsed = t - probe.started_at

    if elapsed < probe.next_sample_at then
        return
    end

    local details = {}
    if probe.manual_clip_id then
        details[#details + 1] = string.format(
            "manual_clip_id=%s manual_clip_time=%.4f/%.4f crossfading=%s bone_mode=%s",
            tostring(probe.manual_clip_id),
            probe.manual_clip_time or 0,
            probe.manual_clip_length,
            tostring(Unit.is_crossfading_animation(probe.mesh)),
            Unit.animation_bone_mode(probe.mesh))
    else
        local animation_states = { Unit.animation_get_state(probe.mesh) }

        details[#details + 1] = string.format(
            "controller_state=%s bone_mode=%s",
            tostring(animation_states[1]),
            Unit.animation_bone_mode(probe.mesh))
    end

    for _, link in ipairs(probe.links) do
        local source_position = Unit.world_position(unit, Unit.node(unit, link.source))
        local target_position = Unit.world_position(probe.mesh, Unit.node(probe.mesh, link.target))
        local initial = probe.initial[link.source]

        details[#details + 1] = string.format(
            "%s source_motion=%.4f target_motion=%.4f link_error=%.4f",
            link.source,
            Vector3.distance(source_position, initial.source:unbox()),
            Vector3.distance(target_position, initial.target:unbox()),
            Vector3.distance(source_position, target_position))
    end

    local source_articulation = articulation_vector(unit, "j_hips", "j_lefthand")
    local target_articulation = articulation_vector(probe.mesh, "j_hips", probe.target_hand)

    if source_articulation and target_articulation
            and probe.initial_source_articulation and probe.initial_target_articulation then
        details[#details + 1] = string.format(
            "articulation source_delta=%.4f target_delta=%.4f manual_angle=%.4f",
            Vector3.distance(source_articulation, probe.initial_source_articulation:unbox()),
            Vector3.distance(target_articulation, probe.initial_target_articulation:unbox()),
            probe.manual_angle or 0)
    else
        details[#details + 1] = "articulation=unavailable"
    end

    probe.samples = probe.samples + 1
    probe.next_sample_at = probe.samples == 1 and 2 or 5
    probe.complete = probe.samples >= 3

    mod:info("[pusfume] Native animation probe t=%.1f %s", elapsed, table.concat(details, "; "))
end

local function initialize_link_probe(extension, unit, config)
    local mesh = extension._tp_unit_mesh

    if not mesh then
        return
    end

    extension._pusfume_native_config = config
    apply_donor_material(extension, config)

    -- Versus Pactsworn profiles drive their rat vocalizations through the
    -- character_vo flow switch. Apply it to this Pusfume unit only; mutating
    -- the shared dwarf profile would also change every Bardin career.
    apply_pusfume_voice_switch(unit)

    if not extension._pusfume_voice_switch_logged then
        extension._pusfume_voice_switch_logged = true
        mod:info("[pusfume] Playable Globadier vocal switch applied: %s", PUSFUME_CHARACTER_VO)
    end

    local has_state_machine = Unit.has_animation_state_machine(mesh)
    local has_enable_event = has_state_machine and Unit.has_animation_event(mesh, "enable")
    local initial_bone_mode = Unit.animation_bone_mode(mesh)

    Unit.set_animation_bone_mode(mesh, "transform")
    Unit.set_bones_lod(mesh, 0)

    if has_state_machine then
        Unit.enable_animation_state_machine(mesh)

        if has_enable_event then
            Unit.animation_event(mesh, "enable")
        end
    end

    mod:info(
        "[pusfume] Native animation controller state_machine=%s enable_event=%s bone_mode=%s->%s",
        tostring(has_state_machine),
        tostring(has_enable_event),
        tostring(initial_bone_mode),
        tostring(Unit.animation_bone_mode(mesh)))

    local requested_links = config.root_animation_isolation
            and NATIVE_PROBE_LINKS
        or LEGACY_PROBE_LINKS
    local links = {}
    local initial = {}

    for _, link in ipairs(requested_links) do
        if Unit.has_node(unit, link.source) and Unit.has_node(mesh, link.target) then
            links[#links + 1] = link
            initial[link.source] = {
                source = Vector3Box(Unit.world_position(unit, Unit.node(unit, link.source))),
                target = Vector3Box(Unit.world_position(mesh, Unit.node(mesh, link.target))),
            }
        else
            mod:warning(
                "[pusfume] Native animation probe skipped unavailable node pair %s->%s",
                link.source,
                link.target)
        end
    end

    local target_hand = config.root_animation_isolation and "j_lefthand" or "j_hand_L"
    local initial_source_articulation = articulation_vector(unit, "j_hips", "j_lefthand")
    local initial_target_articulation = articulation_vector(mesh, "j_hips", target_hand)

    local probe = {
        complete = false,
        initial = initial,
        initial_source_articulation = initial_source_articulation
            and Vector3Box(initial_source_articulation),
        initial_target_articulation = initial_target_articulation
            and Vector3Box(initial_target_articulation),
        links = links,
        mesh = mesh,
        next_sample_at = 0.5,
        samples = 0,
        target_hand = target_hand,
    }

    if config.manual_clip_probe then
        Unit.disable_animation_state_machine(mesh)

        probe.manual_clip_length = config.manual_clip_length
        probe.manual_clip_id = Unit.crossfade_animation(mesh, config.manual_clip_name, 1, 0, true, "normal")

        Unit.crossfade_animation_set_speed(mesh, probe.manual_clip_id, 0)
        mod:warning(
            "[pusfume] Manual animation blender probe active clip=%s id=%s length=%.4f",
            config.manual_clip_name,
            tostring(probe.manual_clip_id),
            probe.manual_clip_length)
    elseif config.manual_skin_probe then
        if Unit.has_node(mesh, "j_spine1") then
            probe.manual_skin_probe = true
            probe.manual_node = Unit.node(mesh, "j_spine1")
            probe.manual_base_rotation = QuaternionBox(Unit.local_rotation(mesh, probe.manual_node))
            Unit.disable_animation_state_machine(mesh)
            mod:warning("[pusfume] Manual skin deformation probe is active on j_spine1")
        else
            mod:warning("[pusfume] Manual skin deformation probe skipped: j_spine1 is unavailable")
        end
    elseif config.locomotion_events_enabled and has_state_machine then
        probe.locomotion_events = Unit.has_animation_event(mesh, "walk")
            and Unit.has_animation_event(mesh, "idle")
        state.locomotion_events_available = probe.locomotion_events == true

        if probe.locomotion_events then
            probe.locomotion_state = "idle"
            -- Enter the idle state explicitly instead of trusting default-state
            -- auto-entry; the 05:45 session showed controller_state=0 with no
            -- visible idle while event-driven walk transitions worked.
            Unit.animation_event(mesh, "idle")
            mod:info("[pusfume] Locomotion animation events active (idle/walk)")
        else
            mod:warning("[pusfume] Compiled controller is missing idle/walk events")
        end
    end

    extension._pusfume_native_probe = probe
end

local function drive_locomotion_events(extension, unit, dt)
    local probe = extension._pusfume_native_probe

    if not probe or not probe.locomotion_events or not ALIVE[unit] or not ALIVE[probe.mesh] then
        return
    end

    local position = Unit.world_position(unit, 0)

    if not probe.last_position then
        probe.last_position = Vector3Box(position)

        return
    end

    if dt and dt > 0 then
        local horizontal_delta = Vector3.flat(position - probe.last_position:unbox())
        local speed = Vector3.length(horizontal_delta) / dt

        if probe.locomotion_state ~= "walk" and speed > WALK_ENTER_SPEED then
            probe.locomotion_state = "walk"
            Unit.animation_event(probe.mesh, "walk")
        elseif probe.locomotion_state ~= "idle" and speed < IDLE_ENTER_SPEED then
            probe.locomotion_state = "idle"
            Unit.animation_event(probe.mesh, "idle")
        end
    end

    probe.last_position:store(position)
end

local function deep_clone(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local clone = {}
    seen[value] = clone

    for key, nested_value in pairs(value) do
        clone[deep_clone(key, seen)] = deep_clone(nested_value, seen)
    end

    return setmetatable(clone, getmetatable(value))
end

local function register_cosmetic(registry, config)
    if not config.enabled then
        return false
    end

    state.resource_available = Application.can_get("unit", config.third_person_unit)

    if not state.resource_available then
        mod:error("[pusfume] Native build enabled but unit is unavailable: %s", config.third_person_unit)
        return false
    end

    local native_skaven_packages_ready =
        (config.native_skaven_first_person or config.dual_first_person_rigs)
        and ensure_native_skaven_first_person_packages(config)
    local native_skaven_ready = config.native_skaven_first_person
        and native_skaven_packages_ready
    state.dual_first_person_rigs_ready = config.dual_first_person_rigs == true
        and native_skaven_packages_ready
        and (config.native_versus_first_person == true
            or type(config.versus_first_person_unit) == "string"
                and Application.can_get("unit", config.versus_first_person_unit))
    local first_person_unit = native_skaven_ready
            and PACKMASTER_FIRST_PERSON_ARMS
        or config.first_person_unit
    if first_person_unit then
        state.first_person_resource_available = Application.can_get("unit", first_person_unit)

        if not state.first_person_resource_available then
            mod:error("[pusfume] First-person build enabled but unit is unavailable: %s", first_person_unit)
            return false
        end
    end

    local donor_career = CareerSettings[registry.DONOR_CAREER_NAME]
    local donor_skin = donor_career and Cosmetics[donor_career.base_skin]

    if not donor_skin then
        mod:error("[pusfume] Native build could not resolve the Ranger Veteran base skin")
        return false
    end

    local skin = deep_clone(donor_skin)

    skin.career = registry.find_career_index() or 5
    skin.always_hide_attachment_slots = { "slot_hat" }
    skin.equip_hat_event = nil
    skin.material_changes = nil
    if native_skaven_ready then
        skin.first_person = SKAVEN_FIRST_PERSON_BASE
        skin.first_person_bot = SKAVEN_FIRST_PERSON_BOT_BASE
    end
    state.native_skaven_skin_registered = native_skaven_ready == true
    local attachment_node_linking = config.root_animation_isolation
            and AttachmentNodeLinking.pusfume_root_animation_attachment
        or AttachmentNodeLinking.pusfume_third_person_attachment

    skin.third_person_attachment = {
        unit = config.third_person_unit,
        attachment_node_linking = attachment_node_linking,
    }
    if first_person_unit then
        local first_person_linking = native_skaven_ready
                and AttachmentNodeLinking.skaven_first_person_attachment
            or config.first_person_direct_link
                and AttachmentNodeLinking.first_person_attachment
            or AttachmentNodeLinking.pusfume_first_person_attachment
        skin.first_person_attachment = {
            unit = first_person_unit,
            attachment_node_linking = first_person_linking,
        }
    end
    Cosmetics[config.skin_name] = skin
    state.native_skin_name = config.skin_name
    registry.set_native_skin(config.skin_name)
    state.cosmetic_registered = true

    mod:info("[pusfume] Native third-person cosmetic registered: %s", config.third_person_unit)
    if first_person_unit then
        mod:info("[pusfume] Native first-person cosmetic registered: %s", first_person_unit)
        if native_skaven_ready then
            mod:info("[pusfume] Native Skaven first-person base active: %s", SKAVEN_FIRST_PERSON_BASE)
        elseif config.native_skaven_first_person then
            mod:warning("[pusfume] Native Skaven first-person unavailable; using bundled arms fallback")
        end
    end

    if config.root_animation_isolation then
        mod:warning("[pusfume] Root-only animation isolation is active")
    end

    return true
end

local function apply_first_person_materials(extension, config)
    if state.native_skaven_skin_registered then
        extension._pusfume_first_person_materials_applied = true
        state.first_person_materials_applied = true
        return true
    end

    if extension._pusfume_first_person_materials_applied then
        return true
    end

    local hero_unit = extension._pusfume_hero_first_person_attachment
        or extension.first_person_attachment_unit
    local materials = config.first_person_materials
    if type(materials) ~= "table" or not hero_unit or not Unit.alive(hero_unit)
            or not ensure_first_person_material_package(config) then
        return false
    end

    for slot_name, material_name in pairs(materials) do
        if not can_get("material", material_name) then
            if not state.first_person_material_error_logged then
                state.first_person_material_error_logged = true
                mod:error("[pusfume] First-person material is unavailable: %s", material_name)
            end

            return false
        end

        Unit.set_material(hero_unit, slot_name, material_name)
    end

    local skaven_material = config.first_person_skaven_material
    local skaven_attachments = extension._pusfume_skaven_first_person_attachments
    if type(skaven_material) == "string" and skaven_attachments then
        if not can_get("material", skaven_material) then
            if not state.first_person_material_error_logged then
                state.first_person_material_error_logged = true
                mod:error("[pusfume] Skaven first-person material is unavailable: %s",
                    skaven_material)
            end

            return false
        end

        for _, skaven_unit in pairs(skaven_attachments) do
            if skaven_unit and Unit.alive(skaven_unit) then
                Unit.set_material(skaven_unit, "p_main", skaven_material)
            end
        end
    end

    extension._pusfume_first_person_materials_applied = true
    state.first_person_materials_applied = true
    mod:info("[pusfume] Janfon first-person materials applied: human=%s skaven=%s",
        tostring(materials.p_main), tostring(skaven_material))

    return true
end

local first_person_probe_nodes = {
    { source = "j_spine2", target = "j_spine2" },
    { source = "j_leftarm", target = "j_leftarm" },
    { source = "j_lefthand", target = "j_lefthand" },
    { source = "j_rightarm", target = "j_rightarm" },
    { source = "j_righthand", target = "j_righthand" },
}

local function initialize_first_person_retarget(extension, source_rest_unit_name)
    if extension._pusfume_first_person_retarget then
        return true
    end

    local source = extension._pusfume_hero_first_person_unit
        or extension.first_person_unit
    local target = extension._pusfume_hero_first_person_attachment
        or extension.first_person_attachment_unit
    local pairs = AttachmentNodeLinking.pusfume_first_person_retarget_pairs
    local unit_spawner = Managers.state.unit_spawner

    if not source or not target or not Unit.alive(source) or not Unit.alive(target)
            or type(source_rest_unit_name) ~= "string" or type(pairs) ~= "table"
            or not unit_spawner then
        return false
    end

    -- A copy without an animation state machine exposes the donor's pristine
    -- local bind transforms. The live target has no controller, so its current
    -- local transforms are Janfon's authored bind pose.
    local rest_source = unit_spawner:spawn_local_unit(source_rest_unit_name)
    local retarget_pairs = {}
    local source_anchor_nodes = {}
    local target_anchor_nodes = {}
    local target_limb_root_nodes = {}
    local target_spine_node

    for _, pair in ipairs(pairs) do
        local source_node = Unit.node(rest_source, pair.source)
        local target_node = Unit.node(target, pair.target)

        retarget_pairs[#retarget_pairs + 1] = {
            source = pair.source,
            target = pair.target,
            source_node = source_node,
            target_node = target_node,
            source_rest = Matrix4x4Box(Unit.local_pose(rest_source, source_node)),
            target_rest = Matrix4x4Box(Unit.local_pose(target, target_node)),
        }

        if pair.source == "j_lefthand" or pair.source == "j_righthand" then
            source_anchor_nodes[#source_anchor_nodes + 1] = source_node
            target_anchor_nodes[#target_anchor_nodes + 1] = target_node
        end
        if pair.target == "j_spine1" then
            target_spine_node = target_node
        elseif pair.target == "j_leftarm" then
            target_limb_root_nodes[1] = target_node
        elseif pair.target == "j_rightarm" then
            target_limb_root_nodes[2] = target_node
        end
    end

    unit_spawner:mark_for_deletion(rest_source)

    local source_lod_count = Unit.num_lod_objects(source)
    local target_lod_count = Unit.num_lod_objects(target)
    local bounds_copied = false
    if source_lod_count > 0 and target_lod_count > 0 then
        local source_lod = Unit.lod_object(source, 0)
        local target_lod = Unit.lod_object(target, 0)

        LODObject.set_bounding_volume(target_lod, LODObject.bounding_volume(source_lod))
        bounds_copied = true
    end

    extension._pusfume_first_person_retarget = {
        pairs = retarget_pairs,
        bounds_copied = bounds_copied,
        source_lod_count = source_lod_count,
        target_lod_count = target_lod_count,
        source_anchor_nodes = source_anchor_nodes,
        target_anchor_nodes = target_anchor_nodes,
        target_limb_root_nodes = target_limb_root_nodes,
        target_limb_parent_nodes = {
            Unit.scene_graph_parent(target, target_limb_root_nodes[1]),
            Unit.scene_graph_parent(target, target_limb_root_nodes[2]),
        },
        target_spine_node = target_spine_node,
        target_spine_parent_node = target_spine_node
            and Unit.scene_graph_parent(target, target_spine_node),
        anchor_correction = Vector3Box(Vector3.zero()),
        anchor_error = 0,
        limb_corrections = {
            Vector3Box(Vector3.zero()),
            Vector3Box(Vector3.zero()),
        },
        limb_errors = { 0, 0 },
        limb_residuals = { 0, 0 },
        invalid_pose_logged = false,
    }
    state.first_person_retarget_initialized = true
    state.first_person_bounds_copied = bounds_copied
    mod:info(
        "[pusfume] First-person rest retarget initialized pairs=%d bounds_copied=%s lods=%d/%d anchors=%d limbs=%d",
        #retarget_pairs,
        tostring(bounds_copied),
        source_lod_count,
        target_lod_count,
        #source_anchor_nodes,
        #target_limb_root_nodes)

    return true
end

local function update_first_person_retarget(extension)
    local retarget = extension._pusfume_first_person_retarget
    -- Always update Janfon's human attachment, even when the default
    -- Packmaster weapon has made the separate Skaven rig active.
    local source = extension._pusfume_hero_first_person_unit
        or extension.first_person_unit
    local target = extension._pusfume_hero_first_person_attachment
        or extension.first_person_attachment_unit

    if not retarget or not source or not target or not Unit.alive(source) or not Unit.alive(target) then
        return
    end

    -- World transforms resolve after the update. Measure the preceding frame's
    -- completed correction before replacing local poses for this frame.
    if retarget.correction_applied then
        for index = 1, 2 do
            retarget.limb_residuals[index] = Vector3.distance(
                Unit.world_position(source, retarget.source_anchor_nodes[index]),
                Unit.world_position(target, retarget.target_anchor_nodes[index]))
        end
    end

    for _, pair in ipairs(retarget.pairs) do
        local source_pose = Unit.local_pose(source, pair.source_node)
        local source_rest = pair.source_rest:unbox()
        local target_rest = pair.target_rest:unbox()
        local animation_delta = Matrix4x4.multiply(source_pose, Matrix4x4.inverse(source_rest))
        local target_pose = Matrix4x4.multiply(animation_delta, target_rest)

        -- VT2's 1P clips are rotational. Preserve Janfon's local offsets so a
        -- donor translation cannot change his bone lengths or collapse hands.
        Matrix4x4.set_translation(target_pose, Matrix4x4.translation(target_rest))

        if Matrix4x4.is_valid(target_pose) then
            Unit.set_local_pose(target, pair.target_node, target_pose)
        elseif not retarget.invalid_pose_logged then
            retarget.invalid_pose_logged = true
            mod:error(
                "[pusfume] First-person retarget rejected invalid pose %s->%s",
                pair.source,
                pair.target)
        end
    end

    local midpoint_correction = Vector3.zero()
    if #retarget.source_anchor_nodes == 2 and #retarget.target_anchor_nodes == 2
            and retarget.target_spine_node and retarget.target_spine_parent_node then
        local source_anchor = (
            Unit.world_position(source, retarget.source_anchor_nodes[1])
            + Unit.world_position(source, retarget.source_anchor_nodes[2])) * 0.5
        local target_anchor = (
            Unit.world_position(target, retarget.target_anchor_nodes[1])
            + Unit.world_position(target, retarget.target_anchor_nodes[2])) * 0.5
        local correction = source_anchor - target_anchor
        local spine_world_pose = Unit.world_pose(target, retarget.target_spine_node)

        Matrix4x4.set_translation(
            spine_world_pose,
            Matrix4x4.translation(spine_world_pose) + correction)

        local parent_world_pose = Unit.world_pose(target, retarget.target_spine_parent_node)
        local spine_local_pose = Matrix4x4.multiply(
            spine_world_pose,
            Matrix4x4.inverse(parent_world_pose))

        if Matrix4x4.is_valid(spine_local_pose) then
            Unit.set_local_pose(target, retarget.target_spine_node, spine_local_pose)
            retarget.anchor_correction:store(correction)
            retarget.anchor_error = Vector3.length(correction)
            midpoint_correction = correction
        elseif not retarget.invalid_pose_logged then
            retarget.invalid_pose_logged = true
            mod:error("[pusfume] First-person camera-anchor correction produced an invalid pose")
        end
    end

    if #retarget.source_anchor_nodes == 2 and #retarget.target_anchor_nodes == 2
            and #retarget.target_limb_root_nodes == 2
            and #retarget.target_limb_parent_nodes == 2 then
        for index = 1, 2 do
            local hand_error = Unit.world_position(source, retarget.source_anchor_nodes[index])
                - Unit.world_position(target, retarget.target_anchor_nodes[index])
            -- The arm parent inherits the spine's midpoint translation. Apply
            -- only the remaining side-specific error at the limb root.
            local correction = hand_error - midpoint_correction
            local limb_world_pose = Unit.world_pose(target, retarget.target_limb_root_nodes[index])

            Matrix4x4.set_translation(
                limb_world_pose,
                Matrix4x4.translation(limb_world_pose) + correction)

            local parent_world_pose = Unit.world_pose(
                target,
                retarget.target_limb_parent_nodes[index])
            local limb_local_pose = Matrix4x4.multiply(
                limb_world_pose,
                Matrix4x4.inverse(parent_world_pose))

            if Matrix4x4.is_valid(limb_local_pose) then
                Unit.set_local_pose(
                    target,
                    retarget.target_limb_root_nodes[index],
                    limb_local_pose)
                retarget.limb_corrections[index]:store(correction)
                retarget.limb_errors[index] = Vector3.length(hand_error)
            elseif not retarget.invalid_pose_logged then
                retarget.invalid_pose_logged = true
                mod:error(
                    "[pusfume] First-person %s arm-anchor correction produced an invalid pose",
                    index == 1 and "left" or "right")
            end
        end
        retarget.correction_applied = true
    end
end

local function log_first_person_attachment_probe(extension)
    if extension._pusfume_first_person_probe_logged then
        return
    end

    -- Keep the diagnostic stable while a Versus weapon activates its own rig.
    local source = extension._pusfume_hero_first_person_unit
        or extension.first_person_unit
    local target = extension._pusfume_hero_first_person_attachment
        or extension.first_person_attachment_unit
    if not source or not target or not Unit.alive(source) or not Unit.alive(target) then
        return
    end

    local node_distances = {}
    for _, node_pair in ipairs(first_person_probe_nodes) do
        if Unit.has_node(source, node_pair.source)
                and Unit.has_node(target, node_pair.target) then
            local source_node = Unit.node(source, node_pair.source)
            local target_node = Unit.node(target, node_pair.target)
            local source_position = Unit.world_position(source, source_node)
            local target_position = Unit.world_position(target, target_node)

            node_distances[#node_distances + 1] = string.format(
                "%s->%s=%.4f", node_pair.source, node_pair.target,
                Vector3.distance(source_position, target_position))
        else
            node_distances[#node_distances + 1] = string.format(
                "%s->%s=unavailable", node_pair.source, node_pair.target)
        end
    end

    extension._pusfume_first_person_probe_logged = true
    mod:info(
        "[pusfume] First-person attachment probe meshes=%d mode=%s shown=%s active_rig=%s direct=%s retarget=%s bounds=%s lods=%s/%s anchor_error=%.4f anchor_delta=%s limb_error=%.4f/%.4f limb_residual=%.4f/%.4f limb_delta=%s/%s root=%s scale=%s node_distance(%s)",
        Unit.num_meshes(target),
        tostring(extension.first_person_mode),
        tostring(extension._show_first_person_units),
        tostring(extension._pusfume_active_first_person_rig),
        tostring(installed_config and installed_config.first_person_direct_link == true),
        tostring(extension._pusfume_first_person_retarget ~= nil),
        tostring(extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.bounds_copied),
        tostring(extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.source_lod_count),
        tostring(extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.target_lod_count),
        extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.anchor_error or 0,
        tostring(extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.anchor_correction:unbox()),
        extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.limb_errors[1] or 0,
        extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.limb_errors[2] or 0,
        extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.limb_residuals[1] or 0,
        extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.limb_residuals[2] or 0,
        tostring(extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.limb_corrections[1]:unbox()),
        tostring(extension._pusfume_first_person_retarget
            and extension._pusfume_first_person_retarget.limb_corrections[2]:unbox()),
        tostring(Unit.local_position(target, 0)),
        tostring(Unit.local_scale(target, 0)),
        table.concat(node_distances, ","))
end

local function skip_missing_first_person_event(extension, first_person_unit, event)
    if not extension or not extension._pusfume_first_person
            or type(event) ~= "string"
            or not first_person_unit or not Unit.alive(first_person_unit) then
        return false
    end

    local active_animation_unit = extension._pusfume_active_animation_unit
    local first_person_has_event = unit_has_animation_event(first_person_unit, event)
    local active_has_event = not active_animation_unit
        or not Unit.alive(active_animation_unit)
        or active_animation_unit == first_person_unit
        or unit_has_animation_event(active_animation_unit, event)

    if first_person_has_event and active_has_event then
        return false
    end

    extension._pusfume_skipped_anim_events =
        extension._pusfume_skipped_anim_events or {}
    if not extension._pusfume_skipped_anim_events[event] then
        extension._pusfume_skipped_anim_events[event] = true
        mod:info(
            "[pusfume] Skipped 1P animation event missing on active rig: %s base=%s active=%s",
            tostring(event), tostring(first_person_has_event), tostring(active_has_event))
    end

    return true
end

local function set_unit_visible(unit, visible)
    if unit and Unit.alive(unit) then
        Unit.set_unit_visibility(unit, visible)
    end
end

local function link_shared_first_person_nodes(world, source, target,
        node_linking, label)
    if not source or not Unit.alive(source)
            or not target or not Unit.alive(target) then
        mod:error("[pusfume] First-person guarded link has dead unit label=%s",
            tostring(label))
        return false
    end

    -- AttachmentUtils.link can be wrapped by other mods with an all-or-nothing
    -- missing-node guard. Janfon intentionally omits unused fingertip nodes,
    -- so link each shared pair through Stingray's primitive instead.
    World.unlink_unit(world, target)

    local linked = 0
    local skipped = 0
    local skipped_names = {}

    for _, link_data in ipairs(node_linking) do
        local source_node = link_data.source
        local target_node = link_data.target
        local source_exists = type(source_node) ~= "string"
            or Unit.has_node(source, source_node)
        local target_exists = type(target_node) ~= "string"
            or Unit.has_node(target, target_node)

        if source_exists and target_exists then
            local source_index = type(source_node) == "string"
                and Unit.node(source, source_node)
                or source_node
            local target_index = type(target_node) == "string"
                and Unit.node(target, target_node)
                or target_node

            World.link_unit(world, target, target_index, source, source_index)
            linked = linked + 1
        else
            skipped = skipped + 1
            if #skipped_names < 8 then
                skipped_names[#skipped_names + 1] = string.format(
                    "%s->%s", tostring(source_node), tostring(target_node))
            end
        end
    end

    mod:info(
        "[pusfume] First-person guarded links label=%s linked=%d skipped=%d nodes=%s",
        tostring(label), linked, skipped, table.concat(skipped_names, ","))

    return linked > 0
end

local function spawn_dual_first_person_rig(extension, config)
    if not state.dual_first_person_rigs_ready
            or extension._pusfume_skaven_first_person_unit then
        return state.dual_first_person_rigs_ready
    end

    local unit_spawner = Managers.state.unit_spawner
    if not unit_spawner then
        return false
    end

    local skaven_base = unit_spawner:spawn_local_unit(SKAVEN_FIRST_PERSON_BASE)
    local skaven_attachments = {}

    if config.native_versus_first_person then
        for role, unit_name in pairs(SKAVEN_FIRST_PERSON_ARMS) do
            local arms = unit_spawner:spawn_local_unit(unit_name)
            local linked = link_shared_first_person_nodes(
                extension.world,
                skaven_base,
                arms,
                AttachmentNodeLinking.skaven_first_person_attachment,
                "Fatshark-native-" .. role)
            if not linked then
                for _, spawned_arms in pairs(skaven_attachments) do
                    unit_spawner:mark_for_deletion(spawned_arms)
                end
                unit_spawner:mark_for_deletion(arms)
                unit_spawner:mark_for_deletion(skaven_base)
                return false
            end

            set_unit_visible(arms, false)
            apply_pusfume_voice_switch(arms)
            skaven_attachments[role] = arms
        end
    else
        local arms = unit_spawner:spawn_local_unit(config.versus_first_person_unit)
        local linked = link_shared_first_person_nodes(
            extension.world,
            skaven_base,
            arms,
            AttachmentNodeLinking.skaven_first_person_attachment,
            "Janfon-99-skaven")
        if not linked then
            unit_spawner:mark_for_deletion(arms)
            unit_spawner:mark_for_deletion(skaven_base)
            return false
        end

        set_unit_visible(arms, false)
        apply_pusfume_voice_switch(arms)
        skaven_attachments.packmaster = arms
    end

    local skaven_arms = skaven_attachments.packmaster

    -- PlayerUnitFirstPerson and the viewport must keep the hero base forever.
    -- The Skaven controller is a child animation target only; linking its root
    -- prevents locomotion clips from drifting away from the camera authority.
    World.link_unit(
        extension.world,
        skaven_base,
        0,
        extension.first_person_unit,
        0)
    Unit.set_local_position(skaven_base, 0, Vector3.zero())
    Unit.set_local_rotation(skaven_base, 0, Quaternion.identity())
    Unit.set_flow_variable(skaven_base, "lua_career_name", "pusfume")
    Unit.set_flow_variable(skaven_base, "lua_first_person_mesh_unit", skaven_arms)
    apply_pusfume_voice_switch(skaven_base)

    extension._pusfume_hero_first_person_unit = extension.first_person_unit
    extension._pusfume_hero_first_person_attachment =
        extension.first_person_attachment_unit
    extension._pusfume_skaven_first_person_unit = skaven_base
    extension._pusfume_skaven_first_person_attachment = skaven_arms
    extension._pusfume_skaven_first_person_attachments = skaven_attachments
    extension._pusfume_active_animation_unit = extension.first_person_unit
    extension._pusfume_active_first_person_rig = "hero"
    extension._pusfume_active_skaven_role = nil

    mod:info(
        "[pusfume] Dual first-person attachments created: hero=Janfon-160 skaven=%s camera_base=hero",
        config.native_versus_first_person and "Fatshark-native-role-set" or "Janfon-99")

    return true
end

local function relink_damage_unit(world, weapon_extension, first_person_unit,
        attachment_node_linking)
    local damage_unit = weapon_extension and weapon_extension.actual_damage_unit
    local attachment = attachment_node_linking and attachment_node_linking[1]

    if not damage_unit or not Unit.alive(damage_unit) or not attachment then
        return
    end

    World.unlink_unit(world, damage_unit)

    local source_node = attachment.source
    local source_node_index = type(source_node) == "string"
        and Unit.node(first_person_unit, source_node) or source_node

    World.link_unit(world, damage_unit, 0, first_person_unit, source_node_index)
end

local function relink_weapon_unit(inventory_extension, weapon_unit,
        first_person_unit, attachment_node_linking)
    if not weapon_unit or not Unit.alive(weapon_unit)
            or type(attachment_node_linking) ~= "table" then
        return false
    end

    local weapon_extension = ScriptUnit.has_extension(weapon_unit, "weapon_system")

    GearUtils.unlink(inventory_extension._world, weapon_unit)
    GearUtils.link(
        inventory_extension._world,
        attachment_node_linking,
        {},
        first_person_unit,
        weapon_unit)

    if weapon_extension then
        weapon_extension.first_person_unit = first_person_unit
        relink_damage_unit(
            inventory_extension._world,
            weapon_extension,
            first_person_unit,
            attachment_node_linking)

        for _, action in pairs(weapon_extension.actions or {}) do
            action.first_person_unit = first_person_unit
            if action.owner_unit_first_person then
                action.owner_unit_first_person = first_person_unit
            end
        end
    end

    return true
end

local function relink_ammo_unit(inventory_extension, ammo_unit,
        first_person_unit, attachment_node_linking)
    if not ammo_unit or not Unit.alive(ammo_unit)
            or type(attachment_node_linking) ~= "table" then
        return false
    end

    GearUtils.unlink(inventory_extension._world, ammo_unit)
    GearUtils.link(
        inventory_extension._world,
        attachment_node_linking,
        {},
        first_person_unit,
        ammo_unit)

    return true
end

local function relink_first_person_slot(inventory_extension, slot_data,
        first_person_unit, rig_name)
    if not slot_data or slot_data._pusfume_first_person_rig == rig_name then
        return
    end

    local item_template = BackendUtils.get_item_template(slot_data.item_data)
    local rebound = 0

    for _, hand in ipairs({ "right", "left" }) do
        local linking = item_template[hand .. "_hand_attachment_node_linking"]
        local first_person_linking = linking and linking.first_person
            and linking.first_person.wielded
        local weapon_unit = slot_data[hand .. "_unit_1p"]

        if relink_weapon_unit(
                inventory_extension,
                weapon_unit,
                first_person_unit,
                first_person_linking) then
            rebound = rebound + 1
        end

        local ammo_data = item_template.ammo_data
        local ammo_linking = ammo_data
            and ammo_data.ammo_hand == hand
            and ammo_data.ammo_unit_attachment_node_linking
        local ammo_first_person_linking = ammo_linking
            and ammo_linking.first_person
            and ammo_linking.first_person.wielded

        if relink_ammo_unit(
                inventory_extension,
                slot_data[hand .. "_ammo_unit_1p"],
                first_person_unit,
                ammo_first_person_linking) then
            rebound = rebound + 1
        end
    end

    slot_data._pusfume_first_person_rig = rig_name
    mod:info("[pusfume] First-person slot rebound slot=%s rig=%s units=%d",
        tostring(slot_data.id), rig_name, rebound)
end

local function stop_inactive_warpfire_effect(inventory_extension, active_slot)
    if active_slot == "slot_ranged" then
        return
    end

    local equipment = inventory_extension._equipment
    local slot_data = equipment and equipment.slots
        and equipment.slots.slot_ranged
    local item_key = slot_data and slot_data.item_data
        and slot_data.item_data.key

    if item_key ~= WARPFIRE_ITEM_KEY then
        return
    end

    local stopped_state = false
    local reset_units = 0
    local disabled_lights = 0
    local reset_names = {}
    for _, weapon_unit in pairs({
            slot_data.right_unit_1p,
            slot_data.left_unit_1p,
            slot_data.right_unit_3p,
            slot_data.left_unit_3p,
        }) do
        if weapon_unit and Unit.alive(weapon_unit) then
            local weapon_extension =
                ScriptUnit.has_extension(weapon_unit, "weapon_system")
            if weapon_extension
                    and type(weapon_extension.current_synced_state) == "function"
                    and weapon_extension:current_synced_state() then
                weapon_extension:change_synced_state(nil)
                stopped_state = true
            end

            local light_count = Unit.num_lights(weapon_unit)
            for light_index = 0, light_count - 1 do
                Light.set_enabled(Unit.light(weapon_unit, light_index), false)
            end
            disabled_lights = disabled_lights + light_count

            if not state.inactive_warpfire_units[weapon_unit] then
                -- cooldown_ready is the Warpfire unit's ready/glow state. End
                -- that state, then send the inventory's canonical unwield event.
                Unit.flow_event(weapon_unit, "wind_up_start")
                Unit.flow_event(weapon_unit, "lua_unwield")
                Unit.set_unit_visibility(weapon_unit, false)
                state.inactive_warpfire_units[weapon_unit] = true
                reset_units = reset_units + 1
                reset_names[#reset_names + 1] = Unit.debug_name(weapon_unit)
            end
        end
    end

    if stopped_state or reset_units > 0 or disabled_lights > 0
            or not inventory_extension._pusfume_warpfire_idle_logged then
        inventory_extension._pusfume_warpfire_idle_logged = true
        mod:info(
            "[pusfume] Inactive Warpfire visual state cleared slot=%s synced_state_stopped=%s units_reset=%d lights_disabled=%d units=%s",
            tostring(active_slot), tostring(stopped_state), reset_units,
            disabled_lights, table.concat(reset_names, ","))
    end
end

local function switch_first_person_rig(extension, inventory_extension, role)
    if not extension._pusfume_skaven_first_person_unit then
        return false
    end

    local use_skaven = role ~= nil
    local rig_name = use_skaven and "skaven" or "hero"
    local first_person_unit = use_skaven
        and extension._pusfume_skaven_first_person_unit
        or extension._pusfume_hero_first_person_unit
    local skaven_attachments = extension._pusfume_skaven_first_person_attachments
    local attachment_unit = use_skaven
            and skaven_attachments
            and (skaven_attachments[role] or skaven_attachments.packmaster)
        or extension._pusfume_hero_first_person_attachment

    if not first_person_unit or not Unit.alive(first_person_unit)
            or not attachment_unit or not Unit.alive(attachment_unit) then
        mod:error("[pusfume] First-person rig switch unavailable rig=%s role=%s",
            rig_name, tostring(role))
        return false
    end

    set_unit_visible(extension._pusfume_hero_first_person_attachment, false)
    if skaven_attachments then
        for _, skaven_attachment in pairs(skaven_attachments) do
            set_unit_visible(skaven_attachment, false)
        end
    end

    if extension._pusfume_active_first_person_rig ~= rig_name
            or extension._pusfume_active_skaven_role ~= role then
        extension._pusfume_first_person_probe_logged = nil
        extension._pusfume_first_person_probe_frames = 0
        extension._pusfume_weapon_presentation_ready = nil
        extension._pusfume_weapon_hide_logged = nil
    end

    local custom_assassin = role == "gutter_runner"
        and type(installed_config and installed_config.assassin_first_person_clips)
            == "table"

    if use_skaven then
        AttachmentUtils.unlink(extension.world, attachment_unit)
        if custom_assassin then
            -- The custom clips are compiled against Janfon's 99-bone unit, not
            -- Fatshark's 59-bone Skaven camera base. Link only the root so the
            -- attachment keeps camera authority while its own clip drives all
            -- remaining bones.
            World.link_unit(
                extension.world, attachment_unit, 0, first_person_unit, 0)
            Unit.set_local_position(attachment_unit, 0, Vector3.zero())
            Unit.set_local_rotation(
                attachment_unit, 0, Quaternion.identity())
        elseif not link_shared_first_person_nodes(
                extension.world,
                first_person_unit,
                attachment_unit,
                AttachmentNodeLinking.skaven_first_person_attachment,
                "Janfon-99-native-role") then
            mod:error(
                "[pusfume] Failed to restore native Skaven attachment links role=%s",
                tostring(role))
            return false
        end
    end

    -- Do not assign extension.first_person_unit here. The viewport, camera,
    -- look state and hero locomotion all cache the unit created by init.
    extension._pusfume_active_animation_unit = custom_assassin
        and attachment_unit or first_person_unit
    extension._pusfume_active_first_person_rig = rig_name
    extension._pusfume_active_skaven_role = role
    if role ~= "gutter_runner" and extension._pusfume_assassin_manual_driver then
        local disabled_unit =
            extension._pusfume_assassin_disabled_state_machine_unit
        if disabled_unit and Unit.alive(disabled_unit) then
            Unit.enable_animation_state_machine(disabled_unit)
        end
        extension._pusfume_assassin_manual_driver = nil
        extension._pusfume_assassin_disabled_state_machine_unit = nil
        extension._pusfume_assassin_clip = nil
    end
    if use_skaven then
        extension._pusfume_skaven_first_person_attachment = attachment_unit
        Unit.set_flow_variable(first_person_unit, "lua_first_person_mesh_unit", attachment_unit)
    end
    extension._pusfume_weapon_pose_slot = nil

    local weapon_animation_unit = extension._pusfume_active_animation_unit
    inventory_extension._first_person_unit = weapon_animation_unit
    Unit.set_data(
        weapon_animation_unit, "equipment", inventory_extension._equipment)

    local visible = extension.first_person_mode
        and extension._show_first_person_units
        and not extension.tutorial_first_person
    set_unit_visible(attachment_unit, visible == true)

    mod:info("[pusfume] First-person attachment active rig=%s role=%s visible=%s camera_base=hero",
        rig_name, tostring(role), tostring(visible == true))

    return true
end

local function prepare_first_person_rig_for_wield(inventory_extension, slot_name)
    local extension = inventory_extension.first_person_extension
    local slot_data = inventory_extension._equipment
        and inventory_extension._equipment.slots[slot_name]

    if not extension or not extension._pusfume_first_person or not slot_data then
        return
    end

    stop_inactive_warpfire_effect(inventory_extension, slot_name)

    local item_template = BackendUtils.get_item_template(slot_data.item_data)
    local role = item_template
        and SKAVEN_ROLE_BY_POSE[item_template.pusfume_role_pose]

    if switch_first_person_rig(extension, inventory_extension, role) then
        local animation_unit = extension._pusfume_active_animation_unit
        relink_first_person_slot(
            inventory_extension,
            slot_data,
            animation_unit,
            role and "skaven" or "hero")
    end
end

local function destroy_dual_first_person_rig(extension)
    local skaven_base = extension._pusfume_skaven_first_person_unit
    local skaven_attachments = extension._pusfume_skaven_first_person_attachments

    if skaven_attachments then
        for _, skaven_arms in pairs(skaven_attachments) do
            if skaven_arms and Unit.alive(skaven_arms) then
                AttachmentUtils.unlink(extension.world, skaven_arms)
                Managers.state.unit_spawner:mark_for_deletion(skaven_arms)
            end
        end
    end

    if skaven_base and Unit.alive(skaven_base) then
        World.unlink_unit(extension.world, skaven_base)
        Managers.state.unit_spawner:mark_for_deletion(skaven_base)
    end

    extension._pusfume_skaven_first_person_unit = nil
    extension._pusfume_skaven_first_person_attachment = nil
    extension._pusfume_skaven_first_person_attachments = nil
    extension._pusfume_active_animation_unit = nil
end

local function install_first_person_hook(registry, config)
    if not config.first_person_unit then
        return true
    end

    if state.first_person_hook_installed then
        return true
    end

    if not PlayerUnitFirstPerson then
        return false
    end

    mod:hook(PlayerUnitFirstPerson, "init", function(func, extension,
            extension_init_context, unit, extension_init_data)
        local profile = extension_init_data.profile
        local hero_attributes = Managers.backend:get_interface("hero_attributes")
        local career_index = hero_attributes:get(profile.display_name, "career") or 1
        local career = profile.careers[career_index]

        if career and career.name == registry.CAREER_NAME then
            if state.native_skaven_skin_registered
                    and not ensure_native_skaven_first_person_packages(config) then
                mod:error("[pusfume] Native Skaven first-person spawn blocked; retaining donor skin")
                return func(extension, extension_init_context, unit, extension_init_data)
            end

            local donor_skin_name = extension_init_data.skin_name
            local donor_skin = Cosmetics[donor_skin_name]
            local source_rest_unit_name = donor_skin and donor_skin.first_person
                or profile.base_units.first_person

            -- Vanilla chooses and spawns the first-person attachment inside
            -- init. Substitute only for that call, then restore the shared
            -- extension data before any later system can observe the change.
            extension_init_data.skin_name = config.skin_name
            local donor_default_state_machine = profile.default_state_machine

            if state.native_skaven_skin_registered then
                -- Playable Pactsworn profiles deliberately omit this field:
                -- the shared Skaven base carries its own controller. Applying
                -- Bardin's common controller deforms the Skaven skeleton even
                -- though every attachment node is linked exactly.
                profile.default_state_machine = nil
            end

            mod:info("[pusfume] First-person skin substitution: %s -> %s",
                tostring(donor_skin_name), config.skin_name)
            local result = func(extension, extension_init_context, unit, extension_init_data)

            profile.default_state_machine = donor_default_state_machine
            extension_init_data.skin_name = donor_skin_name
            extension._pusfume_first_person = true
            extension._pusfume_donor_default_state_machine = donor_default_state_machine
            extension._pusfume_weapon_hide_pending = true
            apply_pusfume_voice_switch(extension.first_person_unit)
            apply_pusfume_voice_switch(extension.first_person_attachment_unit)
            link_shared_first_person_nodes(
                extension.world,
                extension.first_person_unit,
                extension.first_person_attachment_unit,
                AttachmentNodeLinking.first_person_attachment,
                "Janfon-160-human")
            spawn_dual_first_person_rig(extension, config)
            extension._pusfume_initial_rig_pending = true
            restore_first_person_weapons(extension)
            apply_first_person_materials(extension, config)
            if config.first_person_direct_link then
                state.first_person_direct_link = true
                mod:info("[pusfume] First-person donor-rest direct links active")
            else
                initialize_first_person_retarget(extension, source_rest_unit_name)
            end

            return result
        end

        return func(extension, extension_init_context, unit, extension_init_data)
    end)
    mod:hook(PlayerUnitFirstPerson, "destroy", function(func, extension)
        if extension._pusfume_first_person then
            destroy_dual_first_person_rig(extension)
        end

        return func(extension)
    end)
    if SimpleInventoryExtension then
        mod:hook(SimpleInventoryExtension, "wield", function(func, inventory_extension,
                slot_name)
            prepare_first_person_rig_for_wield(inventory_extension, slot_name)

            return func(inventory_extension, slot_name)
        end)
    end
    mod:hook(PlayerUnitFirstPerson, "animation_event", function(func, extension, event)
        -- The native Skaven 1P rig lacks the hero item wield events
        -- (to_potion, to_healthkit, to_grenade, ...). Playing an unknown
        -- event resolves to a negative Stingray animation index and CTDs
        -- (2026-07-19 22:41 potion wield). Skip any event the rig does not
        -- carry; weapons keep their sanitized contracts.
        if play_custom_first_person_clip(extension, event) then
            return
        end

        if skip_missing_first_person_event(
                extension, extension.first_person_unit, event) then
            return
        end

        return func(extension, event)
    end)
    if WeaponUnitExtension then
        -- start_action sends equip_interrupt directly through Unit.animation_event
        -- before _play_1p_anim. The Assassin rig intentionally has no active
        -- state machine while its clips are manually timed, so suppress only
        -- that vanilla blend event by borrowing the existing looping branch.
        mod:hook(WeaponUnitExtension, "start_action", function(func,
                weapon_extension, action_name, sub_action_name, actions, ...)
            local first_person_extension = weapon_extension.first_person_extension
            local action = actions and actions[action_name]
            local action_settings = action and action[sub_action_name]
            -- Vanilla sends equip_interrupt to this exact cached unit. During
            -- a rig switch it can still be the old controllerless Assassin
            -- attachment even after the extension's active role has changed.
            local event_unit = weapon_extension.first_person_unit
            local controllerless_pusfume = first_person_extension
                and first_person_extension._pusfume_first_person
                and event_unit
                and Unit.alive(event_unit)
                and not Unit.has_animation_state_machine(event_unit)
                and action_settings
                and action_settings.looping_anim ~= true

            if controllerless_pusfume then
                local previous_looping = action_settings.looping_anim
                action_settings.looping_anim = true
                func(weapon_extension, action_name, sub_action_name, actions, ...)
                action_settings.looping_anim = previous_looping
                return
            end

            return func(weapon_extension, action_name, sub_action_name, actions, ...)
        end)
        -- This path calls Unit.animation_event directly and bypasses the guard
        -- above. Check Fatshark's effective event before the native call.
        mod:hook(WeaponUnitExtension, "_play_1p_anim", function(func, weapon_extension,
                event_1p, event, first_person_unit, ...)
            local first_person_extension = weapon_extension.first_person_extension
            -- Fatshark passes the hero/network event second but normally plays
            -- that value directly. Prefer our explicit 1P override so Janfon's
            -- compiled clips are not discarded in favor of Elf event names.
            local custom_event = event_1p or event
            local native_event = event or event_1p

            if first_person_extension
                    and play_custom_first_person_clip(
                        first_person_extension, custom_event) then
                return
            end

            if skip_missing_first_person_event(
                    first_person_extension, first_person_unit, native_event) then
                return
            end

            return func(weapon_extension, event_1p, event, first_person_unit, ...)
        end)
        mod:hook(WeaponUnitExtension, "_play_end_event_1p",
            function(func, weapon_extension, event)
                local first_person_extension =
                    weapon_extension.first_person_extension

                if first_person_extension
                        and play_custom_first_person_clip(
                            first_person_extension, event) then
                    return
                end

                if skip_missing_first_person_event(
                        first_person_extension,
                        weapon_extension.first_person_unit,
                        event) then
                    return
                end

                return func(weapon_extension, event)
            end)
    end
    mod:hook_safe(PlayerUnitFirstPerson, "update", function(extension, unit,
            input, dt, context, t)
        if extension._pusfume_first_person then
            -- Clear the old hand-diagnostic hide reason after hot reloads.
            restore_first_person_weapons(extension)
            apply_first_person_materials(extension, config)
            if extension._pusfume_initial_rig_pending
                    and extension.inventory_extension then
                local wielded_slot = extension.inventory_extension:get_wielded_slot_name()
                if wielded_slot then
                    extension._pusfume_initial_rig_pending = nil
                    prepare_first_person_rig_for_wield(
                        extension.inventory_extension, wielded_slot)
                    mod:info(
                        "[pusfume] Initial first-person attachment selected slot=%s",
                        tostring(wielded_slot))
                end
            end
            local active_attachment = extension._pusfume_active_first_person_rig
                    == "skaven"
                and extension._pusfume_skaven_first_person_attachment
                or extension._pusfume_hero_first_person_attachment
            local visible = extension.first_person_mode
                and extension._show_first_person_units
                and not extension.tutorial_first_person
            set_unit_visible(extension._pusfume_hero_first_person_attachment,
                active_attachment == extension._pusfume_hero_first_person_attachment
                    and visible == true)
            local skaven_attachments =
                extension._pusfume_skaven_first_person_attachments or {}
            for _, skaven_attachment in pairs(skaven_attachments) do
                set_unit_visible(skaven_attachment,
                    skaven_attachment == active_attachment and visible == true)
            end
            set_unit_visible(active_attachment, visible == true)
            if extension._pusfume_active_first_person_rig ~= "skaven"
                    and not config.first_person_direct_link then
                update_first_person_retarget(extension)
            end
            update_custom_first_person_clip(extension, t)
            extension._pusfume_first_person_probe_frames =
                (extension._pusfume_first_person_probe_frames or 0) + 1

            if extension._pusfume_first_person_probe_frames >= 30 then
                log_first_person_attachment_probe(extension)
            end
        end
    end)
    state.first_person_hook_installed = true

    return true
end

local function install_dialogue_voice_hook(registry)
    if state.dialogue_voice_hook_installed or not DialogueContextSystem then
        return state.dialogue_voice_hook_installed
    end

    mod:hook_safe(DialogueContextSystem, "extensions_ready", function(system,
            world, unit)
        local career_extension = ScriptUnit.has_extension(unit, "career_system")

        if career_extension
                and type(career_extension.career_name) == "function"
                and career_extension:career_name() == registry.CAREER_NAME then
            local dialogue_extension = ScriptUnit.has_extension(
                unit, "dialogue_system")

            if dialogue_extension and dialogue_extension.context then
                dialogue_extension.context.player_profile = PUSFUME_CHARACTER_VO
                mod:info("[pusfume] Dialogue profile routed to %s",
                    PUSFUME_CHARACTER_VO)
            end

            apply_pusfume_voice_switch(unit)
        end
    end)
    state.dialogue_voice_hook_installed = true

    return true
end

local function install_cosmetic_hook(registry, config)
    if state.hook_installed or not state.cosmetic_registered or not PlayerUnitCosmeticExtension then
        return state.hook_installed
    end

    mod:hook(PlayerUnitCosmeticExtension, "_init_mesh_attachment", function(func, extension,
            world, unit, skin_name, profile, career)
        if career and career.name == registry.CAREER_NAME then
            extension._cosmetics.skin = Cosmetics[config.skin_name]
            skin_name = config.skin_name
            mod:info("[pusfume] Attaching native third-person mesh to Pusfume player unit")
        end

        local result = func(extension, world, unit, skin_name, profile, career)

        if career and career.name == registry.CAREER_NAME then
            initialize_link_probe(extension, unit, config)
        end

        return result
    end)

    state.hook_installed = true

    return true
end

local function install_probe_hook()
    if state.probe_hook_installed or not PlayerUnitCosmeticExtension then
        return state.probe_hook_installed
    end

    mod:hook_safe(PlayerUnitCosmeticExtension, "update", function(extension, unit, dummy_input, dt, context, t)
        if extension._pusfume_native_config then
            apply_donor_material(extension, extension._pusfume_native_config)
            suppress_inherited_equipment_particles(extension, unit)
            hide_donor_weapons(extension, unit, extension._pusfume_native_config)
            hide_assassin_third_person_weapons(unit)
        end

        apply_manual_clip_probe(extension, t)
        apply_manual_skin_probe(extension, t)
        drive_locomotion_events(extension, unit, dt)
        sample_link_probe(extension, unit, t)
    end)

    state.probe_hook_installed = true

    return true
end

local function install_preview_package_filter(config)
    if state.preview_package_filter_installed then
        return true
    end

    if not CosmeticsUtils then
        return false
    end

    mod:hook(CosmeticsUtils, "retrieve_skin_packages_for_preview", function(func, skin_name)
        local packages = func(skin_name)

        if skin_name ~= config.skin_name then
            return packages
        end

        local filtered = {}

        for _, package_name in ipairs(packages) do
            if package_name ~= config.third_person_unit then
                filtered[#filtered + 1] = package_name
            end
        end

        if not state.preview_package_filtered then
            state.preview_package_filtered = true
            mod:info("[pusfume] Native preview will use the startup-resident Pusfume unit")
        end

        return filtered
    end)

    state.preview_package_filter_installed = true

    return true
end

function M.install(registry, config)
    installed_config = config
    state.hero_preview_enabled = config.hero_preview_enabled == true

    if not state.cosmetic_registered then
        register_cosmetic(registry, config)
    end

    install_cosmetic_hook(registry, config)
    local first_person_hook_ready = install_first_person_hook(registry, config)
    install_dialogue_voice_hook(registry)
    install_probe_hook()
    install_material_probe_command(config)

    if state.hero_preview_enabled and not install_preview_package_filter(config) then
        state.hero_preview_enabled = false
        mod:warning("[pusfume] Native hero preview disabled because CosmeticsUtils is unavailable")
    end

    return state.cosmetic_registered and state.hook_installed and state.probe_hook_installed
        and first_person_hook_ready
end

function M.preview_enabled()
    return state.cosmetic_registered and state.hero_preview_enabled
end

function M.native_skin_name()
    return state.cosmetic_registered and state.native_skin_name or nil
end

function M.apply_donor_to_unit(unit)
    if not installed_config then
        return false
    end

    return apply_donor_material_to_unit(unit, installed_config)
end

function M.enabled()
    return state.cosmetic_registered
end

function M.status()
    return state
end

function M.donor_status()
    local config = installed_config

    if not config or not config.donor_material_enabled then
        return {
            enabled = false,
        }
    end

    return {
        enabled = true,
        package_ok = can_get("package", config.donor_package) == true,
        material_ok = can_get("material", config.donor_material) == true,
        package_loaded = state.donor_package_loaded,
        applied = state.donor_material_applied,
        fur_material_ok = type(config.fur_child_material) == "string"
            and can_get("material", config.fur_child_material) == true,
        fur_applied = state.fur_material_applied,
        whisker_material_ok = type(config.whisker_child_material) == "string"
            and can_get("material", config.whisker_child_material) == true,
        whisker_applied = state.whisker_material_applied,
        whisker_package_ok = type(config.whisker_donor_package) ~= "string"
            or can_get("package", config.whisker_donor_package) == true,
        whisker_package_loaded = type(config.whisker_donor_package) ~= "string"
            or state.whisker_donor_package_loaded,
    }
end

function M.first_person_status()
    local config = installed_config

    return {
        enabled = type(config and config.first_person_unit) == "string",
        dual_rigs_requested = config and config.dual_first_person_rigs == true,
        dual_rigs_ready = state.dual_first_person_rigs_ready == true,
        native_skaven_baseline = config and config.native_skaven_first_person == true
            and state.native_skaven_skin_registered
            and state.native_skaven_packages_loaded,
        native_skaven_packages_loaded = state.native_skaven_packages_loaded,
        resource_available = state.first_person_resource_available,
        hook_installed = state.first_person_hook_installed,
        package_requested = state.first_person_material_package_requested,
        package_loaded = state.first_person_material_package_loaded,
        materials_applied = state.first_person_materials_applied,
        direct_link = state.first_person_direct_link == true,
        retarget_initialized = state.first_person_retarget_initialized == true,
        bounds_copied = state.first_person_bounds_copied == true,
        camera_anchor = state.first_person_retarget_initialized == true,
    }
end

function M.animation_status()
    local config = installed_config

    return {
        locomotion_events_enabled = (config and config.locomotion_events_enabled) == true,
        locomotion_events_available = state.locomotion_events_available,
        manual_clip_probe = (config and config.manual_clip_probe) == true,
        manual_skin_probe = (config and config.manual_skin_probe) == true,
    }
end

function M.shutdown(config)
    if state.native_skaven_packages_requested then
        for index = #NATIVE_SKAVEN_FIRST_PERSON_PACKAGES, 1, -1 do
            local package_name = NATIVE_SKAVEN_FIRST_PERSON_PACKAGES[index]

            if Managers.package and Managers.package:has_loaded(
                    package_name, NATIVE_SKAVEN_PACKAGE_REFERENCE) then
                Managers.package:unload(package_name, NATIVE_SKAVEN_PACKAGE_REFERENCE)
            end
        end

        state.native_skaven_packages_requested = false
        state.native_skaven_packages_loaded = false
        state.native_skaven_packages_logged = false
        state.native_skaven_skin_registered = false
        mod:info("[pusfume] Released native Skaven first-person packages")
    end

    if state.first_person_material_package_requested then
        if mod.package_status and
                mod:package_status(config.first_person_material_package) == "loaded" then
            mod:unload_package(config.first_person_material_package)
        end
        state.first_person_material_package_requested = false
        state.first_person_material_package_loaded = false
        state.first_person_material_package_error_logged = false
        state.first_person_material_error_logged = false
        state.first_person_materials_applied = false
        mod:info("[pusfume] Released first-person material package")
    end

    if state.shadow_package_requested then
        if mod.package_status and
                mod:package_status(config.donor_texture_shadow_package) == "loaded" then
            mod:unload_package(config.donor_texture_shadow_package)
            mod:info("[pusfume] Released late donor texture shadow package")
        end

        state.shadow_package_requested = false
        state.shadow_package_loaded = false
        state.shadow_package_error_logged = false
    end

    if state.child_package_requested then
        if mod.package_status and mod:package_status(config.parent_child_package) == "loaded" then
            mod:unload_package(config.parent_child_package)
            mod:info("[pusfume] Released native child material package")
        end

        state.child_package_requested = false
        state.child_package_loaded = false
        state.child_package_error_logged = false
    end

    if state.whisker_donor_package_requested and Managers.package then
        Managers.package:unload(config.whisker_donor_package, WHISKER_DONOR_PACKAGE_REFERENCE)
        state.whisker_donor_package_requested = false
        state.whisker_donor_package_loaded = false
        state.whisker_donor_package_error_logged = false
        mod:info("[pusfume] Released Laurel whisker donor package")
    end

    if state.donor_package_requested and Managers.package then
        Managers.package:unload(config.donor_package, DONOR_PACKAGE_REFERENCE)
        state.donor_package_requested = false
        state.donor_package_loaded = false
        state.donor_package_error_logged = false
        state.donor_material_error_logged = false
        state.donor_material_applied = false
        state.whisker_material_applied = false
        state.donor_texture_errors = {}
        mod:info("[pusfume] Released Globadier donor package")
    end
end

return M
