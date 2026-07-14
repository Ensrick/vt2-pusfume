local mod = get_mod("pusfume")

local M = {}

M.CAREER_NAME = "pusfume"
M.DONOR_CAREER_NAME = "dr_ranger"
M.PROFILE_NAME = "dwarf_ranger"

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

function M.register()
    fassert(CareerSettings and CareerSettings[M.DONOR_CAREER_NAME], "Pusfume donor career is unavailable.")
    fassert(PROFILES_BY_NAME and PROFILES_BY_NAME[M.PROFILE_NAME], "Pusfume donor profile is unavailable.")

    local profile = PROFILES_BY_NAME[M.PROFILE_NAME]
    local career = CareerSettings[M.CAREER_NAME]

    if not career then
        career = deep_clone(CareerSettings[M.DONOR_CAREER_NAME])
        career.name = M.CAREER_NAME
        career.display_name = M.CAREER_NAME
        career.description = "pusfume_description"
        career.playfab_name = nil
        career.required_dlc = nil
        career.sort_order = 5
        career.is_unlocked_function = unlocked
        career.is_dlc_unlocked = unlocked
        career.override_available_for_mechanism = unlocked

        CareerSettings[M.CAREER_NAME] = career
        CareerSettingsOriginal[M.CAREER_NAME] = deep_clone(career)
    end

    local career_index

    for i, existing_career in ipairs(profile.careers) do
        if existing_career.name == M.CAREER_NAME then
            career_index = i
            break
        end
    end

    if not career_index then
        profile.careers[#profile.careers + 1] = career
        career_index = #profile.careers
    end

    PROFILES_BY_CAREER_NAMES[M.CAREER_NAME] = profile

    local changed_items = register_item_permissions()

    mod:info("[pusfume] registered profile=%s career_index=%d donor=%s item_permissions=%d",
        M.PROFILE_NAME, career_index, M.DONOR_CAREER_NAME, changed_items)

    return career_index, changed_items
end

return M

