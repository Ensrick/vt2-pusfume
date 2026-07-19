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
    target_adapter_installed = false,
    warpfire_action_adapter_installed = false,
}

local installed_registry

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

    -- is_climbing belongs to the playable-Pactsworn status extension. Pusfume
    -- keeps the ordinary hero extension in Adventure, where that method is
    -- intentionally absent.
    if status_extension and type(status_extension.is_climbing) == "function"
            and status_extension:is_climbing() then
        return false
    end

    local overcharge_extension = ScriptUnit.has_extension(action_user, "overcharge_system")

    return overcharge_extension
        and type(overcharge_extension.get_overcharge_value) == "function"
        and overcharge_extension:get_overcharge_value() <= 0
end

local function hero_warpfire_reload_condition(action_user)
    local overcharge_extension = ScriptUnit.has_extension(action_user, "overcharge_system")

    return overcharge_extension
        and type(overcharge_extension.get_overcharge_value) == "function"
        and overcharge_extension:get_overcharge_value() > 0
end


local function rewrite_chain_inputs(sub_actions, old_action, new_action, old_hold, new_hold)
    for _, action in pairs(sub_actions or {}) do
        if type(action) == "table" then
            if action.hold_input == old_hold then
                action.hold_input = new_hold
            end

            for _, chain in ipairs(action.allowed_chain_actions or {}) do
                if chain.action == old_action then
                    chain.action = new_action
                end
                if chain.input == old_action then
                    chain.input = new_action
                end
                if chain.input == old_hold then
                    chain.input = new_hold
                end
            end
        end
    end
end

local function adapt_warpfire_template(template)
    local action_one = template.actions and template.actions.dark_pact_action_one
    local action_reload = template.actions and template.actions.dark_pact_reload

    if not action_one or not action_one.default or not action_one.fire
            or not action_reload or not action_reload.default then
        return false
    end

    -- Preserve Fatshark's Warpfire action class, heat, damage and synchronized
    -- shooting/cooling states. Only translate Pactsworn inputs and remove the
    -- priming VCE callback, whose manager does not exist in Adventure.
    action_one.default.condition_func = hero_warpfire_condition
    action_reload.default.condition_func = hero_warpfire_reload_condition
    action_reload.default.chain_condition_func = hero_warpfire_reload_condition

    rewrite_chain_inputs(action_one, "dark_pact_action_one", "action_one",
        "dark_pact_action_one_hold", "action_one_hold")
    rewrite_chain_inputs(action_one, "dark_pact_reload", "weapon_reload",
        "dark_pact_reload_hold", "weapon_reload_hold")
    rewrite_chain_inputs(action_reload, "dark_pact_action_one", "action_one",
        "dark_pact_action_one_hold", "action_one_hold")
    rewrite_chain_inputs(action_reload, "dark_pact_reload", "weapon_reload",
        "dark_pact_reload_hold", "weapon_reload_hold")

    template.actions.action_one = action_one
    template.actions.weapon_reload = action_reload
    template.actions.dark_pact_action_one = nil
    template.actions.dark_pact_reload = nil

    if template.synced_states and template.synced_states.priming then
        template.synced_states.priming.enter = nil
    end

    return true
end

local PACKMASTER_UNSAFE_HIT_ANIMATION_FIELDS = {
    "dual_hit_stop_anims",
    "first_person_hit_anim",
    "hit_armor_anim",
    "hit_shield_stop_anim",
    "hit_stop_anim",
    "hit_stop_kill_anim",
}

local function sanitize_packmaster_melee_actions(actions)
    local removed = 0

    for _, sub_actions in pairs(actions or {}) do
        if type(sub_actions) == "table" then
            for _, action in pairs(sub_actions) do
                if type(action) == "table" then
                    for _, field_name in ipairs(PACKMASTER_UNSAFE_HIT_ANIMATION_FIELDS) do
                        if action[field_name] ~= nil then
                            action[field_name] = nil
                            removed = removed + 1
                        end
                    end
                end
            end
        end
    end

    return removed
end

