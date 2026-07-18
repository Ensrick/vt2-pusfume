local mod = get_mod("pusfume")

local M = {}

M.TEST_WEAPON_ORDER = {
    "packmaster_claw",
    "gutter_runner_claws",
    "poison_wind_globe",
    "ratling_gun",
    "warpfire_thrower",
    "rat_ogre_hands",
}

M.TEST_WEAPONS = {
    packmaster_claw = {
        backend_id = "pusfume_item_packmaster_claw_v1",
        description = "pusfume_packmaster_claw_description",
        display_name = "pusfume_packmaster_claw_name",
        hud_icon = "weapon_generic_icon_axe1h",
        inventory_icon = "icon_wpn_dw_axe_01_t1",
        item_key = "pusfume_packmaster_claw",
        item_type = "we_spear",
        right_hand_unit = "units/weapons/player/dark_pact/wpn_skaven_packmaster_claw/wpn_skaven_packmaster_claw",
        source_key = "vs_packmaster_claw",
        template_name = "pusfume_vs_packmaster_claw_template",
    },
    gutter_runner_claws = {
        backend_id = "pusfume_item_gutter_runner_claws_v1",
        description = "pusfume_gutter_runner_claws_description",
        display_name = "pusfume_gutter_runner_claws_name",
        hud_icon = "weapon_generic_icon_axe1h",
        inventory_icon = "icon_wpn_dw_axe_01_t1",
        item_key = "pusfume_gutter_runner_claws",
        item_type = "we_dual_wield_daggers",
        left_hand_unit = "units/weapons/player/dark_pact/wpn_skaven_gutter_runner_claws/wpn_left_claw",
        right_hand_unit = "units/weapons/player/dark_pact/wpn_skaven_gutter_runner_claws/wpn_right_claw",
        source_key = "vs_gutter_runner_claws",
        template_name = "pusfume_vs_gutter_runner_claws_template",
    },
    poison_wind_globe = {
        backend_id = "pusfume_item_poison_wind_globe_v1",
        description = "pusfume_poison_wind_globe_description",
        display_name = "pusfume_poison_wind_globe_name",
        hud_icon = "weapon_generic_icon_axe1h",
        inventory_icon = "icon_wpn_dw_axe_01_t1",
        item_key = "pusfume_poison_wind_globe",
        item_type = "dr_1h_axes",
        right_hand_unit = "units/weapons/player/dark_pact/wpn_poison_wind_globe/wpn_poison_wind_globe",
        source_key = "vs_poison_wind_globadier_orb",
        template_name = "pusfume_vs_poison_wind_globadier_orb_template",
    },
    ratling_gun = {
        backend_id = "pusfume_item_ratling_gun_v1",
        description = "pusfume_ratling_gun_description",
        display_name = "pusfume_ratling_gun_name",
        hud_icon = "weapon_generic_icon_axe1h",
        inventory_icon = "icon_wpn_dw_axe_01_t1",
        item_key = "pusfume_ratling_gun",
        item_type = "dr_drakegun",
        left_hand_unit = "units/weapons/player/dark_pact/wpn_skaven_ratlinggun/wpn_skaven_ratlinggun",
        source_key = "vs_ratling_gunner_gun",
        template_name = "pusfume_vs_ratling_gunner_gun_template",
    },
    warpfire_thrower = {
        backend_id = "pusfume_item_warpfire_thrower_v1",
        description = "pusfume_warpfire_thrower_description",
        display_name = "pusfume_warpfire_thrower_name",
        hud_icon = "weapon_generic_icon_axe1h",
        inventory_icon = "icon_wpn_dw_axe_01_t1",
        item_key = "pusfume_warpfire_thrower",
        item_type = "dr_drakegun",
        left_hand_unit = "units/weapons/player/dark_pact/wpn_skaven_warpfiregun/wpn_skaven_warpfiregun",
        source_key = "vs_warpfire_thrower_gun",
        template_name = "pusfume_vs_warpfire_thrower_gun_template",
    },
    rat_ogre_hands = {
        backend_id = "pusfume_item_rat_ogre_hands_v1",
        description = "pusfume_rat_ogre_hands_description",
        display_name = "pusfume_rat_ogre_hands_name",
        hud_icon = "weapon_generic_icon_axe1h",
        inventory_icon = "icon_wpn_dw_axe_01_t1",
        item_key = "pusfume_rat_ogre_hands",
        item_type = "dr_1h_axes",
        left_hand_unit = "units/weapons/player/wpn_invisible_weapon",
        right_hand_unit = "units/weapons/player/wpn_invisible_weapon",
        source_key = "vs_rat_ogre_hands",
        template_name = "pusfume_vs_rat_ogre_hands_template",
    },
}

M.ITEM_KEYS = {}
M.BACKEND_IDS = {}
M.TEMPLATE_NAMES = {}
M.UNIT_PATHS = {}

