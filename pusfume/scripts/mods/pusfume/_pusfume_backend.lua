local mod = get_mod("pusfume")

local M = {}

local function alias_career(career_name, registry)
    if career_name == registry.CAREER_NAME then
        return registry.DONOR_CAREER_NAME
    end

    return career_name
end

local function hook_career_first(class_name, method_name, registry)
    mod:hook(class_name, method_name, function(func, self, career_name, ...)
        return func(self, alias_career(career_name, registry), ...)
    end)
end

function M.install(registry)
    mod:hook("BackendInterfaceItemPlayfab", "get_loadout", function(func, self, ...)
        local loadouts = func(self, ...)

        if type(loadouts) == "table" and loadouts[registry.DONOR_CAREER_NAME] then
            loadouts[registry.CAREER_NAME] = loadouts[registry.DONOR_CAREER_NAME]
        end

        return loadouts
    end)

    mod:hook("BackendInterfaceItemPlayfab", "get_bot_loadout", function(func, self, ...)
        local loadouts = func(self, ...)

        if type(loadouts) == "table" and loadouts[registry.DONOR_CAREER_NAME] then
            loadouts[registry.CAREER_NAME] = loadouts[registry.DONOR_CAREER_NAME]
        end

        return loadouts
    end)

    local item_methods = {
        "set_loadout_index",
        "add_loadout",
        "delete_loadout",
        "set_default_override",
        "get_default_override",
        "get_career_loadouts",
        "get_selected_career_loadout",
        "get_default_loadouts",
        "get_loadout_by_career_name",
        "get_loadout_item_id",
        "get_cosmetic_loadout",
    }

    for _, method_name in ipairs(item_methods) do
        hook_career_first("BackendInterfaceItemPlayfab", method_name, registry)
    end

    mod:hook("BackendInterfaceItemPlayfab", "set_loadout_item", function(func, self, item_id, career_name, ...)
        return func(self, item_id, alias_career(career_name, registry), ...)
    end)

    local talent_methods = {
        "set_default_override",
        "get_talent_ids",
        "get_talent_tree",
        "set_talents",
        "get_talents",
        "get_bot_talents",
        "get_default_talents",
        "get_career_talents",
        "get_career_talent_ids",
    }

    for _, method_name in ipairs(talent_methods) do
        hook_career_first("BackendInterfaceTalentsPlayfab", method_name, registry)
    end

    mod:info("[pusfume] installed PlayFab donor adapters")
end

return M

