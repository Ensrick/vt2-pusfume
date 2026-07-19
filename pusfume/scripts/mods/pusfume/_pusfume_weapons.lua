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
M.MELEE_VARIANTS = {
    packmaster_hook = {
        backend_id = "pusfume_item_packmaster_hook_v1",
        description = "pusfume_packmaster_hook_description",
        display_name = "pusfume_packmaster_hook_name",
        item_key = "pusfume_packmaster_hook",
        source_item = "vs_packmaster_claw",
        template_name = "pusfume_packmaster_hook_template",
    },
    assassin_claws = {
        backend_id = "pusfume_item_assassin_claws_v1",
        description = "pusfume_assassin_claws_description",
        display_name = "pusfume_assassin_claws_name",
        item_key = "pusfume_assassin_claws",
        source_item = "vs_gutter_runner_claws",
        template_name = "pusfume_assassin_claws_template",
    },
}
M.MELEE_VARIANT_ORDER = {
    "packmaster_hook",
    "assassin_claws",
}
M.RANGED_VARIANTS = {
    warpfire_thrower = {
        backend_id = "pusfume_item_warpfire_thrower_v1",
        description = "pusfume_warpfire_thrower_description",
        display_name = "pusfume_warpfire_thrower_name",
        item_key = "pusfume_warpfire_thrower",
        source_item = "vs_warpfire_thrower_gun",
        template_name = "pusfume_warpfire_thrower_template",
    },
    ratling_gun = {
        backend_id = "pusfume_item_ratling_gun_v1",
        description = "pusfume_ratling_gun_description",
        display_name = "pusfume_ratling_gun_name",
        item_key = "pusfume_ratling_gun",
        source_item = "vs_ratling_gunner_gun",
        template_name = "pusfume_ratling_gun_template",
    },
    poison_wind_globe = {
        backend_id = "pusfume_item_poison_wind_globe_v1",
        description = "pusfume_poison_wind_globe_description",
        display_name = "pusfume_poison_wind_globe_name",
        item_key = "pusfume_poison_wind_globe",
        source_item = "vs_poison_wind_globadier_orb",
        template_name = "pusfume_poison_wind_globe_template",
    },
    crossbow = {
        backend_id = "pusfume_item_crossbow_v1",
        description = "pusfume_crossbow_description",
        display_name = "pusfume_crossbow_name",
        item_key = "pusfume_crossbow",
        source_item = "dr_crossbow",
        template_name = "pusfume_crossbow_template",
    },
}
M.RANGED_VARIANT_ORDER = {
    "warpfire_thrower",
    "ratling_gun",
    "poison_wind_globe",
    "crossbow",
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
    ratling_audio_adapter_installed = false,
    selected_backend_ids = {
        slot_melee = "pusfume_item_packmaster_hook_v1",
        slot_ranged = "pusfume_item_warpfire_thrower_v1",
    },
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

local function bind_action_lookup_data(sub_actions, action_name)
    for sub_action_name, action in pairs(sub_actions or {}) do
        if type(action) == "table" then
            action.lookup_data = action.lookup_data or {}
            action.lookup_data.action_name = action_name
            action.lookup_data.sub_action_name = sub_action_name
        end
    end
end

local function validate_action_graph(actions)
    for action_name, sub_actions in pairs(actions or {}) do
        if type(sub_actions) == "table" then
            for sub_action_name, action in pairs(sub_actions) do
                if type(action) == "table" then
                    for _, chain in ipairs(action.allowed_chain_actions or {}) do
                        local target_name = chain.action

                        if target_name then
                            local target = actions[target_name]
                            local target_sub_action = chain.sub_action or "default"

                            if type(target) ~= "table"
                                    or type(target[target_sub_action]) ~= "table" then
                                return false, string.format(
                                    "%s.%s -> %s.%s",
                                    tostring(action_name), tostring(sub_action_name),
                                    tostring(target_name), tostring(target_sub_action))
                            end
                        end
                    end
                end
            end
        end
    end

    return true
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
    bind_action_lookup_data(action_one, "action_one")
    bind_action_lookup_data(action_reload, "weapon_reload")

    -- ActionWarpfireThrower retains native Pactsworn transition names in its
    -- synchronized state. Keep independent compatibility aliases instead of
    -- deleting them; shared tables would corrupt lookup_data for one name.
    template.actions.dark_pact_action_one = deep_clone(action_one)
    template.actions.dark_pact_reload = deep_clone(action_reload)
    bind_action_lookup_data(
        template.actions.dark_pact_action_one, "dark_pact_action_one")
    bind_action_lookup_data(template.actions.dark_pact_reload, "dark_pact_reload")

    if template.synced_states and template.synced_states.priming then
        template.synced_states.priming.enter = nil
    end

    return true
end

local function hero_ratling_condition(action_user, input_extension, ammo_extension)
    local status_extension = ScriptUnit.has_extension(action_user, "status_system")

    if status_extension and type(status_extension.is_climbing) == "function"
            and status_extension:is_climbing() then
        return false
    end

    return not ammo_extension or ammo_extension:ammo_count() > 0
end

local function hero_ratling_reload_condition(action_user, input_extension, ammo_extension)
    local status_extension = ScriptUnit.has_extension(action_user, "status_system")

    if status_extension and type(status_extension.is_climbing) == "function"
            and status_extension:is_climbing() then
        return false
    end

    return ammo_extension and ammo_extension:can_reload()
end

local function adapt_ratling_template(template)
    local action_one = template.actions and template.actions.dark_pact_action_one
    local action_reload = template.actions and template.actions.dark_pact_reload
    local action_two = template.actions and template.actions.dark_pact_action_two

    if not action_one or not action_one.default or not action_one.fire
            or not action_reload or not action_reload.default
            or not action_two or not action_two.default then
        return false
    end

    action_one.default.condition_func = hero_ratling_condition
    action_one.fire.chain_condition_func = hero_ratling_condition
    action_reload.default.condition_func = hero_ratling_reload_condition
    action_reload.default.chain_condition_func = hero_ratling_reload_condition
    action_one.fire.lightweight_projectile_info.collision_filter =
        "filter_player_ray_projectile"

    for _, actions in ipairs({ action_one, action_reload, action_two }) do
        rewrite_chain_inputs(actions, "dark_pact_action_one", "action_one",
            "dark_pact_action_one_hold", "action_one_hold")
        rewrite_chain_inputs(actions, "dark_pact_reload", "weapon_reload",
            "dark_pact_reload_hold", "weapon_reload_hold")
        rewrite_chain_inputs(actions, "dark_pact_action_two", "action_two",
            "dark_pact_action_two_hold", "action_two_hold")
    end

    template.actions.action_one = action_one
    template.actions.weapon_reload = action_reload
    template.actions.action_two = action_two
    bind_action_lookup_data(action_one, "action_one")
    bind_action_lookup_data(action_reload, "weapon_reload")
    bind_action_lookup_data(action_two, "action_two")

    template.actions.dark_pact_action_one = deep_clone(action_one)
    template.actions.dark_pact_reload = deep_clone(action_reload)
    template.actions.dark_pact_action_two = deep_clone(action_two)
    bind_action_lookup_data(template.actions.dark_pact_action_one,
        "dark_pact_action_one")
    bind_action_lookup_data(template.actions.dark_pact_reload,
        "dark_pact_reload")
    bind_action_lookup_data(template.actions.dark_pact_action_two,
        "dark_pact_action_two")

    -- Versus state callbacks depend on VCE and a Pactsworn "fire" career
    -- ability. The weapon actions retain their native spin, ammo and
    -- projectile behavior; empty synchronized callbacks keep network state
    -- transitions valid without invoking those unavailable managers.
    for _, synced_state in pairs(template.synced_states or {}) do
        synced_state.enter = nil
        synced_state.update = nil
        synced_state.leave = nil
    end

    template.pusfume_role_pose = "to_ratling_gunner"

    -- The Versus Ratling gun is intentionally inexhaustible. Adventure ammo
    -- pickups only recognize finite ranged weapons, so keep one 120-round
    -- hopper and let ordinary ammo boxes refill it directly.
    template.ammo_data.infinite_ammo = false
    template.ammo_data.starting_reserve_ammo = 0

    return true
end

local function throw_poison_wind_globe(owner_unit)
    local first_person_extension = ScriptUnit.has_extension(
        owner_unit, "first_person_system")
    local first_person_unit = first_person_extension
        and first_person_extension:get_first_person_unit()

    if not first_person_unit or not Unit.alive(first_person_unit) then
        return
    end

    CharacterStateHelper.play_animation_event(owner_unit, "globe_throw")
    CharacterStateHelper.play_animation_event_first_person(
        first_person_extension, "globe_throw")

    local rotation = Unit.world_rotation(first_person_unit, 0)
    local angle = ActionUtils.pitch_from_rotation(rotation)
    local direction = Vector3.normalize(
        Vector3.flat(Quaternion.forward(rotation)) + Vector3(0, 0, 0.2))
    local node = Unit.has_node(first_person_unit, "j_rightweaponattach")
        and Unit.node(first_person_unit, "j_rightweaponattach") or 0
    local position = Unit.world_position(first_person_unit, node)
    local projectile_system = Managers.state.entity:system("projectile_system")

    if projectile_system then
        projectile_system:spawn_globadier_globe(
            position, direction, angle, 1600, 3.5, 4.5, 6,
            owner_unit, M.RANGED_VARIANTS.poison_wind_globe.item_key,
            3, 5, 1, true, false)
    end
end

local function create_globadier_template(source_template)
    local template = deep_clone(source_template)

    template.actions = {
        action_one = {
            default = {
                anim_event = "globe_throw",
                anim_event_1p = "globe_throw",
                kind = "dummy",
                total_time = 0.9,
                weapon_action_hand = "right",
                enter_function = function(owner_unit, input_extension)
                    input_extension:clear_input_buffer()
                    input_extension:reset_release_input()
                    throw_poison_wind_globe(owner_unit)
                end,
                allowed_chain_actions = {
                    {
                        action = "action_one",
                        input = "action_one",
                        start_time = 0.8,
                        sub_action = "default",
                    },
                    {
                        action = "action_wield",
                        input = "action_wield",
                        start_time = 0.2,
                        sub_action = "default",
                    },
                },
            },
        },
        action_wield = deep_clone(ActionTemplates.wield),
    }
    bind_action_lookup_data(template.actions.action_one, "action_one")
    template.buff_type = "RANGED"
    template.crosshair_style = "dot"
    template.pusfume_role_pose = "to_globadier"
    template.weapon_type = "THROWING_AXE"
    template.wield_anim = "idle"

    return template
end

local function sanitize_placeholder_animation_events(actions)
    local sanitized = 0

    for _, sub_actions in pairs(actions or {}) do
        if type(sub_actions) == "table" then
            for _, action in pairs(sub_actions) do
                if type(action) == "table" then
                    for field_name, value in pairs(action) do
                        if type(field_name) == "string" and type(value) == "string"
                                and string.find(field_name, "anim", 1, true)
                                and string.find(field_name, "event", 1, true) then
                            action[field_name] = "idle"
                            sanitized = sanitized + 1
                        end
                    end
                end
            end
        end
    end

    return sanitized
end

local PACKMASTER_UNSAFE_HIT_ANIMATION_FIELDS = {
    "dual_hit_stop_anims",
    "first_person_hit_anim",
    "hit_armor_anim",
    "hit_shield_stop_anim",
    "hit_stop_anim",
    "hit_stop_kill_anim",
}

local function packmaster_hook_target(owner_unit)
    local side_manager = Managers.state.side
    local side = side_manager and side_manager.side_by_unit[owner_unit]
    local enemy_units = side and side:enemy_units()

    if not enemy_units then
        return nil
    end

    local first_person_extension = ScriptUnit.has_extension(
        owner_unit, "first_person_system")
    local first_person_unit = first_person_extension
        and first_person_extension:get_first_person_unit()
    local origin_unit = first_person_unit or owner_unit
    local origin = POSITION_LOOKUP[origin_unit]
        or Unit.world_position(origin_unit, 0)
    local direction = Quaternion.forward(Unit.world_rotation(origin_unit, 0))
    local best_target
    local best_dot = 0.9

    for _, target_unit in ipairs(enemy_units) do
        if Unit.alive(target_unit) and DamageUtils.is_enemy(owner_unit, target_unit) then
            local target_position = POSITION_LOOKUP[target_unit]
                or Unit.world_position(target_unit, 0)
            local offset = target_position - origin
            local distance = Vector3.length(offset)
            local dot = distance > 0
                and Vector3.dot(direction, Vector3.normalize(offset)) or -1

            if distance <= 4.5 and dot > best_dot then
                best_target = target_unit
                best_dot = dot
            end
        end
    end

    return best_target
end

local function strike_with_packmaster_hook(owner_unit)
    local target_unit = packmaster_hook_target(owner_unit)

    if not target_unit then
        return false
    end

    local target_position = POSITION_LOOKUP[target_unit]
        or Unit.world_position(target_unit, 0)
    local owner_position = POSITION_LOOKUP[owner_unit]
        or Unit.world_position(owner_unit, 0)
    local attack_direction = Vector3.normalize(target_position - owner_position)

    DamageUtils.add_damage_network(target_unit, owner_unit, 15, "torso",
        "light_slashing_smiter_pull", nil, attack_direction,
        M.ITEM_KEYS.slot_melee, nil, nil, nil, nil, nil, nil, nil,
        nil, nil, nil, 1)
    mod:info("[pusfume] Packmaster hook pull target=%s range=4.5 profile=light_slashing_smiter_pull",
        tostring(target_unit))

    return true
end

local sanitize_packmaster_melee_actions

local function prepare_assassin_claw_actions(actions)
    local posed = 0

    sanitize_packmaster_melee_actions(actions)

    for _, sub_actions in pairs(actions or {}) do
        if type(sub_actions) == "table" then
            for _, action in pairs(sub_actions) do
                if type(action) == "table"
                        and (action.kind == "melee_start" or action.kind == "sweep") then
                    -- jump_start/attack_finished are native Gutter Runner 1P
                    -- events; the Elf dagger event names are not present on
                    -- the shared Skaven first-person controller.
                    action.anim_event_1p = "jump_start"
                    action.anim_end_event_1p = "attack_finished"
                    posed = posed + 1
                end
            end
        end
    end

    return posed
end

sanitize_packmaster_melee_actions = function(actions)
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
    local posed = 0

    for _, sub_actions in pairs(actions or {}) do
        if type(sub_actions) == "table" then
            for _, action in pairs(sub_actions) do
                if type(action) == "table"
                        and (action.kind == "melee_start" or action.kind == "sweep") then
                    action.anim_event_1p = "attack_grab"
                    posed = posed + 1
                end

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

                        strike_with_packmaster_hook(owner_unit)
                    end
                    action.pusfume_packmaster_event = true
                    wrapped = wrapped + 1
                end
            end
        end
    end

    return wrapped, posed
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

local function install_ratling_audio_adapter()
    if state.ratling_audio_adapter_installed or not ActionMinigun then
        return state.ratling_audio_adapter_installed
    end

    -- ActionMinigun treats every spin-up as a hero career activation. On the
    -- shared Bardin profile that produces a Bardin ability bark even after the
    -- unit-level Skaven Wwise switches are set.
    mod:hook(ActionMinigun, "_play_vo", function(func, action)
        if is_pusfume_unit(action.owner_unit) then
            return
        end

        return func(action)
    end)
    state.ratling_audio_adapter_installed = true

    return true
end

local function register_templates()
    local melee_source = Weapons and Weapons.vs_packmaster_claw
    local melee_actions = Weapons and Weapons.two_handed_axes_template_1
    local assassin_source = Weapons and Weapons.vs_gutter_runner_claws
    local assassin_actions = Weapons and Weapons.dual_wield_daggers_template_1
    local ranged_source = Weapons and Weapons.vs_warpfire_thrower_gun
    local ratling_source = Weapons and Weapons.vs_ratling_gunner_gun
    local globadier_source = Weapons and Weapons.vs_poison_wind_globadier_orb
    local crossbow_source = Weapons and Weapons.crossbow_template_1

    if not melee_source or not melee_actions or not assassin_source
            or not assassin_actions or not ranged_source
            or not ratling_source or not globadier_source or not crossbow_source then
        return false
    end

    local assassin_definition = M.MELEE_VARIANTS.assassin_claws
    local installed_assassin = rawget(Weapons, assassin_definition.template_name)

    if not installed_assassin or not installed_assassin.actions
            or not installed_assassin.actions.action_one then
        local template = deep_clone(assassin_source)

        template.actions = deep_clone(assassin_actions.actions)
        template.wield_anim = "idle"
        template.pusfume_role_pose = "to_gutter_runner"
        state.assassin_pose_actions = prepare_assassin_claw_actions(template.actions)
        Weapons[assassin_definition.template_name] = template
    else
        installed_assassin.pusfume_role_pose = "to_gutter_runner"
        state.assassin_pose_actions = prepare_assassin_claw_actions(
            installed_assassin.actions)
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
        state.melee_actions_wrapped, state.melee_pose_actions =
            add_packmaster_weapon_events(template.actions)
        template.wield_anim = "idle"
        template.pusfume_role_pose = "to_packmaster"
        Weapons[M.TEMPLATE_NAMES.slot_melee] = template
    else
        -- Hot reloads can retain the previous template table. Sanitize it in
        -- place so an unsafe hero hit event cannot survive a code refresh.
        state.melee_animation_fields_sanitized =
            (state.melee_animation_fields_sanitized or 0)
            + sanitize_packmaster_melee_actions(
                Weapons[M.TEMPLATE_NAMES.slot_melee].actions)
        local installed_melee = Weapons[M.TEMPLATE_NAMES.slot_melee]
        state.melee_actions_wrapped, state.melee_pose_actions =
            add_packmaster_weapon_events(installed_melee.actions)
        installed_melee.wield_anim = "idle"
        installed_melee.pusfume_role_pose = "to_packmaster"
    end

    local installed_ranged = rawget(Weapons, M.TEMPLATE_NAMES.slot_ranged)

    if not installed_ranged or not installed_ranged.actions
            or not installed_ranged.actions.action_one
            or not installed_ranged.actions.dark_pact_action_one
            or not installed_ranged.actions.dark_pact_reload
            or not installed_ranged.synced_states then
        local template = deep_clone(ranged_source)

        if not adapt_warpfire_template(template) then
            return false
        end

        Weapons[M.TEMPLATE_NAMES.slot_ranged] = template
    end

    Weapons[M.TEMPLATE_NAMES.slot_ranged].pusfume_role_pose =
        "to_warpfire_thrower"

    local ratling_definition = M.RANGED_VARIANTS.ratling_gun
    local installed_ratling = rawget(Weapons, ratling_definition.template_name)

    if not installed_ratling or not installed_ratling.actions
            or not installed_ratling.actions.action_one
            or not installed_ratling.actions.dark_pact_action_one then
        local template = deep_clone(ratling_source)

        if not adapt_ratling_template(template) then
            return false
        end

        Weapons[ratling_definition.template_name] = template
    end

    local globe_definition = M.RANGED_VARIANTS.poison_wind_globe
    local installed_globe = rawget(Weapons, globe_definition.template_name)

    if not installed_globe or not installed_globe.actions
            or not installed_globe.actions.action_one then
        Weapons[globe_definition.template_name] =
            create_globadier_template(globadier_source)
    end

    local crossbow_definition = M.RANGED_VARIANTS.crossbow
    local installed_crossbow = rawget(Weapons, crossbow_definition.template_name)

    if not installed_crossbow or not installed_crossbow.actions
            or not installed_crossbow.actions.action_one then
        installed_crossbow = deep_clone(crossbow_source)
        Weapons[crossbow_definition.template_name] = installed_crossbow
    end

    -- The temporary crossbow keeps Bardin's projectile and ammo behavior but
    -- must never install his first-person controller on the native Skaven rig.
    -- Until Pusfume receives authored crossbow poses, use inert native events.
    installed_crossbow.state_machine = nil
    installed_crossbow.load_state_machine = false
    installed_crossbow.wield_anim = "idle"
    installed_crossbow.wield_anim_no_ammo = "idle"
    installed_crossbow.wield_anim_not_loaded = "idle"
    installed_crossbow.reload_event = "idle"
    installed_crossbow.pusfume_role_pose = "idle"
    state.crossbow_animation_fields_sanitized =
        sanitize_placeholder_animation_events(installed_crossbow.actions)

    local melee_graph_ready, melee_graph_error = validate_action_graph(
        Weapons[M.TEMPLATE_NAMES.slot_melee].actions)
    local ranged_graph_ready, ranged_graph_error = validate_action_graph(
        Weapons[M.TEMPLATE_NAMES.slot_ranged].actions)
    local ratling_graph_ready, ratling_graph_error = validate_action_graph(
        Weapons[ratling_definition.template_name].actions)
    local globe_graph_ready, globe_graph_error = validate_action_graph(
        Weapons[globe_definition.template_name].actions)
    local assassin_graph_ready, assassin_graph_error = validate_action_graph(
        Weapons[assassin_definition.template_name].actions)
    local crossbow_graph_ready, crossbow_graph_error = validate_action_graph(
        Weapons[crossbow_definition.template_name].actions)

    state.action_graph_ready = melee_graph_ready and ranged_graph_ready
        and ratling_graph_ready and globe_graph_ready and assassin_graph_ready
        and crossbow_graph_ready
    state.action_graph_error = melee_graph_error or ranged_graph_error
        or ratling_graph_error or globe_graph_error or assassin_graph_error
        or crossbow_graph_error

    if not state.action_graph_ready then
        mod:error("[pusfume] Invalid weapon action graph: %s",
            tostring(state.action_graph_error))
        return false
    end

    state.templates_registered = true

    return true
end

local function item_definitions(registry)
    local packmaster_item = resolve_versus_item("slot_melee")
    local warpfire_item = resolve_versus_item("slot_ranged")
    local melee_source_items = {}
    local ranged_source_items = {}

    for _, variant_name in ipairs(M.MELEE_VARIANT_ORDER) do
        local definition = M.MELEE_VARIANTS[variant_name]

        melee_source_items[variant_name] = ItemMasterList
            and rawget(ItemMasterList, definition.source_item)
    end

    for _, variant_name in ipairs(M.RANGED_VARIANT_ORDER) do
        local definition = M.RANGED_VARIANTS[variant_name]

        ranged_source_items[variant_name] = variant_name == "warpfire_thrower"
            and warpfire_item or ItemMasterList
            and rawget(ItemMasterList, definition.source_item)
    end

    if not packmaster_item or not warpfire_item
            or not melee_source_items.assassin_claws
            or not ranged_source_items.warpfire_thrower
            or not ranged_source_items.ratling_gun
            or not ranged_source_items.poison_wind_globe
            or not ranged_source_items.crossbow then
        return nil
    end

    -- Start from Fatshark's complete records so future Pusfume variants retain
    -- every native unit and presentation field. Only ownership, identity, the
    -- Adventure slot adapter, and our isolated templates differ from Versus.
    local definitions = {}

    for _, variant_name in ipairs(M.MELEE_VARIANT_ORDER) do
        local definition = M.MELEE_VARIANTS[variant_name]
        local melee = deep_clone(melee_source_items[variant_name])

        melee.can_wield = { registry.CAREER_NAME }
        melee.description = definition.description
        melee.display_name = definition.display_name
        melee.mechanisms = nil
        melee.name = definition.item_key
        melee.property_table_name = "melee"
        melee.slot_type = "melee"
        melee.source_item = definition.source_item
        melee.template = definition.template_name
        melee.trait_table_name = "melee"
        definitions[definition.item_key] = melee
    end

    for _, variant_name in ipairs(M.RANGED_VARIANT_ORDER) do
        local definition = M.RANGED_VARIANTS[variant_name]
        local ranged = deep_clone(ranged_source_items[variant_name])

        ranged.can_wield = { registry.CAREER_NAME }
        ranged.description = definition.description
        ranged.display_name = definition.display_name
        ranged.mechanisms = nil
        ranged.name = definition.item_key
        ranged.property_table_name = "ranged"
        ranged.slot_type = "ranged"
        ranged.source_item = definition.source_item
        ranged.template = definition.template_name
        if variant_name == "warpfire_thrower" then
            ranged.trait_table_name = "ranged_heat"
        else
            ranged.trait_table_name = ranged.trait_table_name or "ranged"
        end
        definitions[definition.item_key] = ranged
    end

    return definitions
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

    local item_registrations = {}

    for _, variant_name in ipairs(M.MELEE_VARIANT_ORDER) do
        local definition = M.MELEE_VARIANTS[variant_name]

        item_registrations[#item_registrations + 1] = {
            backend_id = definition.backend_id,
            item_key = definition.item_key,
            slot_name = "slot_melee",
            template_name = definition.template_name,
        }
    end

    for _, variant_name in ipairs(M.RANGED_VARIANT_ORDER) do
        local definition = M.RANGED_VARIANTS[variant_name]

        item_registrations[#item_registrations + 1] = {
            backend_id = definition.backend_id,
            item_key = definition.item_key,
            slot_name = "slot_ranged",
            template_name = definition.template_name,
        }
    end

    for _, registration in ipairs(item_registrations) do
        local item_key = registration.item_key
        local item_data = rawget(ItemMasterList, item_key)

        if not item_data then
            item_data = definitions[item_key]
            ItemMasterList[item_key] = item_data
        end

        append_lookup(NetworkLookup.item_names, item_key)
        append_lookup(NetworkLookup.damage_sources, item_key)
        hand_contract_ready = hand_contract_ready and action_hand_contract_ready(
            item_data, Weapons[registration.template_name])
        state.backend_items[registration.backend_id] = make_backend_item(
            item_key, registration.backend_id, item_data)
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
    local ratling_audio_ready = install_ratling_audio_adapter()

    state.installed = templates_ready and items_ready and target_adapter_ready
        and action_adapter_ready and ratling_audio_ready

    if state.installed then
        mod:info("[pusfume] registered Pusfume-only rat weapons melee=%d ranged=%d default_melee=%s unit=%s default_ranged=%s unit=%s hand_contract=%s action_graph=%s sanitized_melee_hit_events=%d hook_actions=%d hook_pose_actions=%d assassin_pose_actions=%d adventure_target_adapter=%s action_adapter=%s ratling_audio_adapter=%s",
            #M.MELEE_VARIANT_ORDER, #M.RANGED_VARIANT_ORDER,
            M.ITEM_KEYS.slot_melee, M.UNIT_PATHS.slot_melee,
            M.ITEM_KEYS.slot_ranged, M.UNIT_PATHS.slot_ranged,
            tostring(state.hand_contract_ready),
            tostring(state.action_graph_ready),
            state.melee_animation_fields_sanitized or 0,
            state.melee_actions_wrapped or 0,
            state.melee_pose_actions or 0,
            state.assassin_pose_actions or 0,
            tostring(state.target_adapter_installed),
            tostring(state.warpfire_action_adapter_installed),
            tostring(state.ratling_audio_adapter_installed))
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
    return state.selected_backend_ids[slot_name] or M.BACKEND_IDS[slot_name]
end

function M.item_for_slot(slot_name)
    return state.backend_items[M.backend_id_for_slot(slot_name)]
end

function M.is_weapon_slot(slot_name)
    return slot_name == "slot_melee" or slot_name == "slot_ranged"
end

function M.allowed_backend_ids(slot_name)
    if slot_name == "slot_melee" then
        local result = {}

        for _, variant_name in ipairs(M.MELEE_VARIANT_ORDER) do
            result[#result + 1] = M.MELEE_VARIANTS[variant_name].backend_id
        end

        return result
    end

    if slot_name == "slot_ranged" then
        local result = {}

        for _, variant_name in ipairs(M.RANGED_VARIANT_ORDER) do
            result[#result + 1] = M.RANGED_VARIANTS[variant_name].backend_id
        end

        return result
    end

    return {}
end

function M.allowed_item_keys(slot_name)
    if slot_name == "slot_melee" then
        local result = {}

        for _, variant_name in ipairs(M.MELEE_VARIANT_ORDER) do
            result[#result + 1] = M.MELEE_VARIANTS[variant_name].item_key
        end

        return result
    end

    if slot_name == "slot_ranged" then
        local result = {}

        for _, variant_name in ipairs(M.RANGED_VARIANT_ORDER) do
            result[#result + 1] = M.RANGED_VARIANTS[variant_name].item_key
        end

        return result
    end

    return {}
end


function M.select_backend_id(slot_name, backend_id)
    for _, allowed_id in ipairs(M.allowed_backend_ids(slot_name)) do
        if backend_id == allowed_id then
            state.selected_backend_ids[slot_name] = backend_id
            mod:info("[pusfume] selected weapon slot=%s backend_id=%s",
                slot_name, backend_id)
            return true
        end
    end

    return false
end

function M.select_item_key(slot_name, item_key)
    for backend_id, item in pairs(state.backend_items) do
        if item and item.key == item_key then
            return M.select_backend_id(slot_name, backend_id)
        end
    end

    return false
end

function M.overlay_loadout(loadout)
    local result = type(loadout) == "table" and table.clone(loadout) or {}

    result.slot_melee = M.backend_id_for_slot("slot_melee")
    result.slot_ranged = M.backend_id_for_slot("slot_ranged")

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
