local mod = get_mod("pusfume")

local M = {}

local state = {
    aliases = {},
}

local function alias_entry(target, label, registry)
    if type(target) ~= "table" or target[registry.DONOR_CAREER_NAME] == nil then
        state.aliases[label] = false
        return false
    end

    target[registry.CAREER_NAME] = target[registry.DONOR_CAREER_NAME]
    state.aliases[label] = true

    return true
end

function M.install(registry)
    alias_entry(CareerConstants, "career constants", registry)
    alias_entry(CareerNameAchievementMapping, "achievement mapping", registry)

    if UISettings then
        alias_entry(UISettings.default_loadout_settings, "default loadout UI", registry)
    end

    if BotActions and BotActions.default then
        alias_entry(BotActions.default.use_ability, "bot ability action", registry)
    end

    if BTConditions then
        alias_entry(BTConditions.can_activate, "bot ability condition", registry)
        alias_entry(BTConditions.reload_ability_weapon, "bot ability reload", registry)

        local category_aliased = false

        for _, category in pairs(BTConditions.ability_check_categories or {}) do
            if category[registry.DONOR_CAREER_NAME] then
                category[registry.CAREER_NAME] = true
                category_aliased = true
            end
        end

        state.aliases["bot ability category"] = category_aliased
    end

    mod:info("[pusfume] refreshed runtime donor aliases")

    return state
end

function M.status()
    return state
end

return M
