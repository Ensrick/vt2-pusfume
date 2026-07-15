local mod = get_mod("pusfume")

local M = {}
local state = {
    cosmetic_registered = false,
    hook_installed = false,
    resource_available = false,
}

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
    skin.third_person_attachment = {
        unit = config.third_person_unit,
        attachment_node_linking = AttachmentNodeLinking.pusfume_third_person_attachment,
    }
    Cosmetics[config.skin_name] = skin
    registry.set_native_skin(config.skin_name)
    state.cosmetic_registered = true

    mod:info("[pusfume] Native third-person cosmetic registered: %s", config.third_person_unit)

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

        return func(extension, world, unit, skin_name, profile, career)
    end)

    state.hook_installed = true

    return true
end

function M.install(registry, config)
    if not state.cosmetic_registered then
        register_cosmetic(registry, config)
    end

    install_cosmetic_hook(registry, config)

    return state.cosmetic_registered and state.hook_installed
end

function M.enabled()
    return state.cosmetic_registered
end

function M.status()
    return state
end

return M
