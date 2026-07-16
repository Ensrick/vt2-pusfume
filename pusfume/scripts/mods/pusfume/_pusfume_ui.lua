local mod = get_mod("pusfume")

local M = {}

local CAREER_CARD_WIDTH = 124
local LEGACY_OVERFLOW_COLUMN = 5
local LEGACY_OVERFLOW_Y = 144
local MODEL_PREVIEW_OFFSET = { 140, -20, 150 }
local MODEL_PREVIEW_SIZE = { 576, 675 }
local MODEL_PREVIEW_TEXTURE = "pusfume_model_preview"
local TOP_ROW_OFFSET_Y = 0
local state = {
    card_seen = false,
    hook_installed = false,
    legacy_card_seen = false,
    legacy_hook_installed = false,
    legacy_target_row = nil,
    modern_card_seen = false,
    modern_hook_installed = false,
    preview_hook_installed = false,
    previewer_purity_installed = false,
    preview_widget_seen = false,
    donor_preview_suppressed = false,
    native_preview_enabled = false,
    selection_seen = false,
    target_column = nil,
}

local function is_pusfume_selection(window, registry, profile_index, career_index)
    profile_index = profile_index or window._selected_profile_index
    career_index = career_index or window._selected_career_index

    local profile = profile_index and SPProfiles[profile_index]
    local career = profile and career_index and profile.careers[career_index]

    return career and career.name == registry.CAREER_NAME
end

local function sync_preview_visibility(window, visible)
    window._pusfume_preview_selected = visible == true

    local widget = window._pusfume_model_preview_widget

    if widget then
        widget.content.visible = window._pusfume_preview_selected
    end
end

local function create_model_preview_widget(window)
    if window._pusfume_model_preview_widget then
        return
    end

    local widget_definition = {
        scenegraph_id = "screen",
        element = {
            passes = {
                {
                    content_check_function = function(content)
                        return content.visible
                    end,
                    pass_type = "texture",
                    style_id = "texture_id",
                    texture_id = "texture_id",
                },
            },
        },
        content = {
            texture_id = MODEL_PREVIEW_TEXTURE,
            visible = false,
        },
        style = {
            texture_id = {
                color = { 255, 255, 255, 255 },
                horizontal_alignment = "center",
                texture_size = MODEL_PREVIEW_SIZE,
                vertical_alignment = "center",
            },
        },
        offset = MODEL_PREVIEW_OFFSET,
    }
    local widget = UIWidget.init(widget_definition)

    window._pusfume_model_preview_widget = widget
    table.insert(window._additional_widgets, widget)
    sync_preview_visibility(window, window._pusfume_preview_selected)
    state.preview_widget_seen = true

    mod:info("[pusfume] Model-derived selector preview initialized at 1920x1080 virtual scale")
end

local function suppress_donor_preview(world_previewer)
    -- clear_units does not cancel queued spawns or package polling on its own.
    world_previewer._requested_hero_spawn_data = nil
    world_previewer._delayed_hero_spawn_data = nil
    world_previewer:clear_asynchronous_data()
    world_previewer:_unload_all_packages()
    world_previewer:clear_units()
    world_previewer:hide_character()
end

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
    local selected = career and career.name == registry.CAREER_NAME

    if selected then
        state.selection_seen = true
        mod:info("[pusfume] Hero selector previewed Pusfume")
    end

    return selected
end

local function install_modern_hooks(registry)
    if state.modern_hook_installed or not HeroWindowCharacterSelectionConsole then
        return
    end

    mod:hook_safe(HeroWindowCharacterSelectionConsole, "_setup_hero_selection_widgets", function(window)
        move_modern_card_to_top_right(window, registry)
    end)

    mod:hook_safe(HeroWindowCharacterSelectionConsole, "_select_hero", function(window, profile_index, career_index)
        sync_preview_visibility(window, track_selection(registry, profile_index, career_index))
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
        sync_preview_visibility(window, track_selection(registry, profile_index, career_index))
    end)

    state.legacy_hook_installed = true
end

local function install_previewer_purity_hooks(registry, native)
    if state.previewer_purity_installed or not MenuWorldPreviewer then
        return
    end

    -- One hook covers every menu surface that previews a career through
    -- MenuWorldPreviewer (character selection AND the inventory hero view):
    -- when the previewed career is Pusfume, spawn the preview-only skin whose
    -- third_person IS the native unit, and flag the previewer so its weapon
    -- and ammo units stay hidden.
    mod:hook(MenuWorldPreviewer, "request_spawn_hero_unit", function(func, previewer,
            profile_name, career_index, state_character, callback, optional_scale,
            camera_move_duration, optional_skin, reset_camera)
        local preview_skin = native.preview_skin_name()
        local is_pusfume = preview_skin
            and career_index == registry.find_career_index()
            and (profile_name == registry.PROFILE_NAME or profile_name == "bardin")

        if is_pusfume then
            previewer._pusfume_preview_active = true
            optional_skin = preview_skin
            mod:info("[pusfume] Menu previewer spawning native preview skin")
        else
            previewer._pusfume_preview_active = nil
        end

        return func(previewer, profile_name, career_index, state_character, callback,
            optional_scale, camera_move_duration, optional_skin, reset_camera)
    end)

    mod:hook_safe(MenuWorldPreviewer, "_update_units_visibility", function(previewer)
        if not previewer._pusfume_preview_active then
            return
        end

        local equipment_units = previewer._equipment_units

        if not equipment_units then
            return
        end

        for _, hands in pairs(equipment_units) do
            if type(hands) == "table" then
                for _, weapon_unit in pairs(hands) do
                    if weapon_unit and Unit.alive(weapon_unit) then
                        Unit.set_unit_visibility(weapon_unit, false)
                    end
                end
            end
        end
    end)

    state.previewer_purity_installed = true
end

local function install_preview_hooks(registry, native)
    if state.preview_hook_installed or not CharacterSelectionStateCharacter then
        return
    end

    mod:hook_safe(CharacterSelectionStateCharacter, "create_ui_elements", function(window)
        create_model_preview_widget(window)
    end)

    mod:hook(CharacterSelectionStateCharacter, "_spawn_hero_unit", function(func, window, hero_name)
        if is_pusfume_selection(window, registry) then
            if native.preview_enabled() then
                sync_preview_visibility(window, false)
                state.native_preview_enabled = true
                mod:info("[pusfume] Requesting native Pusfume hero preview")

                local spawn_callback = callback(window, "cb_hero_unit_spawned", hero_name)

                -- Equipped skins resolve through the donor backend. Force the
                -- base skin so Pusfume cannot preview as Ranger Veteran.
                return window.world_previewer:request_spawn_hero_unit(hero_name,
                    window._selected_career_index, true, spawn_callback, nil, 0.5)
            end

            local world_previewer = window.world_previewer

            suppress_donor_preview(world_previewer)
            sync_preview_visibility(window, true)
            state.donor_preview_suppressed = true

            mod:info("[pusfume] Native hero preview disabled; using crash-safe model-derived UI preview")

            return
        end

        sync_preview_visibility(window, false)

        return func(window, hero_name)
    end)

    state.preview_hook_installed = true
end

function M.install(registry, native)
    install_modern_hooks(registry)
    install_legacy_hooks(registry)
    install_preview_hooks(registry, native)
    install_previewer_purity_hooks(registry, native)

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
