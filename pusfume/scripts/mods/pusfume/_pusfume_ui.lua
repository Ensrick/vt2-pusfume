local mod = get_mod("pusfume")

local M = {}

local CAREER_CARD_WIDTH = 124
local LEGACY_OVERFLOW_COLUMN = 5
local LEGACY_OVERFLOW_Y = 144
local TOP_ROW_OFFSET_Y = 0
local state = {
    card_seen = false,
    hook_installed = false,
    legacy_card_seen = false,
    legacy_hook_installed = false,
    legacy_target_row = nil,
    modern_card_seen = false,
    modern_hook_installed = false,
    selection_seen = false,
    target_column = nil,
}

local function rightmost_base_career_column(registry)
    local max_columns = 0

    for _, profile_index in ipairs(ProfilePriority or {}) do
        local profile = SPProfiles[profile_index]
        local columns = 0

        for _, career in ipairs(profile and profile.careers or {}) do
            if career.name ~= registry.CAREER_NAME then
                columns = columns + 1
            end
        end

        max_columns = math.max(max_columns, columns)
    end

    return max_columns + 1
end

local function mark_card_seen(kind, column)
    state.card_seen = true
    state[kind .. "_card_seen"] = true
    state.target_column = column
end

local function move_modern_card_to_top_right(window, registry)
    local target_column = rightmost_base_career_column(registry)

    for _, widget in ipairs(window._hero_widgets or {}) do
        local content = widget.content
        local career = content and content.career_settings

        if career and career.name == registry.CAREER_NAME then
            local offset = widget.offset

            offset[1] = (target_column - 1) * CAREER_CARD_WIDTH
            offset[2] = TOP_ROW_OFFSET_Y
            offset[3] = math.max(offset[3] or 0, 10)

            -- Distinguish the donor portrait until original Pusfume UI art is available.
            content.is_premium = true
            window._pusfume_career_widget = widget
            mark_card_seen("modern", target_column)

            mod:info("[pusfume] Hero window card placed at top-right column %d", target_column)

            return
        end
    end

    mod:warning("[pusfume] Hero window opened without a registered Pusfume card")
end

local function ordered_profiles()
    local profiles = PlayerData and PlayerData.bot_spawn_priority

    if not profiles or not profiles[1] then
        profiles = ProfileIndexToPriorityIndex or ProfilePriority
    end

    return profiles or {}
end

local function find_profile_index(registry)
    local target_profile = PROFILES_BY_NAME and PROFILES_BY_NAME[registry.PROFILE_NAME]

    for profile_index, profile in ipairs(SPProfiles or {}) do
        if profile == target_profile then
            return profile_index
        end
    end
end

local function configure_legacy_widget(widget, career, profile, profile_index, row, career_index)
    local content = widget.content
    local offset = widget.offset
    local hero_name = profile.display_name
    local hero_attributes = Managers.backend:get_interface("hero_attributes")
    local hero_experience = hero_attributes:get(hero_name, "experience") or 0
    local hero_level = ExperienceSettings.get_level(hero_experience)

    content.career_settings = career
    content.portrait = "medium_" .. career.portrait_image

    local is_unlocked, reason, dlc_name, localized = career:is_unlocked_function(hero_name, hero_level)

    content.locked = not is_unlocked
    content.locked_reason = not is_unlocked and (localized and reason or Localize(reason))
    content.dlc_name = dlc_name

    if reason == "dlc_not_owned" then
        content.lock_texture = content.lock_texture .. "_gold"
        content.frame = content.frame .. "_gold"
    end

    local selected_career_index = hero_attributes:get(hero_name, "career")
    local bot_career_index = hero_attributes:get(hero_name, "bot_career") or selected_career_index or 1
    local bot_priority = table.find(ordered_profiles(), profile_index)

    if bot_career_index == career_index and bot_priority and bot_priority <= 5 then
        content.bot_priority = bot_priority
        content.bot_selected = true
    end

    content.is_premium = true
    content.pusfume_overflow = true
    offset[1] = (LEGACY_OVERFLOW_COLUMN - 1) * CAREER_CARD_WIDTH
    offset[2] = LEGACY_OVERFLOW_Y
    offset[3] = math.max(offset[3] or 0, 110)

    mark_card_seen("legacy", LEGACY_OVERFLOW_COLUMN)
    state.legacy_target_row = row
