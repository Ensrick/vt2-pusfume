local mod = get_mod("pusfume")

local M = {}

local PROFILE_NAME = "dwarf_ranger"
local SETTING_KEY = "pusfume_talent_columns"
local DEFAULT_SELECTION = { 0, 0, 0, 0, 0, 0 }

local rows = {
    {
        { key = "second_wind", icon = "bardin_ranger_regrowth", buffs = { "thp_tank" }, buffer = "server" },
        { key = "execute", icon = "bardin_ranger_conqueror", buffs = { "thp_smiter" }, buffer = "server" },
        { key = "cleave", icon = "bardin_ranger_bloodlust", buffs = { "thp_linesman" }, buffer = "server" },
    },
    {
        { key = "crafty_claws", icon = "bardin_ranger_cooldown_on_reload", guarded = true },
        { key = "coward_at_heart", icon = "bardin_ranger_movement_speed", buffs = { "pusfume_coward_at_heart" } },
        { key = "elusive_nature", icon = "bardin_ranger_reduced_damage_taken_headshot", buffs = { "pusfume_elusive_nature" } },
    },
    {
        { key = "smiter", icon = "bardin_ranger_linesman_unbalance", buffs = { "smiter_unbalance" }, buffer = "server" },
        { key = "mainstay", icon = "bardin_ranger_tank_unbalance", buffs = { "tank_unbalance" }, buffer = "server" },
        { key = "enhanced_power", icon = "bardin_ranger_power_level_unbalance", buffs = { "power_level_unbalance" }, buffer = "server" },
    },
    {
        { key = "opportunism", icon = "bardin_ranger_attack_speed", guarded = true },
        { key = "enhanced_cunning", icon = "bardin_ranger_activated_ability_duration", guarded = true },
        { key = "run_it_through_a_filter", icon = "bardin_ranger_activated_ability_duration", guarded = true },
    },
    {
        { key = "warpstone_bullets", icon = "bardin_ranger_power_level_unbalance", guarded = true },
        { key = "open_wounds", icon = "bardin_ranger_attack_speed", guarded = true },
        { key = "last_ditch_effort", icon = "bardin_ranger_activated_ability_stealth_outside_of_smoke", guarded = true },
    },
    {
        { key = "expert_craftsmanship", icon = "bardin_ranger_ability_free_grenade", guarded = true },
        { key = "from_scraps", icon = "bardin_ranger_activated_ability_duration", guarded = true },
        { key = "make_it_two_two", icon = "bardin_ranger_passive_improved_ammo", guarded = true },
    },
}

local state = {
    guarded_count = 0,
    installed = false,
    operational_count = 0,
    persistence_writes = 0,
    talent_count = 0,
    tree_index = nil,
}

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
    definition.name = name
    BuffTemplates[name] = { buffs = { definition } }
    append_lookup(NetworkLookup.buff_templates, name)
end

local function register_runtime_buffs()
    register_buff_template("pusfume_coward_at_heart", {
        buff_to_add = "pusfume_coward_at_heart_stack",
        chunk_size = 20,
        max_stacks = 4,
        update_func = "activate_buff_stacks_based_on_health_chunks",
    })
    register_buff_template("pusfume_coward_at_heart_stack", {
        apply_buff_func = "apply_movement_buff",
        max_stacks = 4,
        multiplier = 1.05,
        path_to_movement_setting_to_modify = { "move_speed" },
        remove_buff_func = "remove_movement_buff",
    })
    register_buff_template("pusfume_elusive_nature", {
        apply_buff_func = "apply_movement_buff",
        max_stacks = 1,
        multiplier = 1.1,
        path_to_movement_setting_to_modify = { "dodging", "distance_modifier" },
        remove_buff_func = "remove_movement_buff",
    })
end

local function talent_name(key)
    return "pusfume_talent_" .. key
end

local function find_existing_tree(trees)
    local first_name = talent_name(rows[1][1].key)

    for index, tree in ipairs(trees) do
        if tree[1] and tree[1][1] == first_name then
            return index
        end
    end
end

local function register_tree()
    local hero_talents = Talents[PROFILE_NAME]
    local hero_trees = TalentTrees[PROFILE_NAME]
    local tree = {}
    local tree_index = find_existing_tree(hero_trees) or (#hero_trees + 1)
    local operational_count = 0
    local guarded_count = 0

    for row_index, row in ipairs(rows) do
        tree[row_index] = {}

        for column_index, definition in ipairs(row) do
            local name = talent_name(definition.key)
            local lookup = rawget(TalentIDLookup, name)
            local talent_id = lookup and lookup.talent_id or (#hero_talents + 1)
            local talent = {
                buffer = definition.buffer,
                buffs = definition.buffs or {},
                description = name .. "_description",
                description_values = {},
                display_name = name .. "_name",
                icon = definition.icon,
                name = name,
                num_ranks = 1,
                pusfume_guarded = definition.guarded == true,
                tree = tree_index,
                row = row_index,
                coulumn = column_index,
                talent_id = talent_id,
            }

            hero_talents[talent_id] = talent
            TalentIDLookup[name] = {
                hero_name = PROFILE_NAME,
                talent_id = talent_id,
            }
            tree[row_index][column_index] = name

            if definition.guarded then
                guarded_count = guarded_count + 1
            else
                operational_count = operational_count + 1
            end
        end
    end

    hero_trees[tree_index] = tree
    state.guarded_count = guarded_count
    state.operational_count = operational_count
    state.talent_count = operational_count + guarded_count
    state.tree_index = tree_index
end

local function sanitized_selection(selection)
    local result = {}

    for row = 1, 6 do
        local column = type(selection) == "table" and tonumber(selection[row]) or 0
        column = column and math.floor(column) or 0
        result[row] = column >= 0 and column <= 3 and column or 0
    end

    return result
end

function M.get_selection()
    return sanitized_selection(mod:get(SETTING_KEY) or DEFAULT_SELECTION)
end

function M.set_selection(selection)
    local sanitized = sanitized_selection(selection)
    mod:set(SETTING_KEY, sanitized)
    state.persistence_writes = state.persistence_writes + 1

    return sanitized
end

function M.get_talent_ids(optional_selection)
    local selection = sanitized_selection(optional_selection or M.get_selection())
    local tree = M.get_tree()
    local ids = {}

    for row = 1, 6 do
        local column = selection[row]

        if column > 0 then
            local name = tree[row] and tree[row][column]
            local lookup = name and TalentIDLookup[name]

            if lookup then
                ids[#ids + 1] = lookup.talent_id
            end
        end
    end

    return ids
end


function M.get_tree()
    return state.tree_index and TalentTrees[PROFILE_NAME][state.tree_index]
end

function M.get_tree_index()
    return state.tree_index
end

function M.get_loadout_sets()
    return { M.get_selection() }
end

function M.install()
    if state.installed then
        return state.tree_index
    end

    fassert(Talents and Talents[PROFILE_NAME] and TalentTrees and TalentTrees[PROFILE_NAME]
            and TalentIDLookup and BuffTemplates and NetworkLookup and NetworkLookup.buff_templates,
        "Pusfume talent registries are unavailable.")
    register_runtime_buffs()
    register_tree()
    state.installed = true

    mod:info("[pusfume] registered talent tree index=%d operational=%d guarded=%d",
        state.tree_index, state.operational_count, state.guarded_count)

    return state.tree_index
end

function M.status()
    return state
end

return M
