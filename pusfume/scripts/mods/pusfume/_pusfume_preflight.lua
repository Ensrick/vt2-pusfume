local mod = get_mod("pusfume")

local M = {}

local function add(checks, name, status, detail)
    checks[#checks + 1] = {
        detail = detail,
        name = name,
        status = status,
    }
end

local function backend_runtime_check(checks, registry)
    local backend_manager = Managers and Managers.backend

    if not backend_manager or not backend_manager.get_interface then
        add(checks, "backend data", "WARN", "not initialized; rerun in the Keep")
        return
    end

    local ok, item_interface = pcall(backend_manager.get_interface, backend_manager, "items")

    if not ok or not item_interface then
        add(checks, "backend data", "WARN", "item interface is not ready")
        return
    end

    local donor_ok, donor_loadout = pcall(item_interface.get_loadout_by_career_name,
        item_interface, registry.DONOR_CAREER_NAME, false)
    local pusfume_ok, pusfume_loadout = pcall(item_interface.get_loadout_by_career_name,
        item_interface, registry.CAREER_NAME, false)

    if donor_loadout and pusfume_loadout then
        add(checks, "backend data", "PASS", "donor loadout is exposed as pusfume")
    elseif donor_ok and pusfume_ok then
        add(checks, "backend data", "WARN", "loadouts are not materialized yet; rerun in the Keep")
    else
        add(checks, "backend data", "FAIL", "donor loadout adapter raised an error")
    end
end

function M.collect(registry, career_index, backend, compat, ui)
    local checks = {}
    local career = CareerSettings and CareerSettings[registry.CAREER_NAME]
    local donor = CareerSettings and CareerSettings[registry.DONOR_CAREER_NAME]
    local profile = PROFILES_BY_NAME and PROFILES_BY_NAME[registry.PROFILE_NAME]
    local actual_index = registry.find_career_index()

    add(checks, "career registry", career and donor and "PASS" or "FAIL",
        career and donor and "custom and donor settings exist" or "career settings are missing")
    add(checks, "career index", actual_index == career_index and "PASS" or "FAIL",
        string.format("expected=%s actual=%s", tostring(career_index), tostring(actual_index)))
    add(checks, "reverse lookup",
        PROFILES_BY_CAREER_NAMES and PROFILES_BY_CAREER_NAMES[registry.CAREER_NAME] == profile and "PASS" or "FAIL",
        "PROFILES_BY_CAREER_NAMES points to Bardin")

    local has_states = career and type(career.character_state_list) == "table"
        and #career.character_state_list > 0 and type(career.camera_state_list) == "table"
        and #career.camera_state_list > 0
    add(checks, "player states", has_states and "PASS" or "FAIL", "character and camera state lists")

    local talent_trees = career and TalentTrees and TalentTrees[career.profile_name]
    local talent_tree = talent_trees and talent_trees[career.talent_tree_index]
    local has_gameplay = career and career.activated_ability and career.passive_ability and talent_tree
    add(checks, "gameplay donor", has_gameplay and "PASS" or "FAIL", "ability, passive, and talent tree")

    local permissions = registry.item_permission_status()
    local permission_status = permissions.eligible > 0 and permissions.missing == 0 and "PASS" or "FAIL"
    add(checks, "item permissions", permission_status,
        string.format("configured=%d eligible=%d missing=%d", permissions.configured,
            permissions.eligible, permissions.missing))

    local backend_status = backend.status()
    add(checks, "backend hooks",
        backend_status.installed and backend_status.hook_count == backend_status.expected_hook_count and "PASS" or "FAIL",
        string.format("installed=%s hooks=%d/%d", tostring(backend_status.installed),
            backend_status.hook_count, backend_status.expected_hook_count))

    local aliases = compat.status().aliases
    local bot_aliases = aliases["bot ability action"] and aliases["bot ability condition"]
        and aliases["bot ability category"]
    add(checks, "bot takeover", bot_aliases and "PASS" or "WARN",
        bot_aliases and "Ranger Veteran ability behavior aliased" or "bot tables not loaded yet")

    local ui_status = ui.status()
    add(checks, "five-row grid hook", ui_status.legacy_hook_installed and "PASS" or "FAIL",
        ui_status.legacy_hook_installed and "CharacterSelectionStateCharacter hooked" or "class unavailable")
    add(checks, "five-row grid card", ui_status.legacy_card_seen and "PASS" or "WARN",
        ui_status.legacy_card_seen and string.format("overflow row=%d column=%d",
            ui_status.legacy_target_row, ui_status.target_column)
            or "not rendered yet; reopen the selection grid and rerun")
    add(checks, "Hero window hook", ui_status.modern_hook_installed and "PASS" or "WARN",
        ui_status.modern_hook_installed and "HeroWindowCharacterSelectionConsole hooked"
            or "class not loaded in this menu path")

    local supported, mechanism_name = registry.is_supported_mechanism()
    add(checks, "mechanism", supported and "PASS" or "FAIL",
        string.format("%s (Adventure/Keep supported)", tostring(mechanism_name)))

    local network_ready = type(career_index_from_name) == "function" and ProfileRequester
        and type(ProfileRequester.request_profile) == "function"
    add(checks, "profile request", network_ready and "PASS" or "FAIL", "host-mediated selection path")

    backend_runtime_check(checks, registry)

    return checks
end

function M.summarize(checks)
    local totals = {
        FAIL = 0,
        PASS = 0,
        WARN = 0,
    }

    for _, check in ipairs(checks) do
        totals[check.status] = totals[check.status] + 1
    end

    return totals
end

function M.install(registry, career_index, backend, compat, ui)
    mod:command("pusfume_preflight", "Run Pusfume registration and runtime checks.", function()
        registry.refresh_item_permissions()
        compat.install(registry)
        ui.install(registry)

        local checks = M.collect(registry, career_index, backend, compat, ui)

        for _, check in ipairs(checks) do
            mod:echo(string.format("[%s] %s: %s", check.status, check.name, check.detail))
        end

        local totals = M.summarize(checks)

        mod:echo(string.format("Pusfume preflight: %d PASS, %d WARN, %d FAIL.",
            totals.PASS, totals.WARN, totals.FAIL))
    end)
end

function M.log_summary(registry, career_index, backend, compat, ui)
    local totals = M.summarize(M.collect(registry, career_index, backend, compat, ui))

    mod:info("[pusfume] preflight summary pass=%d warn=%d fail=%d", totals.PASS, totals.WARN, totals.FAIL)
end

return M