local function add_packmaster_weapon_events(actions)
    local wrapped = 0

    for _, sub_actions in pairs(actions or {}) do
        if type(sub_actions) == "table" then
            for _, action in pairs(sub_actions) do
                if type(action) == "table" and action.kind == "sweep"
                        and not action.pusfume_packmaster_event then
                    local original_enter = action.enter_function

                    action.enter_function = function(owner_unit, ...)
                        if original_enter then
                            original_enter(owner_unit, ...)
                        end

                        local inventory_system = Managers.state.entity:system("inventory_system")

                        if inventory_system then
                            inventory_system:weapon_anim_event(owner_unit, "attack_grab")
                        end
                    end
                    action.pusfume_packmaster_event = true
                    wrapped = wrapped + 1
                end
            end
        end
    end

    return wrapped
end

local function is_pusfume_unit(unit)
    if not installed_registry or not Unit.alive(unit) then
        return false
    end

    local career_extension = ScriptUnit.has_extension(unit, "career_system")

    return career_extension
        and type(career_extension.career_name) == "function"
        and career_extension:career_name() == installed_registry.CAREER_NAME
end

local function pusfume_warpfire_targets(player_unit, first_person_unit, physics_world)
    local side_manager = Managers.state.side
    local side = side_manager and side_manager.side_by_unit[player_unit]
    local enemy_units = side and side:enemy_units()

    if not enemy_units then
        return nil
    end

    local origin = POSITION_LOOKUP[first_person_unit]
        or Unit.world_position(first_person_unit, 0)
    local rotation = Unit.world_rotation(first_person_unit, 0)
    local direction = Vector3.normalize(Quaternion.forward(rotation))
    local targets = {}

    for _, target_unit in ipairs(enemy_units) do
        if Unit.alive(target_unit) and DamageUtils.is_enemy(player_unit, target_unit) then
            local node = Unit.has_node(target_unit, "c_spine")
                and Unit.node(target_unit, "c_spine") or 0
            local target_position = POSITION_LOOKUP[target_unit]
                or Unit.world_position(target_unit, node)
            local offset = target_position - origin
            local distance = Vector3.length(offset)

            if distance > 0 and distance <= 10 then
                local target_direction = Vector3.normalize(offset)
                local in_cone = Vector3.dot(direction, target_direction) >= 0.75
                local in_los = in_cone and PerceptionUtils.is_position_in_line_of_sight(
                    player_unit, origin, target_position, physics_world,
                    "filter_ai_line_of_sight_check")

                if in_los then
                    targets[#targets + 1] = {
                        unit = target_unit,
                        distance = distance,
                    }
                end
            end
        end
    end

    return #targets > 0 and targets or nil
end

local function install_target_adapter()
    if state.target_adapter_installed or not EnemyCharacterStateHelper then
        return state.target_adapter_installed
    end

    mod:hook(EnemyCharacterStateHelper, "get_enemies_in_line_of_sight",
        function(func, player_unit, first_person_unit, physics_world, ...)
            if is_pusfume_unit(player_unit) then
                return pusfume_warpfire_targets(
                    player_unit, first_person_unit, physics_world)
            end

            return func(player_unit, first_person_unit, physics_world, ...)
        end)

    state.target_adapter_installed = true

    return true
end

