local mod = get_mod("pusfume")

local M = {}

local CAREER_CARD_WIDTH = 124
local TOP_ROW_OFFSET_Y = 0

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

local function move_card_to_top_right(window, registry)
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

            mod:info("[pusfume] Hero selector card placed at top-right column %d", target_column)

            return
        end
    end

    mod:warning("[pusfume] Hero selector opened without a registered Pusfume card")
end

function M.install(registry)
    if not HeroWindowCharacterSelectionConsole then
        mod:warning("[pusfume] Hero selector class is unavailable; /pusfume remains available")
        return false
    end

    mod:hook_safe(HeroWindowCharacterSelectionConsole, "_setup_hero_selection_widgets", function(window)
        move_card_to_top_right(window, registry)
    end)

    return true
end

return M
