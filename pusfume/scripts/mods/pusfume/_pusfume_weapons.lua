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
M.VERSUS_ITEM_KEYS = {
    slot_melee = "vs_packmaster_claw",
    slot_ranged = "vs_warpfire_thrower_gun",
}
M.UNIT_PATHS = {
    slot_melee = nil,
    slot_ranged = nil,
}

local state = {
    backend_items = {},
    installed = false,
    lookups_registered = false,
    masterlist_registered = false,
    hand_contract_ready = false,
    resolved_unit_paths = {},
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

local function resolve_versus_item(slot_name)
    local item = ItemMasterList and rawget(ItemMasterList, M.VERSUS_ITEM_KEYS[slot_name])

    if not item then
        return nil
    end

    local unit_path = item.right_hand_unit or item.left_hand_unit

    if type(unit_path) ~= "string" or not Application.can_get("unit", unit_path) then
        return nil
    end

    M.UNIT_PATHS[slot_name] = unit_path
    state.resolved_unit_paths[slot_name] = unit_path

    return item
end

local function hero_warpfire_condition(action_user)
    local status_extension = ScriptUnit.has_extension(action_user, "status_system")

    if status_extension and status_extension:is_climbing() then
        return false
    end

    local overcharge_extension = ScriptUnit.has_extension(action_user, "overcharge_system")

    return overcharge_extension and overcharge_extension:get_overcharge_value() <= 0
end


local function sanitize_warpfire_template(template)
    local action_one = template.actions and template.actions.dark_pact_action_one
    local action_reload = template.actions and template.actions.dark_pact_reload

    if not action_one or not action_one.default or not action_one.fire
            or not action_reload or not action_reload.default then
        return false
    end

    -- Versus ghost-mode and VCE state callbacks are absent in Adventure.
    -- Keep Fatshark's Warpfire action class, damage, input, heat, and FX data,
    -- but remove only callbacks that cross that mechanism boundary.
    action_one.default.condition_func = hero_warpfire_condition
    action_one.default.enter_function = nil
    action_one.default.finish_function = nil
    action_one.fire.enter_function = nil
    action_one.fire.finish_function = nil
    action_reload.default.enter_function = nil
    action_reload.default.finish_function = nil
    template.synced_states = nil

    return true
end

local function register_templates()
    local melee_source = Weapons and Weapons.vs_packmaster_claw
    local melee_actions = Weapons and Weapons.two_handed_axes_template_1
    local ranged_source = Weapons and Weapons.vs_warpfire_thrower_gun

    if not melee_source or not melee_actions or not ranged_source then
        return false
    end

    if not rawget(Weapons, M.TEMPLATE_NAMES.slot_melee) then
        local template = deep_clone(melee_source)

        -- Fatshark's Packmaster claw has no normal weapon actions; its grab is
        -- a Pactsworn character state. Graft only temporary hero attacks while
        -- preserving the native claw template and articulated linking.
        template.actions = deep_clone(melee_actions.actions)
        Weapons[M.TEMPLATE_NAMES.slot_melee] = template
    end

    if not rawget(Weapons, M.TEMPLATE_NAMES.slot_ranged) then
        local template = deep_clone(ranged_source)

        if not sanitize_warpfire_template(template) then
            return false
        end

        Weapons[M.TEMPLATE_NAMES.slot_ranged] = template
    end

    state.templates_registered = true

    return true
end

local function item_definitions(registry)
    local packmaster_item = resolve_versus_item("slot_melee")
    local warpfire_item = resolve_versus_item("slot_ranged")

    if not packmaster_item or not warpfire_item then
        return nil
    end

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
            right_hand_unit = packmaster_item.right_hand_unit,
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
            name = M.ITEM_KEYS.slot_ranged,
            property_table_name = "ranged",
            rarity = "plentiful",
            left_hand_unit = warpfire_item.left_hand_unit,
            slot_type = "ranged",
            template = M.TEMPLATE_NAMES.slot_ranged,
            trait_table_name = "ranged_heat",
        },
    }
end

local function action_hand_contract_ready(item_data, template)
    if not item_data or not template or type(template.actions) ~= "table" then
        return false
    end

    for _, sub_actions in pairs(template.actions) do
        if type(sub_actions) == "table" then
            for _, action in pairs(sub_actions) do
                if type(action) == "table" then
                    local hand = action.weapon_action_hand or "right"
                    local has_right = item_data.right_hand_unit ~= nil
                    local has_left = item_data.left_hand_unit ~= nil

                    if hand == "right" and not has_right
                            or hand == "left" and not has_left
                            or hand == "both" and (not has_right or not has_left)
                            or hand == "either" and not has_right and not has_left then
                        return false
                    end
                end
            end
        end
    end

    return true
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

    if not definitions then
        return false
    end

    local hand_contract_ready = true

    for _, slot_name in ipairs({ "slot_melee", "slot_ranged" }) do
        local item_key = M.ITEM_KEYS[slot_name]
        local item_data = rawget(ItemMasterList, item_key)

        if not item_data then
            item_data = definitions[item_key]
            ItemMasterList[item_key] = item_data
        end

        append_lookup(NetworkLookup.item_names, item_key)
        append_lookup(NetworkLookup.damage_sources, item_key)
        hand_contract_ready = hand_contract_ready and action_hand_contract_ready(
            item_data, Weapons[M.TEMPLATE_NAMES[slot_name]])
        state.backend_items[M.BACKEND_IDS[slot_name]] = make_backend_item(
            item_key, M.BACKEND_IDS[slot_name], item_data)
    end

    state.hand_contract_ready = hand_contract_ready
    state.lookups_registered = true
    state.masterlist_registered = true

    return true
end

function M.install(registry)
    local templates_ready = register_templates()
    local items_ready = templates_ready and register_items(registry)

    state.installed = templates_ready and items_ready

    if state.installed then
        mod:info("[pusfume] registered Pusfume-only Versus weapons melee=%s unit=%s ranged=%s unit=%s hand_contract=%s",
            M.ITEM_KEYS.slot_melee, M.UNIT_PATHS.slot_melee,
            M.ITEM_KEYS.slot_ranged, M.UNIT_PATHS.slot_ranged,
            tostring(state.hand_contract_ready))
    else
        mod:warning("[pusfume] Pusfume weapon dependencies are not ready; registration deferred")
    end

    return state.installed
end

function M.action_hand_contract_ready(item_data, template)
    return action_hand_contract_ready(item_data, template)
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
