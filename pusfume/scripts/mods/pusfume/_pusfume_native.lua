local mod = get_mod("pusfume")

local M = {}
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
    donor_texture_errors = {},
    donor_weapons_hidden = false,
    locomotion_events_available = false,
}

local WALK_ENTER_SPEED = 0.5
local IDLE_ENTER_SPEED = 0.2
local FIRST_PERSON_WEAPON_HIDE_REASON = "pusfume_hands_diagnostic"
local PUSFUME_CHARACTER_VO = "vs_poison_wind_globadier"
local PUSFUME_SOUND_CHARACTER = "dwarf_slayer"

local installed_config

local function restore_first_person_weapons(extension)
    -- VT2 assigns inventory_extension in extensions_ready(), after init.
    -- Calling the native hide API during construction crashes before that
    -- lifecycle boundary, so leave the request pending until it is available.
    if not extension.inventory_extension then
        return false
    end

    extension:hide_weapons(FIRST_PERSON_WEAPON_HIDE_REASON, false)
    extension._pusfume_weapons_hidden = false

    if not extension._pusfume_weapon_hide_logged then
        extension._pusfume_weapon_hide_logged = true
        mod:info("[pusfume] First-person weapons visible for Pusfume prototype loadout testing")
    end

    return true
end

local DONOR_PACKAGE_REFERENCE = "pusfume_globadier_material"
local WHISKER_DONOR_PACKAGE_REFERENCE = "pusfume_laurel_material"
local DONOR_TEXTURE_CHANNELS = {
    color = "texture_map_02af90f8",
    -- Proven from donor channel statistics and the spliced child build:
    -- texture_map_27b67fd2 is the donor's black emissive map. Do not write
    -- Pusfume normals into it during live material probes.
    normal_gloss = "texture_map_8bf37d8e",
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
    normal_gloss = "pusfume_atlas_nm",
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
                "%s=%s", slot_name, material == config.donor_material and "donor" or "child")
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
                    (set_material_texture(material, DONOR_TEXTURE_CHANNELS.normal_gloss,
                        DONOR_ATLAS_TEXTURES.normal_gloss) and 1 or 0)
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
    Unit.set_flow_variable(unit, "character_vo", PUSFUME_CHARACTER_VO)
    Unit.set_flow_variable(unit, "sound_character", PUSFUME_SOUND_CHARACTER)
    Unit.flow_event(unit, "character_vo_set")

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

    local first_person_unit = config.first_person_unit
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
    local attachment_node_linking = config.root_animation_isolation
            and AttachmentNodeLinking.pusfume_root_animation_attachment
        or AttachmentNodeLinking.pusfume_third_person_attachment

    skin.third_person_attachment = {
        unit = config.third_person_unit,
        attachment_node_linking = attachment_node_linking,
    }
    if first_person_unit then
        local first_person_linking = config.first_person_direct_link
                and AttachmentNodeLinking.pusfume_first_person_direct_attachment
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
    end

    if config.root_animation_isolation then
        mod:warning("[pusfume] Root-only animation isolation is active")
    end

    return true
end

local function apply_first_person_materials(extension, config)
    if extension._pusfume_first_person_materials_applied then
        return true
    end

    local unit = extension.first_person_attachment_unit
    local materials = config.first_person_materials
    if type(materials) ~= "table" or not unit or not Unit.alive(unit)
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

        Unit.set_material(unit, slot_name, material_name)
    end

    extension._pusfume_first_person_materials_applied = true
    state.first_person_materials_applied = true
    mod:info("[pusfume] Native first-person materials applied")

    return true
end

local first_person_probe_nodes = {
    { source = "j_spine2", target = "j_spine1" },
    { source = "j_leftarm", target = "j_leftarm" },
    { source = "j_lefthand", target = "j_lefthand" },
    { source = "j_rightarm", target = "j_rightarm" },
    { source = "j_righthand", target = "j_righthand" },
}

local function initialize_first_person_retarget(extension, source_rest_unit_name)
    if extension._pusfume_first_person_retarget then
        return true
    end

    local source = extension.first_person_unit
    local target = extension.first_person_attachment_unit
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
    local source = extension.first_person_unit
    local target = extension.first_person_attachment_unit

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

    local source = extension.first_person_unit
    local target = extension.first_person_attachment_unit
    if not source or not target or not Unit.alive(source) or not Unit.alive(target) then
        return
    end

    local node_distances = {}
    for _, node_pair in ipairs(first_person_probe_nodes) do
        local source_node = Unit.node(source, node_pair.source)
        local target_node = Unit.node(target, node_pair.target)
        local source_position = Unit.world_position(source, source_node)
        local target_position = Unit.world_position(target, target_node)

        node_distances[#node_distances + 1] = string.format(
            "%s->%s=%.4f", node_pair.source, node_pair.target,
            Vector3.distance(source_position, target_position))
    end

    extension._pusfume_first_person_probe_logged = true
    mod:info(
        "[pusfume] First-person attachment probe meshes=%d mode=%s shown=%s direct=%s retarget=%s bounds=%s lods=%s/%s anchor_error=%.4f anchor_delta=%s limb_error=%.4f/%.4f limb_residual=%.4f/%.4f limb_delta=%s/%s root=%s scale=%s node_distance(%s)",
        Unit.num_meshes(target),
        tostring(extension.first_person_mode),
        tostring(extension._show_first_person_units),
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
            local donor_skin_name = extension_init_data.skin_name
            local donor_skin = Cosmetics[donor_skin_name]
            local source_rest_unit_name = donor_skin and donor_skin.first_person
                or profile.base_units.first_person

            -- Vanilla chooses and spawns the first-person attachment inside
            -- init. Substitute only for that call, then restore the shared
            -- extension data before any later system can observe the change.
            extension_init_data.skin_name = config.skin_name
            mod:info("[pusfume] First-person skin substitution: %s -> %s",
                tostring(donor_skin_name), config.skin_name)
            local result = func(extension, extension_init_context, unit, extension_init_data)

            extension_init_data.skin_name = donor_skin_name
            extension._pusfume_first_person = true
            extension._pusfume_weapon_hide_pending = false
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
    mod:hook_safe(PlayerUnitFirstPerson, "update", function(extension)
        if extension._pusfume_first_person then
            -- Clear the old hand-diagnostic hide reason after hot reloads.
            restore_first_person_weapons(extension)
            apply_first_person_materials(extension, config)
            if not config.first_person_direct_link then
                update_first_person_retarget(extension)
            end
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
            hide_donor_weapons(extension, unit, extension._pusfume_native_config)
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
        whisker_package_ok = type(config.whisker_donor_package) == "string"
            and can_get("package", config.whisker_donor_package) == true,
        whisker_package_loaded = state.whisker_donor_package_loaded,
    }
end

function M.first_person_status()
    local config = installed_config

    return {
        enabled = type(config and config.first_person_unit) == "string",
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