local function install_warpfire_action_adapter()
    if state.warpfire_action_adapter_installed or not ActionWarpfireThrower then
        return state.warpfire_action_adapter_installed
    end

    mod:hook(ActionWarpfireThrower, "fire", function(func, self, owner_unit,
            current_action, t)
        if not is_pusfume_unit(owner_unit) then
            return func(self, owner_unit, current_action, t)
        end

        local targets = EnemyCharacterStateHelper.get_enemies_in_line_of_sight(
            owner_unit, self.first_person_unit, self.physics_world)

        for _, target in ipairs(targets or {}) do
            local target_position = POSITION_LOOKUP[target.unit]
                or Unit.world_position(target.unit, 0)
            local owner_position = POSITION_LOOKUP[owner_unit]
                or Unit.world_position(owner_unit, 0)
            local attack_direction = Vector3.normalize(target_position - owner_position)

            DamageUtils.add_damage_network(target.unit, owner_unit, 2, "torso",
                "warpfire_ground", nil, attack_direction,
                M.ITEM_KEYS.slot_ranged, nil, nil, nil, nil, nil, nil, nil,
                nil, nil, nil, 1)
        end
    end)

    state.warpfire_action_adapter_installed = true

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
        state.melee_animation_fields_sanitized =
            (state.melee_animation_fields_sanitized or 0)
            + sanitize_packmaster_melee_actions(template.actions)
        state.melee_actions_wrapped = add_packmaster_weapon_events(template.actions)
        Weapons[M.TEMPLATE_NAMES.slot_melee] = template
    else
        -- Hot reloads can retain the previous template table. Sanitize it in
        -- place so an unsafe hero hit event cannot survive a code refresh.
        state.melee_animation_fields_sanitized =
            (state.melee_animation_fields_sanitized or 0)
            + sanitize_packmaster_melee_actions(
                Weapons[M.TEMPLATE_NAMES.slot_melee].actions)
        state.melee_actions_wrapped = add_packmaster_weapon_events(
            Weapons[M.TEMPLATE_NAMES.slot_melee].actions)
    end

    local installed_ranged = rawget(Weapons, M.TEMPLATE_NAMES.slot_ranged)

    if not installed_ranged or not installed_ranged.actions
            or not installed_ranged.actions.action_one
            or not installed_ranged.synced_states then
        local template = deep_clone(ranged_source)

        if not adapt_warpfire_template(template) then
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

    -- Start from Fatshark's complete records so future Pusfume variants retain
    -- every native unit and presentation field. Only ownership, identity, the
    -- Adventure slot adapter, and our isolated templates differ from Versus.
    local melee = deep_clone(packmaster_item)
    melee.can_wield = { registry.CAREER_NAME }
    melee.description = "pusfume_packmaster_hook_description"
    melee.display_name = "pusfume_packmaster_hook_name"
    melee.mechanisms = nil
    melee.name = M.ITEM_KEYS.slot_melee
    melee.source_item = M.VERSUS_ITEM_KEYS.slot_melee
    melee.template = M.TEMPLATE_NAMES.slot_melee

    local ranged = deep_clone(warpfire_item)
    ranged.can_wield = { registry.CAREER_NAME }
    ranged.description = "pusfume_warpfire_thrower_description"
    ranged.display_name = "pusfume_warpfire_thrower_name"
    ranged.mechanisms = nil
    ranged.name = M.ITEM_KEYS.slot_ranged
    ranged.property_table_name = "ranged"
    ranged.slot_type = "ranged"
    ranged.source_item = M.VERSUS_ITEM_KEYS.slot_ranged
    ranged.template = M.TEMPLATE_NAMES.slot_ranged
    ranged.trait_table_name = "ranged_heat"

    return {
        [M.ITEM_KEYS.slot_melee] = melee,
        [M.ITEM_KEYS.slot_ranged] = ranged,
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
    installed_registry = registry
    local templates_ready = register_templates()
    local items_ready = templates_ready and register_items(registry)
    local target_adapter_ready = install_target_adapter()
    local action_adapter_ready = install_warpfire_action_adapter()

    state.installed = templates_ready and items_ready and target_adapter_ready
        and action_adapter_ready

    if state.installed then
        mod:info("[pusfume] registered Pusfume-only Versus weapons melee=%s unit=%s ranged=%s unit=%s hand_contract=%s sanitized_melee_hit_events=%d claw_actions=%d adventure_target_adapter=%s action_adapter=%s",
            M.ITEM_KEYS.slot_melee, M.UNIT_PATHS.slot_melee,
            M.ITEM_KEYS.slot_ranged, M.UNIT_PATHS.slot_ranged,
            tostring(state.hand_contract_ready),
            state.melee_animation_fields_sanitized or 0,
            state.melee_actions_wrapped or 0,
            tostring(state.target_adapter_installed),
            tostring(state.warpfire_action_adapter_installed))
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