local state = {
    backend_items = {},
    installed = false,
    lookups_registered = false,
    masterlist_registered = false,
    selected_test_weapon = "packmaster_claw",
    templates_registered = false,
    test_command_installed = false,
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
    if not Weapons or not AttachmentNodeLinking then
        return false
    end

    local source_modules = {
        "scripts/settings/dlcs/carousel/attachment_node_linking_vs",
        "scripts/settings/equipment/weapon_templates/vs_packmaster_claw",
        "scripts/settings/equipment/weapon_templates/vs_ratling_gunner_gun",
        "scripts/settings/equipment/weapon_templates/vs_warpfire_thrower_gun",
        "scripts/settings/equipment/weapon_templates/vs_rat_ogre_hands",
    }

    for _, module_name in ipairs(source_modules) do
        local ok, loaded = pcall(require, module_name)

        if ok and type(loaded) == "table" then
            for template_name, template in pairs(loaded) do
                if type(template_name) == "string" and type(template) == "table"
                        and not rawget(Weapons, template_name) then
                    Weapons[template_name] = template
                end
            end
        end
    end

    for _, key in ipairs(M.TEST_WEAPON_ORDER) do
        local definition = M.TEST_WEAPONS[key]
        local source_template = rawget(Weapons, definition.source_key)

        if not source_template then
            return false
        end

        if not rawget(Weapons, definition.template_name) then
            local template = deep_clone(source_template)

            template.pusfume_source_template = definition.source_key
            Weapons[definition.template_name] = template
        end
    end

    state.templates_registered = true

    return true
end

local function item_definitions(registry)
    local definitions = {}

    for _, key in ipairs(M.TEST_WEAPON_ORDER) do
        local definition = M.TEST_WEAPONS[key]
        local item = {
            can_wield = { registry.CAREER_NAME },
            description = definition.description,
            display_name = definition.display_name,
            has_power_level = true,
            hud_icon = definition.hud_icon,
            inventory_icon = definition.inventory_icon,
            item_type = definition.item_type,
            name = definition.item_key,
            property_table_name = "melee",
            rarity = "plentiful",
            right_hand_unit = definition.right_hand_unit,
            slot_type = "melee",
            template = definition.template_name,
            trait_table_name = "melee",
        }

        if definition.left_hand_unit then
            item.left_hand_unit = definition.left_hand_unit
        end

        definitions[definition.item_key] = item
    end

    return definitions
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

    for _, key in ipairs(M.TEST_WEAPON_ORDER) do
        local definition = M.TEST_WEAPONS[key]
        local item_key = definition.item_key
        local item_data = rawget(ItemMasterList, item_key)

        if not item_data then
            item_data = definitions[item_key]
            ItemMasterList[item_key] = item_data
        end

        append_lookup(NetworkLookup.item_names, item_key)
        append_lookup(NetworkLookup.damage_sources, item_key)
        state.backend_items[definition.backend_id] = make_backend_item(
            item_key, definition.backend_id, item_data)
    end

    state.lookups_registered = true
    state.masterlist_registered = true

    return true
end

local function refresh_slot_maps()
    local selected = M.TEST_WEAPONS[state.selected_test_weapon] or M.TEST_WEAPONS.packmaster_claw
    local ranged = M.TEST_WEAPONS.warpfire_thrower

    M.ITEM_KEYS.slot_melee = selected.item_key
    M.ITEM_KEYS.slot_ranged = ranged.item_key
    M.BACKEND_IDS.slot_melee = selected.backend_id
    M.BACKEND_IDS.slot_ranged = ranged.backend_id
    M.TEMPLATE_NAMES.slot_melee = selected.template_name
    M.TEMPLATE_NAMES.slot_ranged = ranged.template_name
    M.UNIT_PATHS.slot_melee = selected.right_hand_unit or selected.left_hand_unit
    M.UNIT_PATHS.slot_ranged = ranged.left_hand_unit or ranged.right_hand_unit
end

local function selected_weapon_index()
    for index, key in ipairs(M.TEST_WEAPON_ORDER) do
        if key == state.selected_test_weapon then
            return index
        end
    end

    return 1
end

local function install_test_command()
    if state.test_command_installed then
        return
    end

    mod:command("pusfume_weapon_test", "Select a Pusfume Versus-rat weapon clone.", function(key)
        if key == "next" or key == nil or key == "" then
            local next_index = selected_weapon_index() + 1

            if next_index > #M.TEST_WEAPON_ORDER then
                next_index = 1
            end

            key = M.TEST_WEAPON_ORDER[next_index]
        end

        if not M.TEST_WEAPONS[key] then
            mod:echo("Usage: /pusfume_weapon_test next|" .. table.concat(M.TEST_WEAPON_ORDER, "|"))
            return
        end

        state.selected_test_weapon = key
        refresh_slot_maps()
        mod:echo(string.format("Pusfume test weapon selected: %s",
            mod:localize(M.TEST_WEAPONS[key].display_name)))
        mod:info("[pusfume] selected Versus rat weapon clone=%s item=%s template=%s",
            key, M.ITEM_KEYS.slot_melee, M.TEMPLATE_NAMES.slot_melee)
    end)

    state.test_command_installed = true
end

function M.install(registry)
    refresh_slot_maps()
    local templates_ready = register_templates()
    local items_ready = templates_ready and register_items(registry)
    install_test_command()

    state.installed = templates_ready and items_ready

    if state.installed then
        mod:info("[pusfume] registered Pusfume-only Versus rat weapon clones selected=%s melee=%s ranged=%s",
            state.selected_test_weapon, M.ITEM_KEYS.slot_melee, M.ITEM_KEYS.slot_ranged)
    else
        mod:warning("[pusfume] Pusfume Versus rat weapon dependencies are not ready; registration deferred")
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
