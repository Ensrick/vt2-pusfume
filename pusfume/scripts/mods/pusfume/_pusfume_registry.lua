local mod = get_mod("pusfume")

local M = {}

M.CAREER_NAME = "pusfume"
M.DONOR_CAREER_NAME = "dr_ranger"
M.PROFILE_NAME = "dwarf_ranger"
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

    return true
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

local function register_item_permissions()
    local changed = 0

    for _, item in pairs(ItemMasterList or {}) do
        local can_wield = item.can_wield

        if type(can_wield) == "table"
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

        if type(can_wield) == "table"
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

function M.find_career_index()
    local profile = PROFILES_BY_NAME and PROFILES_BY_NAME[M.PROFILE_NAME]

    for index, career in ipairs(profile and profile.careers or {}) do
        if career.name == M.CAREER_NAME then
            return index
        end
    end
end

function M.register()
    fassert(CareerSettings and CareerSettings[M.DONOR_CAREER_NAME], "Pusfume donor career is unavailable.")
    fassert(CareerSettingsOriginal, "CareerSettingsOriginal is unavailable.")
    fassert(PROFILES_BY_NAME and PROFILES_BY_NAME[M.PROFILE_NAME], "Pusfume donor profile is unavailable.")

    local profile = PROFILES_BY_NAME[M.PROFILE_NAME]
    local career = CareerSettings[M.CAREER_NAME]

    if not career then
        career = deep_clone(CareerSettings[M.DONOR_CAREER_NAME])
        CareerSettings[M.CAREER_NAME] = career
    end

    -- Reapply custom fields on VMF reloads, where the runtime table may survive.
    career.name = M.CAREER_NAME
    career.display_name = M.CAREER_NAME
    career.description = "pusfume_description"
    career.profile_name = M.PROFILE_NAME
    career.playfab_name = nil
    career.required_dlc = nil
    career.sort_order = 5
    career.is_unlocked_function = available_for_mechanism
    career.is_dlc_unlocked = unlocked
    career.override_available_for_mechanism = available_for_mechanism
    career.character_state_list = build_state_list(profile.base_character_states, career.additional_character_states_list)
    career.camera_state_list = build_state_list(profile.base_camera_states, career.additional_camera_states_list)

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

    local changed_items = register_item_permissions()
    local permission_status = M.item_permission_status()

    mod:info("[pusfume] registered profile=%s career_index=%d donor=%s item_permissions=%d/%d changed=%d",
        M.PROFILE_NAME, career_index, M.DONOR_CAREER_NAME, permission_status.configured,
        permission_status.eligible, changed_items)

    return career_index, changed_items
end

return M
