local mod = get_mod("pusfume")

local M = {}
local loadout_validator

M.CAREER_NAME = "pusfume"
M.DONOR_CAREER_NAME = "dr_ranger"
M.PROFILE_NAME = "dwarf_ranger"
M.NATIVE_SKIN_NAME = nil
M.SUPPORTED_MECHANISMS = {
    adventure = true,
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

local function contains(array, value)
    for i = 1, #array do
        if array[i] == value then
            return true
        end
    end

    return false
end

local function unlocked()
    return true
end

function M.current_mechanism_name()
    local mechanism_manager = Managers and Managers.mechanism

    if mechanism_manager and mechanism_manager.current_mechanism_name then
        return mechanism_manager:current_mechanism_name()
    end
end

function M.is_supported_mechanism()
    local mechanism_name = M.current_mechanism_name()

    if not mechanism_name then
        return true, "not initialized"
    end

    return M.SUPPORTED_MECHANISMS[mechanism_name] == true, mechanism_name
end

local function available_for_mechanism()
    local supported = M.is_supported_mechanism()

    if not supported then
        return false, "disabled_for_mechanism"
    end

    if loadout_validator then
        local ok, ready, detail = pcall(loadout_validator)

        if not ok or not ready then
            return false, "Pusfume loadout unavailable: " .. tostring(ok and detail or ready), nil, true
        end
    end

    return true
end

function M.set_loadout_validator(validator)
    loadout_validator = validator
end

local function build_state_list(base_states, additional_states)
    local states = deep_clone(base_states or {})

    for _, state_name in ipairs(additional_states or {}) do
        if not contains(states, state_name) then
            states[#states + 1] = state_name
        end
    end

    return states
end

function M.refresh_item_permissions()
    local changed = 0

    for _, item in pairs(ItemMasterList or {}) do
        local can_wield = item.can_wield
        local is_weapon = item.slot_type == "melee" or item.slot_type == "ranged"

        if not is_weapon and type(can_wield) == "table"
                and can_wield ~= CanWieldAllItemTemplates
                and contains(can_wield, M.DONOR_CAREER_NAME)
                and not contains(can_wield, M.CAREER_NAME) then
            can_wield[#can_wield + 1] = M.CAREER_NAME
            changed = changed + 1
        end
    end

    return changed
end

function M.item_permission_status()
    local status = {
        configured = 0,
        eligible = 0,
        missing = 0,
    }

    for _, item in pairs(ItemMasterList or {}) do
        local can_wield = item.can_wield
        local is_weapon = item.slot_type == "melee" or item.slot_type == "ranged"

        if not is_weapon and type(can_wield) == "table"
                and can_wield ~= CanWieldAllItemTemplates
                and contains(can_wield, M.DONOR_CAREER_NAME) then
            status.eligible = status.eligible + 1

            if contains(can_wield, M.CAREER_NAME) then
                status.configured = status.configured + 1
            else
                status.missing = status.missing + 1
            end
        end
    end

    return status
end

function M.refresh_career_color()
    local color_definitions = Colors and Colors.color_definitions
    local donor_color = color_definitions and color_definitions[M.DONOR_CAREER_NAME]

    if type(donor_color) ~= "table" then
        return false
    end

    -- The player-list HUD indexes custom career colors without a fallback.
    color_definitions[M.CAREER_NAME] = deep_clone(donor_color)

    return color_definitions[M.CAREER_NAME] ~= donor_color
end

function M.find_career_index()
    local profile = PROFILES_BY_NAME and PROFILES_BY_NAME[M.PROFILE_NAME]

    for index, career in ipairs(profile and profile.careers or {}) do
        if career.name == M.CAREER_NAME then
            return index
        end
    end
end

function M.set_native_skin(skin_name)
    M.NATIVE_SKIN_NAME = skin_name
end

-- StatisticsDefinitions builds its per-career stat families by iterating
-- CareerSettings at BOOT, before this mod registers the career, so every
-- career-keyed stat path (min_health_percentage.pusfume,
-- completed_career_levels.pusfume.*) is absent and any stats consumer that
-- records per-career data raises a fatal (career_tweaker armor/overcharge
-- add_damage stat, crash 2026-07-19 23:30). Replicate the boot generation for
-- this career. Idempotent for VMF reloads; definitions land before any
-- player-unit StatisticsDatabase registration consumes them.
function M.register_statistics_definitions()
    local player_definitions = StatisticsDefinitions and StatisticsDefinitions.player

    if not player_definitions then
        mod:warning("[pusfume] StatisticsDefinitions unavailable; per-career stats not registered")
        return false
    end

    local career_name = M.CAREER_NAME

    if player_definitions.min_health_percentage
            and not player_definitions.min_health_percentage[career_name] then
        player_definitions.min_health_percentage[career_name] = {
            value = 1,
        }
    end

    if player_definitions.min_health_completed
            and not player_definitions.min_health_completed[career_name] then
        player_definitions.min_health_completed[career_name] = {
            source = "player_data",
            value = 0,
            database_name = "min_health_completed_" .. career_name,
        }
    end

    if player_definitions.completed_career_levels
            and not player_definitions.completed_career_levels[career_name]
            and LevelSettings and UnlockableLevels and DifficultySettings then
        local career_levels = {}

        for level_key, _ in pairs(LevelSettings) do
            if table.contains(UnlockableLevels, level_key) then
                career_levels[level_key] = {}

                for diff, _ in pairs(DifficultySettings) do
                    career_levels[level_key][diff] = {
                        source = "player_data",
                        value = 0,
                        database_name = "completed_career_levels_" .. career_name
                            .. "_" .. level_key .. "_" .. diff,
                    }
                end
            end
        end

        player_definitions.completed_career_levels[career_name] = career_levels
    end

    return true
end

function M.register()
    fassert(CareerSettings and CareerSettings[M.DONOR_CAREER_NAME], "Pusfume donor career is unavailable.")
    fassert(CareerSettingsOriginal, "CareerSettingsOriginal is unavailable.")
    fassert(PROFILES_BY_NAME and PROFILES_BY_NAME[M.PROFILE_NAME], "Pusfume donor profile is unavailable.")
    fassert(M.refresh_career_color(), "Pusfume donor career color is unavailable.")

    local profile = PROFILES_BY_NAME[M.PROFILE_NAME]
    local career = CareerSettings[M.CAREER_NAME]

    if not career then
        career = deep_clone(CareerSettings[M.DONOR_CAREER_NAME])
        CareerSettings[M.CAREER_NAME] = career
    end

    -- Reapply custom fields on VMF reloads, where the runtime table may survive.
    career.name = M.CAREER_NAME
    -- ProfileRequester resolves this field as an internal career token before
    -- the UI localizes it, so it must match the registered career name.
    career.display_name = M.CAREER_NAME
    career.description = "pusfume_description"
    career.profile_name = M.PROFILE_NAME
    -- Versus rat careers use this Wwise routing value while character_vo is
    -- applied per spawned Pusfume unit to avoid mutating Bardin's profile.
    career.sound_character = "dwarf_slayer"
    career.playfab_name = nil
    career.required_dlc = nil
    career.sort_order = 5
    career.is_unlocked_function = available_for_mechanism
    career.is_dlc_unlocked = unlocked
    career.override_available_for_mechanism = available_for_mechanism
    career.character_state_list = build_state_list(profile.base_character_states, career.additional_character_states_list)
    career.camera_state_list = build_state_list(profile.base_camera_states, career.additional_camera_states_list)
    career.base_skin = M.NATIVE_SKIN_NAME or CareerSettings[M.DONOR_CAREER_NAME].base_skin
    career.portrait_image = "portrait_pusfume"
    career.picking_image = "medium_portrait_pusfume"
    career.portrait_image_picking = "medium_portrait_pusfume"
    career.portrait_thumbnail = "small_portrait_pusfume"
    career.preview_animation = "idle"
    career.preview_idle_animation = "idle"
    career.preview_items = {}
    career.preview_wield_slot = nil
    career.activated_ability = ActivatedAbilitySettings.pusfume
    career.passive_ability = PassiveAbilitySettings.pusfume
    career.attributes = career.attributes or {}
    career.attributes.max_hp = 100

    -- Warpfire uses the ordinary hero overcharge extension in Adventure. The
    -- HUD resolves its presentation by career name, so the synthetic career
    -- needs an explicit alias rather than Bardin's non-visible fallback.
    OverchargeData = OverchargeData or {}

    if OverchargeData.vs_warpfire_thrower then
        OverchargeData[M.CAREER_NAME] = deep_clone(
            OverchargeData.vs_warpfire_thrower)
    end

    CareerSettingsOriginal[M.CAREER_NAME] = deep_clone(career)

    local career_index

    for i, existing_career in ipairs(profile.careers) do
        if existing_career.name == M.CAREER_NAME then
            career_index = i
            profile.careers[i] = career
            break
        end
    end

    if not career_index then
        profile.careers[#profile.careers + 1] = career
        career_index = #profile.careers
    end

    PROFILES_BY_CAREER_NAMES[M.CAREER_NAME] = profile
    M.register_statistics_definitions()

    local changed_items = M.refresh_item_permissions()
    local permission_status = M.item_permission_status()

    mod:info("[pusfume] registered profile=%s career_index=%d donor=%s item_permissions=%d/%d changed=%d",
        M.PROFILE_NAME, career_index, M.DONOR_CAREER_NAME, permission_status.configured,
        permission_status.eligible, changed_items)

    return career_index, changed_items
end

return M