end

local function add_legacy_overflow_card(window, registry)
    local career_index = registry.find_career_index()
    local profile = PROFILES_BY_NAME and PROFILES_BY_NAME[registry.PROFILE_NAME]
    local career = profile and profile.careers[career_index]
    local profile_index = find_profile_index(registry)
    local profiles = ordered_profiles()
    local row = profile_index and table.find(profiles, profile_index)

    if not career or not row then
        mod:warning("[pusfume] Five-row career grid could not resolve the Pusfume profile row")
        return
    end

    for _, widget in ipairs(window._hero_widgets or {}) do
        local widget_career = widget.content and widget.content.career_settings

        if widget_career and widget_career.name == registry.CAREER_NAME then
            configure_legacy_widget(widget, career, profile, profile_index, row, career_index)
            window._pusfume_career_widget = widget
            return
        end
    end

    local current_columns = window._num_hero_columns and window._num_hero_columns[row] or 0

    if career_index ~= current_columns + 1 then
        mod:warning("[pusfume] Five-row career grid expected career column %d after %d visible columns",
            career_index, current_columns)
        return
    end

    local widget = UIWidget.init(UIWidgets.create_hero_widget("hero_root", { 110, 130 }))

    configure_legacy_widget(widget, career, profile, profile_index, row, career_index)

    local insertion_index = 1

    for prior_row = 1, row - 1 do
        insertion_index = insertion_index + (window._num_hero_columns[prior_row] or 0)
    end

    insertion_index = insertion_index + current_columns
    table.insert(window._hero_widgets, insertion_index, widget)
    window._num_hero_columns[row] = current_columns + 1
    window._pusfume_career_widget = widget

    mod:info("[pusfume] Five-row career grid card added in overflow slot row=%d column=%d",
        row, career_index)
end

local function track_selection(registry, profile_index, career_index)
    local profile = SPProfiles[profile_index]
    local career = profile and profile.careers[career_index]

    if career and career.name == registry.CAREER_NAME then
        state.selection_seen = true
        mod:info("[pusfume] Hero selector previewed Pusfume")
    end
end

local function install_modern_hooks(registry)
    if state.modern_hook_installed or not HeroWindowCharacterSelectionConsole then
        return
    end

    mod:hook_safe(HeroWindowCharacterSelectionConsole, "_setup_hero_selection_widgets", function(window)
        move_modern_card_to_top_right(window, registry)
    end)

    mod:hook_safe(HeroWindowCharacterSelectionConsole, "_select_hero", function(window, profile_index, career_index)
        track_selection(registry, profile_index, career_index)
    end)

    state.modern_hook_installed = true
end

local function install_legacy_hooks(registry)
    if state.legacy_hook_installed or not CharacterSelectionStateCharacter then
        return
    end

    mod:hook_safe(CharacterSelectionStateCharacter, "_setup_hero_selection_widgets", function(window)
        add_legacy_overflow_card(window, registry)
    end)

    mod:hook_safe(CharacterSelectionStateCharacter, "_select_hero", function(window, profile_index, career_index)
        track_selection(registry, profile_index, career_index)
    end)

    state.legacy_hook_installed = true
end

function M.install(registry)
    install_modern_hooks(registry)
    install_legacy_hooks(registry)

    state.hook_installed = state.modern_hook_installed or state.legacy_hook_installed

    if not state.hook_installed then
        mod:warning("[pusfume] Hero selector classes are unavailable; /pusfume remains available")
    end

    return state.hook_installed
end

function M.status()
    return state
end

return M
