local mod = get_mod("pusfume")

local M = {}
local status = {
    expected_hook_count = 24,
    expected_runtime_guard_count = 5,
    hook_count = 0,
    installed = false,
    runtime_guard_count = 0,
    runtime_guards_installed = false,
    used_empty_loadout_fallback = false,
    wire_guard_installed = false,
    weapon_grid_guard_installed = false,
    stripped_sync_keys = {},
}

local function expose_donor_loadout(self, loadouts, registry, weapons)
    if type(loadouts) ~= "table" then
        return loadouts
    end

    local donor_loadout = loadouts[registry.DONOR_CAREER_NAME]

    -- Other loadout mods can replace the cloned return table after our hook.
    -- Consult the authoritative stores before installing an iterable fallback.
    if type(donor_loadout) ~= "table" and type(self._default_loadout_overrides) == "table" then
        donor_loadout = self._default_loadout_overrides[registry.DONOR_CAREER_NAME]
    end

    if type(donor_loadout) ~= "table" and type(self._loadouts) == "table" then
        donor_loadout = self._loadouts[registry.DONOR_CAREER_NAME]
    end

    if type(donor_loadout) ~= "table" then
        donor_loadout = {}

        if not status.used_empty_loadout_fallback then
            status.used_empty_loadout_fallback = true
            mod:warning("[pusfume] Donor loadout table was unavailable; installed an empty UI-safe alias")
        end
    end

    loadouts[registry.CAREER_NAME] = weapons.overlay_loadout(donor_loadout)

    return loadouts
end

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

function M.refresh_runtime_aliases(registry, weapons)
    local backend_manager = Managers and Managers.backend
    local item_interface = backend_manager and backend_manager._interfaces
        and backend_manager._interfaces.items

    if not item_interface then
        return false
    end

    local flat_stores = {
        "_loadouts",
        "_bot_loadouts",
        "_default_loadout_overrides",
    }

    for _, store_name in ipairs(flat_stores) do
        local store = item_interface[store_name]

        if type(store) == "table" and store[registry.DONOR_CAREER_NAME] ~= nil then
            store[registry.CAREER_NAME] = weapons.overlay_loadout(store[registry.DONOR_CAREER_NAME])
        end
    end

    for _, store_name in ipairs({ "_career_loadouts", "_default_loadouts" }) do
        local store = item_interface[store_name]

        if type(store) == "table" and store[registry.DONOR_CAREER_NAME] ~= nil then
            store[registry.CAREER_NAME] = weapons.overlay_loadout_collection(
                store[registry.DONOR_CAREER_NAME])
        end
    end

    local selected = item_interface._selected_career_custom_loadouts

    if type(selected) == "table" then
        selected[registry.CAREER_NAME] = selected[registry.DONOR_CAREER_NAME]
    end

    return true
end

function M.loadout_status(registry, weapons)
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

        local expected_key = weapons.ITEM_KEYS[slot_name]

        if ok and item and item.data and item.key == expected_key then
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

local function install_weapon_grid_guard(registry)
    if status.weapon_grid_guard_installed or not ItemGridUI then
        return status.weapon_grid_guard_installed
    end

    mod:hook(ItemGridUI, "change_item_filter", function(func, self, item_filter, ...)
        local profile = PROFILES_BY_NAME[self._hero_name]
        local career = profile and profile.careers[self._career_index]
        local is_weapon_filter = type(item_filter) == "string"
            and (string.find(item_filter, "slot_type == melee", 1, true)
                or string.find(item_filter, "slot_type == ranged", 1, true))

        if career and career.name == registry.CAREER_NAME and is_weapon_filter then
            item_filter = string.gsub(item_filter,
                "can_wield_by_current_hero", "can_wield_by_current_career")
        end

        return func(self, item_filter, ...)
    end)
    status.weapon_grid_guard_installed = true
    status.runtime_guard_count = status.runtime_guard_count + 1

    return true
end

