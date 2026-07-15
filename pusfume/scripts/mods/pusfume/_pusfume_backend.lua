local mod = get_mod("pusfume")

local M = {}
local status = {
    expected_hook_count = 23,
    expected_runtime_guard_count = 4,
    hook_count = 0,
    installed = false,
    runtime_guard_count = 0,
    runtime_guards_installed = false,
}

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

    status.hook_count = status.hook_count + 1
end

function M.loadout_status(registry)
    local backend_manager = Managers and Managers.backend
    local item_interface = backend_manager and backend_manager._interfaces
        and backend_manager._interfaces.items

    if not item_interface or not BackendUtils or not BackendUtils.get_loadout_item then
        return nil, "backend item data is not ready"
    end

    local resolved = {}
    local missing = {}

    for _, slot_name in ipairs({ "slot_melee", "slot_ranged" }) do
        local ok, item = pcall(BackendUtils.get_loadout_item, registry.CAREER_NAME, slot_name, false)

        if ok and item and item.data then
            resolved[#resolved + 1] = string.format("%s=%s", slot_name,
                tostring(item.data.name or item.backend_id))
        else
            missing[#missing + 1] = slot_name
        end
    end

    if #missing > 0 then
        return false, "unresolved " .. table.concat(missing, ", ")
    end

    return true, table.concat(resolved, " ")
end

function M.install_runtime_guards(registry)
    if status.runtime_guards_installed then
        return true
    end

    if not BackendUtils then
        return false
    end

    -- Alias at the stable outer API so per-career loadout mods never see Pusfume
    -- as independent storage and cannot serve an unrelated career's weapons.
    mod:hook(BackendUtils, "get_loadout_item_id", function(func, career_name, ...)
        return func(alias_career(career_name, registry), ...)
    end)
    status.runtime_guard_count = status.runtime_guard_count + 1

    mod:hook(BackendUtils, "get_loadout_item", function(func, career_name, ...)
        return func(alias_career(career_name, registry), ...)
    end)
    status.runtime_guard_count = status.runtime_guard_count + 1

    mod:hook(BackendUtils, "set_loadout_item", function(func, backend_id, career_name, ...)
        return func(backend_id, alias_career(career_name, registry), ...)
    end)
    status.runtime_guard_count = status.runtime_guard_count + 1

    mod:hook(BackendUtils, "try_set_loadout_item", function(func, career_name, ...)
        return func(alias_career(career_name, registry), ...)
    end)
    status.runtime_guard_count = status.runtime_guard_count + 1

    status.runtime_guards_installed = true
    registry.set_loadout_validator(function()
        return M.loadout_status(registry)
    end)

    mod:info("[pusfume] installed BackendUtils donor guards=%d/%d",
        status.runtime_guard_count, status.expected_runtime_guard_count)

    return true
end

function M.install(registry)
    if status.installed then
        return status
    end

    mod:hook("BackendInterfaceItemPlayfab", "get_loadout", function(func, self, ...)
        local loadouts = func(self, ...)

        if type(loadouts) == "table" and loadouts[registry.DONOR_CAREER_NAME] then
            loadouts[registry.CAREER_NAME] = loadouts[registry.DONOR_CAREER_NAME]
        end

        return loadouts
    end)
    status.hook_count = status.hook_count + 1

    mod:hook("BackendInterfaceItemPlayfab", "get_bot_loadout", function(func, self, ...)
        local loadouts = func(self, ...)

        if type(loadouts) == "table" and loadouts[registry.DONOR_CAREER_NAME] then
            loadouts[registry.CAREER_NAME] = loadouts[registry.DONOR_CAREER_NAME]
        end

        return loadouts
    end)
    status.hook_count = status.hook_count + 1

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
    status.hook_count = status.hook_count + 1

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

    status.installed = true

    mod:info("[pusfume] installed PlayFab donor adapters hooks=%d/%d",
        status.hook_count, status.expected_hook_count)

    return status
end

function M.status()
    return status
end

return M
