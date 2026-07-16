local mod = get_mod("pusfume")

local M = {}

local CAREER_NAME = "pusfume"
local CHALLENGE_CATEGORY = "pusfume_scheme"
local CHALLENGE_SKAVEN = "pusfume_scheme_kill_skaven"
local CHALLENGE_SPECIALS = "pusfume_scheme_kill_skaven_specials"
local REWARD_STRENGTH = "pusfume_scheme_reward_strength"
local REWARD_SPEED = "pusfume_scheme_reward_speed"
local STATION_DURATION = 20

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
    installed = false,
    poison_blocks = 0,
    station_deployments = 0,
    station = nil,
}

local function is_pusfume_unit(unit)
    if not unit or not Unit.alive(unit) then
        return false
    end

    local career_extension = ScriptUnit.has_extension(unit, "career_system")

    return career_extension and career_extension:career_name() == CAREER_NAME
end

local function is_skaven_breed(breed)
    if not breed then
        return false
    end

    return breed.race == "skaven" or type(breed.name) == "string" and string.sub(breed.name, 1, 7) == "skaven_"
end

local function append_lookup(lookup, name)
    if lookup[name] then
        return lookup[name]
    end

    local index = #lookup + 1

    lookup[index] = name
    lookup[name] = index

    return index
end


local function register_buff_template(name, definition)
    BuffTemplates[name] = {
        buffs = {
            definition,
        },
    }
    append_lookup(NetworkLookup.buff_templates, name)
end


local function register_challenges()
    InGameChallengeTemplates[CHALLENGE_SKAVEN] = {
        default_target = 40,
        description = "pusfume_scheme_kill_skaven_description",
        events = {
            on_player_killed_enemy = function(t, data, killing_blow, breed_killed)
                return is_skaven_breed(breed_killed) and 1 or nil
            end,
        },
    }
    InGameChallengeTemplates[CHALLENGE_SPECIALS] = {
        default_target = 5,
        description = "pusfume_scheme_kill_specials_description",
        events = {
            on_player_killed_enemy = function(t, data, killing_blow, breed_killed)
                return is_skaven_breed(breed_killed) and breed_killed.special and 1 or nil
            end,
        },
    }
    InGameChallengeRewards[REWARD_STRENGTH] = {
        icon = "icon_objective_potion",
        pickup_type = "damage_boost_potion",
        sound = "Play_hud_grail_knight_charge",
        target = "owner",
        type = "pickup",
        pickup_spawn_type = PickupSpawnType.DropIfFull,
    }
    InGameChallengeRewards[REWARD_SPEED] = {
        icon = "icon_objective_potion",
        pickup_type = "speed_boost_potion",
        sound = "Play_hud_grail_knight_stamina",
        target = "owner",
        type = "pickup",
        pickup_spawn_type = PickupSpawnType.DropIfFull,
    }

    append_lookup(NetworkLookup.challenges, CHALLENGE_SKAVEN)
    append_lookup(NetworkLookup.challenges, CHALLENGE_SPECIALS)
    append_lookup(NetworkLookup.challenge_rewards, REWARD_STRENGTH)
    append_lookup(NetworkLookup.challenge_rewards, REWARD_SPEED)
    append_lookup(NetworkLookup.challenge_categories, CHALLENGE_CATEGORY)
end


PassiveAbilityPusfumeScheme = class(PassiveAbilityPusfumeScheme)

PassiveAbilityPusfumeScheme.init = function(self, extension_init_context, unit, extension_init_data)
    self._is_server = extension_init_context.is_server
    self._player_unique_id = extension_init_data.player:unique_id()
end

PassiveAbilityPusfumeScheme.extensions_ready = function(self)
    if not self._is_server then
        return
    end

    local level_transition_handler = Managers.level_transition_handler
    local level_key = level_transition_handler and level_transition_handler:get_current_level_keys()
    local level_settings = level_key and LevelSettings[level_key]

    if level_settings and level_settings.hub_level then
        return
    end

    local challenge_manager = Managers.venture and Managers.venture.challenge

    if not challenge_manager then
        mod:warning("[pusfume] The Great Scheme could not find the challenge manager")
        return
    end

    local owner_id = self._player_unique_id
    local existing = challenge_manager:get_challenges_filtered({}, CHALLENGE_CATEGORY, owner_id)

    if #existing > 0 then
        for i = 1, #existing do
            existing[i]:set_paused(false)
        end

        return
    end

    local completed = challenge_manager:get_completed_challenges_filtered({}, CHALLENGE_CATEGORY, owner_id)

    if #completed == 0 then
        challenge_manager:add_challenge(CHALLENGE_SKAVEN, false, CHALLENGE_CATEGORY, REWARD_STRENGTH, owner_id, 40)
        challenge_manager:add_challenge(CHALLENGE_SPECIALS, false, CHALLENGE_CATEGORY, REWARD_SPEED, owner_id, 5)
        mod:info("[pusfume] The Great Scheme started two placeholder Skaven quests")
    end
end