function M.install_runtime_guards(registry, weapons)
    M.refresh_runtime_aliases(registry, weapons)
    install_weapon_grid_guard(registry)

    if status.runtime_guards_installed then
        return true
    end

    if not BackendUtils then
        return false
    end

    -- Alias at the stable outer API so per-career loadout mods never see Pusfume
    -- as independent storage and cannot serve an unrelated career's weapons.
    mod:hook(BackendUtils, "get_loadout_item_id", function(func, career_name, ...)
        local slot_name = select(1, ...)

        if career_name == registry.CAREER_NAME and weapons.is_weapon_slot(slot_name) then
            return weapons.backend_id_for_slot(slot_name)
        end

        return func(alias_career(career_name, registry), ...)
    end)
    status.runtime_guard_count = status.runtime_guard_count + 1

    mod:hook(BackendUtils, "get_loadout_item", function(func, career_name, ...)
        local slot_name = select(1, ...)

        if career_name == registry.CAREER_NAME and weapons.is_weapon_slot(slot_name) then
            return weapons.item_for_slot(slot_name)
        end

        return func(alias_career(career_name, registry), ...)
    end)
    status.runtime_guard_count = status.runtime_guard_count + 1

    mod:hook(BackendUtils, "set_loadout_item", function(func, backend_id, career_name, ...)
        local slot_name = select(1, ...)

        if career_name == registry.CAREER_NAME and weapons.is_weapon_slot(slot_name) then
            return backend_id == weapons.backend_id_for_slot(slot_name)
        end

        return func(backend_id, alias_career(career_name, registry), ...)
    end)
    status.runtime_guard_count = status.runtime_guard_count + 1

    mod:hook(BackendUtils, "try_set_loadout_item", function(func, career_name, ...)
        local slot_name = select(1, ...)
        local item_key = select(2, ...)

        if career_name == registry.CAREER_NAME and weapons.is_weapon_slot(slot_name) then
            if item_key == weapons.ITEM_KEYS[slot_name] then
                return weapons.item_for_slot(slot_name)
            end

            return nil
        end

        return func(alias_career(career_name, registry), ...)
    end)
    status.runtime_guard_count = status.runtime_guard_count + 1

    -- Wire safety, never toggle-gated: the loadout-sync RPC encoder indexes
    -- NetworkLookup.properties/traits, whose metatables RAISE on missing keys
    -- (live crash 2026-07-17: the Blightreaper event sword's
    -- woc_power_vs_order rode the shared Ranger Veteran loadout into
    -- Pusfume's resync). Vanilla never syncs such items down this path; the
    -- synthetic career does, and in coop the raise lands on every decoding
    -- peer. Filter unencodable keys out of the encoder's input, sender-side.
    -- rawget bypasses the raising __index, so membership probing is safe.
    if LoadoutUtils and NetworkLookup and not status.wire_guard_installed then
        mod:hook(LoadoutUtils, "properties_to_rpc_params", function(func, item)
            local properties = item and item.properties
            local traits = item and item.traits

            if not properties and not traits then
                return func(item)
            end

            local safe_properties = nil
            local safe_traits = nil
            local stripped = false

            if properties then
                safe_properties = {}

                for property_name, property_value in pairs(properties) do
                    if rawget(NetworkLookup.properties, property_name) then
                        safe_properties[property_name] = property_value
                    else
                        stripped = true

                        if not status.stripped_sync_keys[property_name] then
                            status.stripped_sync_keys[property_name] = true
                            mod:info("[pusfume] Stripped unencodable loadout property from sync: %s (item=%s)",
                                property_name, tostring(item.key))
                        end
                    end
                end
            end

            if traits then
                safe_traits = {}

                for i = 1, #traits do
                    local trait_name = traits[i]

                    if rawget(NetworkLookup.traits, trait_name) then
                        safe_traits[#safe_traits + 1] = trait_name
                    else
                        stripped = true

                        if not status.stripped_sync_keys[trait_name] then
                            status.stripped_sync_keys[trait_name] = true
                            mod:info("[pusfume] Stripped unencodable loadout trait from sync: %s (item=%s)",
                                trait_name, tostring(item.key))
                        end
                    end
                end
            end

            if not stripped then
                return func(item)
            end

            -- The encoder reads only item.properties and item.traits.
            return func({
                properties = safe_properties,
                traits = safe_traits,
            })
        end)

        status.wire_guard_installed = true
        mod:info("[pusfume] installed loadout sync wire guard")
    end

    status.runtime_guards_installed = true
    registry.set_loadout_validator(function()
        return M.loadout_status(registry, weapons)
    end)

    mod:info("[pusfume] installed BackendUtils donor guards=%d/%d",
        status.runtime_guard_count, status.expected_runtime_guard_count)

    return true
end

function M.install(registry, weapons)
    if status.installed then
        return status
    end

    mod:hook("BackendInterfaceItemPlayfab", "get_loadout", function(func, self, ...)
        local loadouts = func(self, ...)

        return expose_donor_loadout(self, loadouts, registry, weapons)
    end)
    status.hook_count = status.hook_count + 1

    mod:hook("BackendInterfaceItemPlayfab", "get_bot_loadout", function(func, self, ...)
        local loadouts = func(self, ...)

        return expose_donor_loadout(self, loadouts, registry, weapons)
    end)
    status.hook_count = status.hook_count + 1

    mod:hook("BackendInterfaceItemPlayfab", "get_all_backend_items", function(func, self, ...)
        return weapons.inject_backend_items(func(self, ...))
    end)
    status.hook_count = status.hook_count + 1

    local item_methods = {
        "set_loadout_index",
        "add_loadout",
        "delete_loadout",
        "set_default_override",
        "get_default_override",
        "get_selected_career_loadout",
        "get_cosmetic_loadout",
    }

    for _, method_name in ipairs(item_methods) do
        hook_career_first("BackendInterfaceItemPlayfab", method_name, registry)
    end

    for _, method_name in ipairs({ "get_career_loadouts", "get_default_loadouts" }) do
        mod:hook("BackendInterfaceItemPlayfab", method_name, function(func, self, career_name, ...)
            if career_name == registry.CAREER_NAME then
                return weapons.overlay_loadout_collection(
                    func(self, registry.DONOR_CAREER_NAME, ...))
            end

            return func(self, career_name, ...)
        end)
        status.hook_count = status.hook_count + 1
    end

    mod:hook("BackendInterfaceItemPlayfab", "get_loadout_by_career_name", function(func, self,
            career_name, ...)
        if career_name == registry.CAREER_NAME then
            return weapons.overlay_loadout(func(self, registry.DONOR_CAREER_NAME, ...))
        end

        return func(self, career_name, ...)
    end)
    status.hook_count = status.hook_count + 1

    mod:hook("BackendInterfaceItemPlayfab", "get_loadout_item_id", function(func, self,
            career_name, slot_name, ...)
        if career_name == registry.CAREER_NAME and weapons.is_weapon_slot(slot_name) then
            return weapons.backend_id_for_slot(slot_name)
        end

        return func(self, alias_career(career_name, registry), slot_name, ...)
    end)
    status.hook_count = status.hook_count + 1

    mod:hook("BackendInterfaceItemPlayfab", "set_loadout_item", function(func, self, item_id, career_name, ...)
        local slot_name = select(1, ...)

        if career_name == registry.CAREER_NAME and weapons.is_weapon_slot(slot_name) then
            return item_id == weapons.backend_id_for_slot(slot_name)
        end

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
