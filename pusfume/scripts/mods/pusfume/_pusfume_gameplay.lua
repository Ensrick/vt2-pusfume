local mod = get_mod("pusfume")
local buff_perks = require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")

local M = {}

local CAREER_NAME = "pusfume"
local ACTIVE_COOLDOWN = 90
local iteration_effect_by_breed = {
    beastmen_standard_bearer = "wargor",
    chaos_corruptor_sorcerer = "lifeleech",
    chaos_vortex_sorcerer = "blightstormer",
    skaven_gutter_runner = "gutterrunner",
    skaven_loot_rat = "sackrat",
    skaven_pack_master = "packmaster",
    skaven_poison_wind_globadier = "gasrat",
    skaven_ratling_gunner = "ratling",
    skaven_warpfire_thrower = "warpfire_thrower",
}

local poison_damage_types = {
    arrow_poison = true,
    arrow_poison_dot = true,
    poison = true,
}
local poison_damage_sources = {
    aoe_poison_dot = true,
    poison_dot = true,
    skaven_poison_wind_globadier = true,
}
local state = {
    augmentation_activations = 0,
    augmentation_armed = false,
    installed = false,
    iteration_effect = nil,
    iteration_procs = 0,
    iteration_special = nil,
    poison_blocks = 0,
    scaredy_rat_procs = 0,
}

local function is_pusfume_unit(unit)
    if not unit or not Unit.alive(unit) then
        return false
    end

    local career_extension = ScriptUnit.has_extension(unit, "career_system")

    return career_extension and career_extension:career_name() == CAREER_NAME
end

local function append_lookup(lookup, name)
    local existing_index = rawget(lookup, name)

    if existing_index then
        return existing_index
    end

    local index = #lookup + 1

    rawset(lookup, index, name)
    rawset(lookup, name, index)

    return index
end


local function register_buff_template(name, definition)
    -- BuffUtils.copy_talent_buff_names performs this during vanilla boot.
    -- Runtime-added templates must reproduce it before BuffExtension indexes
    -- stacking state by sub-buff name.
    definition.name = name
    BuffTemplates[name] = {
        buffs = {
            definition,
        },
    }
    append_lookup(NetworkLookup.buff_templates, name)
end

local function add_networked_buff(owner_unit, buff_name)
    local entity_manager = Managers.state.entity
    local buff_system = entity_manager and entity_manager:system("buff_system")

    if not buff_system then
        return false
    end

    buff_system:add_buff(owner_unit, buff_name, owner_unit, false)

    return true
end


PassiveAbilityPusfumeAggressiveIteration = class(PassiveAbilityPusfumeAggressiveIteration)

PassiveAbilityPusfumeAggressiveIteration.init = function(self, extension_init_context, unit)
    self._owner_unit = unit
end

PassiveAbilityPusfumeAggressiveIteration.extensions_ready = function(self)
end

PassiveAbilityPusfumeAggressiveIteration.destroy = function(self)
    if is_pusfume_unit(self._owner_unit) then
        state.iteration_effect = nil
        state.iteration_special = nil
    end
end


CareerAbilityPusfumeIngenuity = class(CareerAbilityPusfumeIngenuity)

CareerAbilityPusfumeIngenuity.init = function(self, extension_init_context, unit, extension_init_data)
    self._owner_unit = unit
    self._local_player = extension_init_data.player.local_player
end

CareerAbilityPusfumeIngenuity.extensions_ready = function(self)
    self._career_extension = ScriptUnit.extension(self._owner_unit, "career_system")
    self._input_extension = ScriptUnit.has_extension(self._owner_unit, "input_system")
    self._status_extension = ScriptUnit.extension(self._owner_unit, "status_system")
end

CareerAbilityPusfumeIngenuity.destroy = function(self)
end

CareerAbilityPusfumeIngenuity.update = function(self)
    if not self._input_extension or not self._input_extension:get("action_career") then
        return
    end

    if not self._career_extension:can_use_activated_ability() or self._status_extension:is_disabled() then
        return
    end

    state.augmentation_activations = state.augmentation_activations + 1
    state.augmentation_armed = true
    self._career_extension:start_activated_ability_cooldown()

    if self._local_player then
        mod:echo(mod:localize("pusfume_ingenuity_armed_placeholder"))
    end

    mod:info("[pusfume] Moulder Ingenuity armed the next consumable selection")
end

CareerAbilityPusfumeIngenuity.stop = function(self)
end