PassiveAbilityPusfumeScheme.destroy = function(self)
    local challenge_manager = Managers.venture and Managers.venture.challenge

    if not self._is_server or not challenge_manager then
        return
    end

    local challenges = challenge_manager:get_challenges_filtered({}, CHALLENGE_CATEGORY, self._player_unique_id)

    for i = 1, #challenges do
        challenges[i]:set_paused(true)
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

    local position = POSITION_LOOKUP[self._owner_unit]

    if not position then
        return
    end

    local now = Managers.time:time("game")

    state.station = {
        expires_at = now + STATION_DURATION,
        owner_unit = self._owner_unit,
        position = Vector3Box(position),
    }
    state.station_deployments = state.station_deployments + 1
    self._career_extension:start_activated_ability_cooldown()

    if self._local_player then
        mod:echo(mod:localize("pusfume_ingenuity_station_placeholder"))
    end

    mod:info("[pusfume] Skaven Ingenuity station scaffold deployed x=%.2f y=%.2f z=%.2f duration=%ds",
        position.x, position.y, position.z, STATION_DURATION)
end

CareerAbilityPusfumeIngenuity.stop = function(self)
end


local function register_buffs()
    fassert(type(ProcFunctions) == "table",
        "Pusfume requires VT2's ProcFunctions registry before gameplay registration.")
    fassert(type(BuffTemplates) == "table" and NetworkLookup and type(NetworkLookup.buff_templates) == "table",
        "Pusfume requires VT2's buff and network registries before gameplay registration.")

    ProcFunctions.pusfume_scaredy_rat_proc = function(owner_unit)
        if not Unit.alive(owner_unit) or not is_pusfume_unit(owner_unit) then
            return
        end

        local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")

        buff_extension:add_buff("pusfume_scaredy_rat_speed")
    end

    register_buff_template("pusfume_scaredy_rat_listener", {
        event = "on_damage_taken",
        event_buff = true,
        buff_func = "pusfume_scaredy_rat_proc",
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
    register_buff_template("pusfume_insider_knowledge_aura", {
        buff_to_add = "pusfume_insider_knowledge_team",
        range = 100000,
        remove_buff_func = "remove_aura_buff",
        update_frequency = 0.1,
        update_func = "activate_buff_on_distance",
    })
    register_buff_template("pusfume_insider_knowledge_team", {
        max_stacks = 1,
        multiplier = 0.05,
        stat_buff = "power_level_skaven",
    })
end


local function register_abilities()
    ActivatedAbilitySettings.pusfume = {
        {
            ability_class = CareerAbilityPusfumeIngenuity,
            cooldown = 60,
            description = "pusfume_active_description",
            display_name = "pusfume_active_name",
            icon = "bardin_ranger_activated_ability",
        },
    }
    PassiveAbilitySettings.pusfume = {
        buffs = {
            "pusfume_scaredy_rat_listener",
            "pusfume_insider_knowledge_aura",
        },
        description = "pusfume_passive_description",
        display_name = "pusfume_passive_name",
        icon = "bardin_ranger_passive",
        passive_ability_classes = {
            {
                ability_class = PassiveAbilityPusfumeScheme,
                name = "pusfume_scheme",
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
                description = "pusfume_insider_knowledge_description",
                display_name = "pusfume_insider_knowledge_name",
            },
        },
    }
end


local function install_poison_immunity()
    mod:hook(PlayerUnitHealthExtension, "add_damage", function(func, health_extension, attacker_unit,
            damage_amount, hit_zone_name, damage_type, hit_position, damage_direction, damage_source_name, ...)
        if is_pusfume_unit(health_extension.unit)
                and (poison_damage_types[damage_type] or poison_damage_sources[damage_source_name]) then
            state.poison_blocks = state.poison_blocks + 1

            if state.poison_blocks <= 3 then
                mod:info("[pusfume] Hell Pit Native blocked damage type=%s source=%s amount=%s",
                    tostring(damage_type), tostring(damage_source_name), tostring(damage_amount))
            end

            return
        end

        return func(health_extension, attacker_unit, damage_amount, hit_zone_name, damage_type, hit_position,
            damage_direction, damage_source_name, ...)
    end)
end


function M.install()
    if state.installed then
        return
    end

    register_buffs()
    register_challenges()
    register_abilities()
    install_poison_immunity()
    state.installed = true

    mod:command("pusfume_gameplay", "Show Pusfume career-kit diagnostics.", function()
        local active = state.station and Managers.time and Managers.time:time("game") < state.station.expires_at

        mod:echo(string.format(
            "Pusfume gameplay: poison_blocks=%d station_deployments=%d station_active=%s inventory_upgrades=guarded",
            state.poison_blocks, state.station_deployments, tostring(active == true)))
    end)
end

function M.update()
    if state.station and Managers.time and Managers.time:time("game") >= state.station.expires_at then
        state.station = nil
        mod:info("[pusfume] Skaven Ingenuity station scaffold expired")
    end
end

function M.status()
    return state
end

return M
