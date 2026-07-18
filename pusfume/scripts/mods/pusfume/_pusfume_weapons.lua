local mod = get_mod("pusfume")

local M = {}

M.ITEM_KEYS = {
    slot_melee = "pusfume_packmaster_hook",
    slot_ranged = "pusfume_warpfire_thrower",
}
M.BACKEND_IDS = {
    slot_melee = "pusfume_item_packmaster_hook_v1",
    slot_ranged = "pusfume_item_warpfire_thrower_v1",
}
M.TEMPLATE_NAMES = {
    slot_melee = "pusfume_packmaster_hook_template",
    slot_ranged = "pusfume_warpfire_thrower_template",
}
M.UNIT_PATHS = {
    slot_melee = "units/weapons/player/dark_pact/wpn_skaven_packmaster_claw/wpn_skaven_packmaster_claw",
    slot_ranged = "units/weapons/player/dark_pact/wpn_skaven_warpfiregun/wpn_skaven_warpfiregun",
}

local state = {
    backend_items = {},
    installed = false,
    lookups_registered = false,
    masterlist_registered = false,
    templates_registered = false,
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

local function append_lookup(lookup, name)
    if rawget(lookup, name) then
        return rawget(lookup, name)
    end

    local index = #lookup + 1
    rawset(lookup, index, name)
    rawset(lookup, name, index)

    return index
end

local function register_templates()
    local melee_source = Weapons and Weapons.two_handed_axes_template_1
    local ranged_source = Weapons and Weapons.drakegun_template_1
    local versus_links = AttachmentNodeLinking and AttachmentNodeLinking.vs_warpfire_thrower_gun
    local warpfire_left = versus_links and versus_links.left

    if not melee_source or not ranged_source
            or not AttachmentNodeLinking or not AttachmentNodeLinking.vs_packmaster_claw
            or not warpfire_left then
        return false
    end

    if not rawget(Weapons, M.TEMPLATE_NAMES.slot_melee) then
        local template = deep_clone(melee_source)

        -- Keep Ranger-compatible action poses while letting the shipped claw's
        -- articulated pieces follow the Skaven weapon-component nodes.
        template.right_hand_attachment_node_linking = AttachmentNodeLinking.vs_packmaster_claw
        Weapons[M.TEMPLATE_NAMES.slot_melee] = template
    end

    if not rawget(Weapons, M.TEMPLATE_NAMES.slot_ranged) then
        local template = deep_clone(ranged_source)

        template.left_hand_attachment_node_linking = warpfire_left
        template.right_hand_attachment_node_linking = nil
        template.wwise_dep_left_hand = template.wwise_dep_right_hand
        template.wwise_dep_right_hand = nil
        Weapons[M.TEMPLATE_NAMES.slot_ranged] = template
    end

    state.templates_registered = true

    return true
end

local function item_definitions(registry)
    return {
        [M.ITEM_KEYS.slot_melee] = {
            can_wield = { registry.CAREER_NAME },
            description = "pusfume_packmaster_hook_description",
            display_name = "pusfume_packmaster_hook_name",
            has_power_level = true,
            hud_icon = "weapon_generic_icon_axe2h",
            inventory_icon = "icon_wpn_dw_2h_axe_01_t1",
            item_type = "dr_2h_axes",
            name = M.ITEM_KEYS.slot_melee,
            property_table_name = "melee",
            rarity = "plentiful",
            right_hand_unit = M.UNIT_PATHS.slot_melee,
            slot_type = "melee",
            template = M.TEMPLATE_NAMES.slot_melee,
            trait_table_name = "melee",
        },
        [M.ITEM_KEYS.slot_ranged] = {
            can_wield = { registry.CAREER_NAME },
            description = "pusfume_warpfire_thrower_description",
            display_name = "pusfume_warpfire_thrower_name",
            has_power_level = true,
            hud_icon = "weapon_generic_icon_units/weapons/weapon_display/display_rifle",
            inventory_icon = "icon_wpn_dw_iron_drake_02",
            item_type = "dr_drakegun",
            left_hand_unit = M.UNIT_PATHS.slot_ranged,
            name = M.ITEM_KEYS.slot_ranged,
            property_table_name = "ranged",
            rarity = "plentiful",
            slot_type = "ranged",
            template = M.TEMPLATE_NAMES.slot_ranged,
            trait_table_name = "ranged_heat",
        },
    }
end

local function make_backend_item(item_key, backend_id, item_data)
    return {
        CatalogVersion = "1",
        CreatedBy = "pusfume",
        CustomData = {
            power_level = "300",
            properties = "{}",
            rarity = "default",
            traits = "[]",
        },
        IsModItem = true,
        ItemId = item_key,
        ItemInstanceId = backend_id,
        PurchaseDate = "2026-07-18T00:00:00.000Z",
        RemainingUses = 1,
        UnitPrice = 0,
        backend_id = backend_id,
        bypass_skin_ownership_check = true,
        data = item_data,
        key = item_key,
        power_level = 300,
        properties = {},
        rarity = "default",
        traits = {},
    }
end

local function register_items(registry)
    if not ItemMasterList or not NetworkLookup
            or not NetworkLookup.item_names or not NetworkLookup.damage_sources then
        return false
    end

    local definitions = item_definitions(registry)

    for _, slot_name in ipairs({ "slot_melee", "slot_ranged" }) do
        local item_key = M.ITEM_KEYS[slot_name]
        local item_data = rawget(ItemMasterList, item_key)

        if not item_data then
            item_data = definitions[item_key]
            ItemMasterList[item_key] = item_data
        end

        append_lookup(NetworkLookup.item_names, item_key)
        append_lookup(NetworkLookup.damage_sources, item_key)
        state.backend_items[M.BACKEND_IDS[slot_name]] = make_backend_item(
            item_key, M.BACKEND_IDS[slot_name], item_data)
    end

    state.lookups_registered = true
    state.masterlist_registered = true

    return true
end

function M.install(registry)
    local templates_ready = register_templates()
    local items_ready = templates_ready and register_items(registry)

    state.installed = templates_ready and items_ready

    if state.installed then
        mod:info("[pusfume] registered Pusfume-only weapons melee=%s ranged=%s",
            M.ITEM_KEYS.slot_melee, M.ITEM_KEYS.slot_ranged)
    else
        mod:warning("[pusfume] Pusfume weapon dependencies are not ready; registration deferred")
    end

    return state.installed
end

function M.inject_backend_items(items)
    if type(items) ~= "table" then
        return items
    end

    for backend_id, item in pairs(state.backend_items) do
        items[backend_id] = item
    end

    return items
end

function M.backend_id_for_slot(slot_name)
    return M.BACKEND_IDS[slot_name]
end

function M.item_for_slot(slot_name)
    return state.backend_items[M.BACKEND_IDS[slot_name]]
end

function M.is_weapon_slot(slot_name)
    return slot_name == "slot_melee" or slot_name == "slot_ranged"
end

function M.overlay_loadout(loadout)
    local result = type(loadout) == "table" and table.clone(loadout) or {}

    result.slot_melee = M.BACKEND_IDS.slot_melee
    result.slot_ranged = M.BACKEND_IDS.slot_ranged

    return result
end

function M.overlay_loadout_collection(loadouts)
    if type(loadouts) ~= "table" then
        return loadouts
    end

    local result = {}

    for index, loadout in ipairs(loadouts) do
        result[index] = M.overlay_loadout(loadout)
    end

    return result
end

function M.status()
    return state
end

return M