local function register_buffs()
    fassert(type(ProcFunctions) == "table",
        "Pusfume requires VT2's ProcFunctions registry before gameplay registration.")
    fassert(type(BuffTemplates) == "table" and NetworkLookup and type(NetworkLookup.buff_templates) == "table",
        "Pusfume requires VT2's buff and network registries before gameplay registration.")

    ProcFunctions.pusfume_aggressive_iteration_proc = function(owner_unit, buff, params)
        if not Unit.alive(owner_unit) or not is_pusfume_unit(owner_unit) then
            return
        end

        local breed = params and params[2]

        if not breed or not breed.special then
            return
        end

        local breed_name = breed.name or "unknown_special"
        state.iteration_effect = iteration_effect_by_breed[breed_name]
        state.iteration_procs = state.iteration_procs + 1
        state.iteration_special = breed_name
        add_networked_buff(owner_unit, "pusfume_aggressive_iteration_ready")
        mod:info("[pusfume] Aggressive Iteration captured special=%s effect=%s",
            breed_name, tostring(state.iteration_effect or "unmapped"))
    end

    register_buff_template("pusfume_aggressive_iteration_listener", {
        event = "on_kill",
        event_buff = true,
        buff_func = "pusfume_aggressive_iteration_proc",
    })
    register_buff_template("pusfume_aggressive_iteration_ready", {
        icon = "bardin_ranger_passive",
        max_stacks = 1,
        refresh_durations = true,
    })
    register_buff_template("pusfume_scaredy_rat_listener", {
        perks = {
            buff_perks.no_moveslow_on_hit,
        },
    })
    register_buff_template("pusfume_scaredy_rat_speed", {
        apply_buff_func = "apply_movement_buff",
        duration = 3,
        max_stacks = 1,
        multiplier = 1.2,
        path_to_movement_setting_to_modify = { "move_speed" },
        refresh_durations = true,
        remove_buff_func = "remove_movement_buff",
    })
    register_buff_template("pusfume_swift_claws", {
        max_stacks = 1,
        multiplier = -0.15,
        stat_buff = "reload_speed",
    })
end


local function register_abilities()
    ActivatedAbilitySettings.pusfume = {
        {
            ability_class = CareerAbilityPusfumeIngenuity,
            cooldown = ACTIVE_COOLDOWN,
            description = "pusfume_active_description",
            display_name = "pusfume_active_name",
            icon = "bardin_ranger_activated_ability",
        },
    }
    PassiveAbilitySettings.pusfume = {
        buffs = {
            "pusfume_aggressive_iteration_listener",
            "pusfume_scaredy_rat_listener",
            "pusfume_swift_claws",
        },
        description = "pusfume_passive_description",
        display_name = "pusfume_passive_name",
        icon = "bardin_ranger_passive",
        passive_ability_classes = {
            {
                ability_class = PassiveAbilityPusfumeAggressiveIteration,
                name = "pusfume_aggressive_iteration",
            },
        },
        perks = {
            {
                description = "pusfume_hell_pit_native_description",
                display_name = "pusfume_hell_pit_native_name",
            },
            {
                description = "pusfume_scaredy_rat_description",
                display_name = "pusfume_scaredy_rat_name",
            },
            {
                description = "pusfume_swift_claws_description",
                display_name = "pusfume_swift_claws_name",
            },
        },
    }
end


local function install_damage_traits()
    mod:hook(PlayerUnitHealthExtension, "add_damage", function(func, health_extension, attacker_unit,
            damage_amount, hit_zone_name, damage_type, hit_position, damage_direction, damage_source_name,
            hit_ragdoll_actor, source_attacker_unit, hit_react_type, is_critical_strike, added_dot, first_hit,
            total_hits, attack_type, backstab_multiplier, target_index)
        if is_pusfume_unit(health_extension.unit)
                and (poison_damage_types[damage_type] or poison_damage_sources[damage_source_name]) then
            state.poison_blocks = state.poison_blocks + 1

            if state.poison_blocks <= 3 then
                mod:info("[pusfume] Hell Pit Native blocked damage type=%s source=%s amount=%s",
                    tostring(damage_type), tostring(damage_source_name), tostring(damage_amount))
            end

            return
        end

        local result = func(health_extension, attacker_unit, damage_amount, hit_zone_name, damage_type,
            hit_position, damage_direction, damage_source_name, hit_ragdoll_actor, source_attacker_unit,
            hit_react_type, is_critical_strike, added_dot, first_hit, total_hits, attack_type,
            backstab_multiplier, target_index)
        local owner_unit = health_extension.unit
        local actual_attacker = source_attacker_unit or attacker_unit
        local side_manager = Managers.state.side
        local owner_side = side_manager and side_manager.side_by_unit[owner_unit]
        local attacker_side = actual_attacker and side_manager and side_manager.side_by_unit[actual_attacker]
        local melee_attack = attack_type == "light_attack" or attack_type == "heavy_attack"

        if melee_attack and damage_amount and damage_amount > 0 and owner_side and attacker_side
                and owner_side ~= attacker_side and is_pusfume_unit(owner_unit) then
            local buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

            if buff_extension then
                buff_extension:add_buff("pusfume_scaredy_rat_speed")
                state.scaredy_rat_procs = state.scaredy_rat_procs + 1
            end
        end

        return result
    end)
end


function M.install()
    if state.installed then
        return
    end

    register_buffs()
    register_abilities()
    install_damage_traits()
    state.installed = true

    mod:command("pusfume_gameplay", "Show Pusfume career-kit diagnostics.", function()
        mod:echo(string.format(
            "Pusfume gameplay: poison_blocks=%d scaredy_rat_procs=%d iteration_procs=%d iteration_special=%s iteration_effect=%s augmentation_activations=%d augmentation_armed=%s payloads=guarded",
            state.poison_blocks, state.scaredy_rat_procs, state.iteration_procs, tostring(state.iteration_special),
            tostring(state.iteration_effect), state.augmentation_activations, tostring(state.augmentation_armed)))
    end)
end

function M.update()
end

function M.status()
    return state
end

return M
