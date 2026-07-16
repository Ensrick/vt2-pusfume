local mod = get_mod("pusfume")

local M = {}
local state = {
    cosmetic_registered = false,
    hook_installed = false,
    probe_hook_installed = false,
    preview_package_filter_installed = false,
    preview_package_filtered = false,
    resource_available = false,
    hero_preview_enabled = false,
}

local PROBE_LINKS = {
    { source = "j_hips", target = "j_hips" },
    { source = "j_lefthand", target = "j_hand_L" },
}

local function articulation_vector(unit, hips_node, hand_node)
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

    for _, link in ipairs(PROBE_LINKS) do
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
    local target_articulation = articulation_vector(probe.mesh, "j_hips", "j_hand_L")

    details[#details + 1] = string.format(
        "articulation source_delta=%.4f target_delta=%.4f manual_angle=%.4f",
        Vector3.distance(source_articulation, probe.initial_source_articulation:unbox()),
        Vector3.distance(target_articulation, probe.initial_target_articulation:unbox()),
        probe.manual_angle or 0)

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

    local initial = {}

    for _, link in ipairs(PROBE_LINKS) do
        initial[link.source] = {
            source = Vector3Box(Unit.world_position(unit, Unit.node(unit, link.source))),
            target = Vector3Box(Unit.world_position(mesh, Unit.node(mesh, link.target))),
        }
    end

    local probe = {
        complete = false,
        initial = initial,
        initial_source_articulation = Vector3Box(articulation_vector(unit, "j_hips", "j_lefthand")),
        initial_target_articulation = Vector3Box(articulation_vector(mesh, "j_hips", "j_hand_L")),
        mesh = mesh,
        next_sample_at = 0.5,
        samples = 0,
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
        probe.manual_skin_probe = true
        probe.manual_node = Unit.node(mesh, "j_spine1")
        probe.manual_base_rotation = QuaternionBox(Unit.local_rotation(mesh, probe.manual_node))
        Unit.disable_animation_state_machine(mesh)
        mod:warning("[pusfume] Manual skin deformation probe is active on j_spine1")
    end

    extension._pusfume_native_probe = probe
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
    Cosmetics[config.skin_name] = skin
    registry.set_native_skin(config.skin_name)
    state.cosmetic_registered = true

    mod:info("[pusfume] Native third-person cosmetic registered: %s", config.third_person_unit)

    if config.root_animation_isolation then
        mod:warning("[pusfume] Root-only animation isolation is active")
    end

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
        apply_manual_clip_probe(extension, t)
        apply_manual_skin_probe(extension, t)
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
    state.hero_preview_enabled = config.hero_preview_enabled == true

    if not state.cosmetic_registered then
        register_cosmetic(registry, config)
    end

    install_cosmetic_hook(registry, config)
    install_probe_hook()

    if state.hero_preview_enabled and not install_preview_package_filter(config) then
        state.hero_preview_enabled = false
        mod:warning("[pusfume] Native hero preview disabled because CosmeticsUtils is unavailable")
    end

    return state.cosmetic_registered and state.hook_installed and state.probe_hook_installed
end

function M.preview_enabled()
    return state.cosmetic_registered and state.hero_preview_enabled
end

function M.enabled()
    return state.cosmetic_registered
end

function M.status()
    return state
end

return M
