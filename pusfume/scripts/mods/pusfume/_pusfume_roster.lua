local mod = get_mod("pusfume")

-- Optional layer that opens every hero's weapons to Pusfume once his
-- first-person hands are a standard human hero rig (issue #35). Two concerns:
--   1. Allowlist: append Pusfume's career to each hero weapon's `can_wield`,
--      exactly the vanilla mechanism wt/CWV override (item.data.can_wield is the
--      per-item career roster the inventory filters and equip checks read).
--   2. Wield-anim wire safety: a cross-character weapon fires third-person anim
--      events authored for hero bodies. On Pusfume's Skaven 3P body those events
--      may be absent from NetworkLookup.anims, and the vanilla send paths index
--      that raising metatable before encoding the RPC, so an unknown event CTDs
--      every decoding peer. Skip such an event sender-side (crash floor).
--
-- The allowlist half uses one build-time switch (see _pusfume_roster_config),
-- enabled for this friends-only human-hands test. The wire-safety half installs
-- unconditionally: it is inert while the hard allowlist stands and becomes the
-- crash floor the moment the roster opens.

local config = mod:dofile("scripts/mods/pusfume/_pusfume_roster_config")

local M = {}

-- The five base hero profiles. A weapon item is a "hero weapon" (eligible to be
-- opened to Pusfume) when its can_wield names at least one career on one of
-- these profiles. Built from PROFILES_BY_NAME at runtime so DLC careers count.
local HERO_PROFILES = {
    "empire_soldier",
    "dwarf_ranger",
    "bright_wizard",
    "wood_elf",
    "witch_hunter",
}

local state = {
    career_name = nil,
    expanded_items = 0,
    hero_careers = nil,
    wire_safety_installed = false,
    skipped_3p_events = {},
    -- Pusfume's own per-slot weapon selection when the roster is open. Holds any
    -- backend id (a real hero weapon or an injected rat weapon); nil means the
    -- rat default still stands.
    selected = {
        slot_melee = nil,
        slot_ranged = nil,
    },
}

local function contains(list, value)
    for index = 1, #list do
        if list[index] == value then
            return true
        end
    end

    return false
end

function M.open_all_hero_weapons()
    return config.open_all_hero_weapons == true
end

local function hero_career_set()
    if state.hero_careers then
        return state.hero_careers
    end

    local careers = {}

    for _, profile_name in ipairs(HERO_PROFILES) do
        local profile = PROFILES_BY_NAME and PROFILES_BY_NAME[profile_name]

        for _, career in ipairs(profile and profile.careers or {}) do
            if type(career.name) == "string" and career.name ~= state.career_name then
                careers[career.name] = true
            end
        end
    end

    -- Cache only once the hero profiles have populated their careers, so an
    -- early call before profile registration does not freeze an empty set.
    if next(careers) then
        state.hero_careers = careers
    end

    return careers
end

local function is_hero_weapon(item, hero_careers)
    if item.slot_type ~= "melee" and item.slot_type ~= "ranged" then
        return false
    end

    local can_wield = item.can_wield

    if type(can_wield) ~= "table" or can_wield == CanWieldAllItemTemplates then
        return false
    end

    for index = 1, #can_wield do
        if hero_careers[can_wield[index]] then
            return true
        end
    end

    return false
end

function M.expand_can_wield(registry)
    state.career_name = registry.CAREER_NAME

    if not M.open_all_hero_weapons() then
        return 0
    end

    local hero_careers = hero_career_set()

    if not next(hero_careers) then
        return 0
    end

    local changed = 0

    for _, item in pairs(ItemMasterList or {}) do
        if is_hero_weapon(item, hero_careers)
                and not contains(item.can_wield, registry.CAREER_NAME) then
            item.can_wield[#item.can_wield + 1] = registry.CAREER_NAME
            changed = changed + 1
        end
    end

    state.expanded_items = state.expanded_items + changed

    if changed > 0 then
        mod:info("[pusfume] Opened %d hero weapon(s) to Pusfume via can_wield expansion",
            changed)
    end

    return changed
end

-- Every weapon item key Pusfume may wield in the given slot after expansion.
-- Feeds a roster-aware weapon grid / selection when the layer is delivered; an
-- empty list while the allowlist is closed.
function M.hero_weapon_item_keys(slot_name)
    local slot_type = slot_name == "slot_melee" and "melee"
        or slot_name == "slot_ranged" and "ranged"

    if not slot_type or not state.career_name then
        return {}
    end

    local keys = {}

    for key, item in pairs(ItemMasterList or {}) do
        if item.slot_type == slot_type and type(item.can_wield) == "table"
                and contains(item.can_wield, state.career_name) then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)

    return keys
end

-- Weapon selection store (only consulted while the roster is open). Real hero
-- weapon items live in the account backend; the injected rat weapons are merged
-- into the same store by _pusfume_backend, so get_item_from_id resolves both.
local function item_interface()
    local backend_manager = Managers and Managers.backend

    if not backend_manager then
        return nil
    end

    if backend_manager.get_interface then
        local ok, interface = pcall(backend_manager.get_interface, backend_manager, "items")

        if ok and interface then
            return interface
        end
    end

    return backend_manager._interfaces and backend_manager._interfaces.items
end

local function resolve_item(backend_id)
    local interface = item_interface()

    if interface and interface.get_item_from_id then
        local ok, item = pcall(interface.get_item_from_id, interface, backend_id)

        if ok then
            return item
        end
    end

    return nil
end

local function slot_type_for(slot_name)
    return slot_name == "slot_melee" and "melee"
        or slot_name == "slot_ranged" and "ranged"
        or nil
end

local function valid_for_slot(item, slot_name)
    local slot_type = slot_type_for(slot_name)
    local item_data = item and item.data

    return item_data ~= nil
        and item_data.slot_type == slot_type
        and type(item_data.can_wield) == "table"
        and contains(item_data.can_wield, state.career_name)
end

function M.selected_weapon_id(slot_name)
    return state.selected[slot_name]
end

function M.selected_weapon_item(slot_name)
    local backend_id = state.selected[slot_name]

    return backend_id and resolve_item(backend_id) or nil
end

function M.select_weapon(slot_name, backend_id)
    if not slot_type_for(slot_name) then
        return false
    end

    local item = resolve_item(backend_id)

    if valid_for_slot(item, slot_name) then
        state.selected[slot_name] = backend_id
        mod:info("[pusfume] roster equipped slot=%s backend_id=%s key=%s",
            slot_name, tostring(backend_id), tostring(item.key))

        return true
    end

    return false
end

function M.select_weapon_by_key(slot_name, item_key)
    if not slot_type_for(slot_name) then
        return false
    end

    local interface = item_interface()
    local items = interface and interface.get_all_backend_items
        and interface:get_all_backend_items()

    if type(items) == "table" then
        for backend_id, item in pairs(items) do
            if item and item.key == item_key and valid_for_slot(item, slot_name) then
                return M.select_weapon(slot_name, backend_id)
            end
        end
    end

    return false
end

local function is_pusfume_owner(owner_unit)
    if not state.career_name or not owner_unit or not Unit.alive(owner_unit) then
        return false
    end

    local career_extension = ScriptUnit.has_extension(owner_unit, "career_system")

    return career_extension ~= nil
        and type(career_extension.career_name) == "function"
        and career_extension:career_name() == state.career_name
end

-- rawget bypasses NetworkLookup.anims' raising __index, so probing an unknown
-- event never triggers the crash it would cause during RPC encoding.
local function networked_event_missing(event)
    return type(event) == "string" and NetworkLookup and NetworkLookup.anims
        and not rawget(NetworkLookup.anims, event)
end

local function note_skipped(event)
    if not state.skipped_3p_events[event] then
        state.skipped_3p_events[event] = true
        mod:info("[pusfume] Skipped cross-character 3P anim event missing from NetworkLookup.anims: %s",
            tostring(event))
    end
end

function M.install_wire_safety(registry)
    state.career_name = registry.CAREER_NAME

    if state.wire_safety_installed or not WeaponUnitExtension then
        return state.wire_safety_installed
    end

    -- _play_3p_anim carries the wielded event and owner explicitly; it is the
    -- send path for every attack/wield/reload 3P event.
    mod:hook(WeaponUnitExtension, "_play_3p_anim", function(func, self, event_3p, event,
            owner_unit, ...)
        if is_pusfume_owner(owner_unit) and networked_event_missing(event_3p) then
            note_skipped(event_3p)
            return
        end

        return func(self, event_3p, event, owner_unit, ...)
    end)

    -- _play_end_event_3p and trigger_anim_event resolve the owner from the
    -- extension and share a single (self, event) signature.
    for _, method_name in ipairs({ "_play_end_event_3p", "trigger_anim_event" }) do
        mod:hook(WeaponUnitExtension, method_name, function(func, self, event, ...)
            if is_pusfume_owner(self.owner_unit) and networked_event_missing(event) then
                note_skipped(event)
                return
            end

            return func(self, event, ...)
        end)
    end

    state.wire_safety_installed = true
    mod:info("[pusfume] installed cross-character 3P anim wire safety (3 send paths)")

    return true
end

function M.install(registry)
    state.career_name = registry.CAREER_NAME

    -- Crash floor first, always on: an opened weapon can never raise the
    -- NetworkLookup.anims metatable on a decoding peer.
    M.install_wire_safety(registry)

    local changed = M.expand_can_wield(registry)

    return {
        expanded_items = state.expanded_items,
        last_expansion = changed,
        open_all_hero_weapons = M.open_all_hero_weapons(),
        wire_safety_installed = state.wire_safety_installed,
    }
end

function M.status()
    return state
end

return M
