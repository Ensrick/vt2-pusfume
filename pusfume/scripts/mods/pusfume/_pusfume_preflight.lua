local mod = get_mod("pusfume")
local buff_perks = require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")

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
    local direct_loadouts = item_interface:get_loadout()
    local direct_loadout = direct_loadouts and direct_loadouts[registry.CAREER_NAME]

    if donor_loadout and pusfume_loadout and type(direct_loadout) == "table" then
        add(checks, "backend data", "PASS", "donor loadout is exposed through method and table APIs")
    elseif donor_ok and pusfume_ok then
        add(checks, "backend data", "WARN", "loadout method or table alias is not materialized yet")
    else
        add(checks, "backend data", "FAIL", "donor loadout adapter raised an error")
    end
end

function M.collect(registry, career_index, backend, compat, ui, native)
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

    local color_definitions = Colors and Colors.color_definitions
    local career_color = color_definitions and color_definitions[registry.CAREER_NAME]
    local donor_color = color_definitions and color_definitions[registry.DONOR_CAREER_NAME]
    local has_career_color = type(career_color) == "table" and career_color ~= donor_color
        and type(career_color[1]) == "number" and type(career_color[2]) == "number"
        and type(career_color[3]) == "number" and type(career_color[4]) == "number"
    add(checks, "career color", has_career_color and "PASS" or "FAIL",
        has_career_color and string.format("RGBA=%d,%d,%d,%d", career_color[1], career_color[2],
            career_color[3], career_color[4])
            or "distinct four-channel Colors.color_definitions entry is missing")

    local has_states = career and type(career.character_state_list) == "table"
        and #career.character_state_list > 0 and type(career.camera_state_list) == "table"
        and #career.camera_state_list > 0
    add(checks, "player states", has_states and "PASS" or "FAIL", "character and camera state lists")

    local talent_trees = career and TalentTrees and TalentTrees[career.profile_name]
    local talent_tree = talent_trees and talent_trees[career.talent_tree_index]
    local active_ability = career and career.activated_ability and career.activated_ability[1]
    local passive_ability = career and career.passive_ability
    local passive_class = passive_ability and passive_ability.passive_ability_classes
        and passive_ability.passive_ability_classes[1]
    local has_gameplay = active_ability and active_ability.ability_class == CareerAbilityPusfumeIngenuity
        and active_ability.cooldown == 90
        and passive_ability == PassiveAbilitySettings.pusfume
        and passive_class and passive_class.ability_class == PassiveAbilityPusfumeAggressiveIteration
        and talent_tree
    add(checks, "career kit", has_gameplay and "PASS" or "FAIL",
        "v2 Aggressive Iteration, Moulder Ingenuity, perks, and current talent tree")
    add(checks, "career health", career and career.attributes and career.attributes.max_hp == 100 and "PASS" or "FAIL",
        "v2 specification requires 100 maximum health")

    local localization_keys = {
        "pusfume_character_name",
        "pusfume_career_name",
        "pusfume_passive_name",
        "pusfume_passive_description",
        "pusfume_active_name",
        "pusfume_active_description",
        "pusfume_hell_pit_native_name",
        "pusfume_hell_pit_native_description",
        "pusfume_scaredy_rat_name",
        "pusfume_scaredy_rat_description",
        "pusfume_swift_claws_name",
        "pusfume_swift_claws_description",
        "pusfume_ingenuity_armed_placeholder",
    }
    local unresolved_localization

    for _, key in ipairs(localization_keys) do
        local value = Localize(key)

        if type(value) ~= "string" or value == "<" .. key .. ">" then
            unresolved_localization = key
            break
        end
    end

    add(checks, "career localization", not unresolved_localization and "PASS" or "FAIL",
        unresolved_localization and "global Localize missed " .. unresolved_localization
            or "identity, abilities, perks, and quests resolve through global Localize")

    local iteration_proc_ready = ProcFunctions
        and type(ProcFunctions.pusfume_aggressive_iteration_proc) == "function"
    add(checks, "Aggressive Iteration proc", iteration_proc_ready and "PASS" or "FAIL",
        iteration_proc_ready and "special-kill capture callback is registered"
            or "special-kill callback is missing from the engine proc registry")

    local custom_buffs = {
        "pusfume_aggressive_iteration_listener",
        "pusfume_aggressive_iteration_ready",
        "pusfume_scaredy_rat_listener",
        "pusfume_scaredy_rat_speed",
        "pusfume_swift_claws",
    }
    local custom_buffs_ready = true

    for _, buff_name in ipairs(custom_buffs) do
        local template = BuffTemplates and BuffTemplates[buff_name]

        if not template or type(template.buffs) ~= "table" or not template.buffs[1]
                or template.buffs[1].name ~= buff_name
                or not NetworkLookup or not rawget(NetworkLookup.buff_templates, buff_name) then
            custom_buffs_ready = false
            break
        end
    end

    add(checks, "career buff registry", custom_buffs_ready and "PASS" or "FAIL",
        custom_buffs_ready and "five v2 normalized templates have synchronized native lookup IDs"
            or "a custom template name or network lookup is missing")

    local scaredy_template = BuffTemplates and BuffTemplates.pusfume_scaredy_rat_listener
    local scaredy_perks = scaredy_template and scaredy_template.buffs[1].perks
    local swift_template = BuffTemplates and BuffTemplates.pusfume_swift_claws
    local swift_multiplier = swift_template and swift_template.buffs[1].multiplier
    local v2_perks_ready = scaredy_perks and scaredy_perks[1] == buff_perks.no_moveslow_on_hit
        and swift_multiplier == -0.15
    add(checks, "v2 passive perks", v2_perks_ready and "PASS" or "FAIL",
        "Scaredy-rat ignores hit slowdown and Swift Claws grants 15% faster reload")

    local permissions = registry.item_permission_status()
    local permission_status = permissions.eligible > 0 and permissions.missing == 0 and "PASS" or "FAIL"
    add(checks, "item permissions", permission_status,
        string.format("configured=%d eligible=%d missing=%d", permissions.configured,
            permissions.eligible, permissions.missing))

    local backend_status = backend.status()
    local backend_hooks_ready = backend_status.installed
        and backend_status.hook_count == backend_status.expected_hook_count
        and backend_status.runtime_guards_installed
        and backend_status.runtime_guard_count == backend_status.expected_runtime_guard_count
    add(checks, "backend hooks",
        backend_hooks_ready and "PASS" or "FAIL",
        string.format("PlayFab=%d/%d BackendUtils=%d/%d", backend_status.hook_count,
            backend_status.expected_hook_count, backend_status.runtime_guard_count,
            backend_status.expected_runtime_guard_count))

    local weapons_ready, weapons_detail = backend.loadout_status(registry)
    add(checks, "spawn weapons", weapons_ready == nil and "WARN" or weapons_ready and "PASS" or "FAIL",
        weapons_detail)

    local aliases = compat.status().aliases
    local bot_aliases = aliases["bot ability action"] and aliases["bot ability condition"]
        and aliases["bot ability category"]
    add(checks, "bot takeover", bot_aliases and "PASS" or "WARN",
        bot_aliases and "Ranger Veteran ability behavior aliased" or "bot tables not loaded yet")

    local ui_status = ui.status()
    local native_status = native.status()
    local native_enabled = native.enabled()
    local native_ready = native_enabled and native_status.resource_available and native_status.hook_installed
    add(checks, "native third-person unit",
        native_ready and "PASS" or "WARN",
        native_ready and "custom cosmetic resource and attachment hook are ready"
            or native_enabled and "custom cosmetic registered; attachment hook is not ready"
            or "source-only fallback active; use Build-NativePusfume.ps1 for a model test")
    local first_person_status = native.first_person_status()

    if first_person_status.enabled then
        local first_person_ready = first_person_status.resource_available
            and first_person_status.hook_installed
        local first_person_state = not first_person_ready and "FAIL"
            or first_person_status.materials_applied and "PASS"
            or "WARN"
        local first_person_detail = not first_person_status.resource_available
            and "compiled first-person arms unit is unavailable"
            or not first_person_status.hook_installed
                and "PlayerUnitFirstPerson hook is unavailable"
            or first_person_status.materials_applied
                and "Janfon arms are attached and their direct-UV material is applied"
            or first_person_status.package_loaded
                and "material package is loaded; spawn Pusfume to apply it"
            or "unit and hook are ready; spawn Pusfume to load and apply the material"

        add(checks, "native first-person arms", first_person_state, first_person_detail)
    end
    local donor_status = native.donor_status()

    if donor_status.enabled then
        -- The donor material only becomes gettable once its package is loaded,
        -- so a missing material before the first Pusfume spawn is expected and
        -- must not fail the whole preflight (2026-07-16 05:30 log false FAIL).
        local donor_state, donor_detail

        if not donor_status.package_ok then
            donor_state = "FAIL"
            donor_detail = "Globadier donor package is missing from installed game data"
        elseif not donor_status.whisker_package_ok then
            donor_state = "FAIL"
            donor_detail = "Laurel whisker donor package is missing from installed game data"
        elseif donor_status.package_loaded and not donor_status.material_ok then
            donor_state = "FAIL"
            donor_detail = "donor package is loaded but its outfit material did not resolve"
        elseif donor_status.applied then
            donor_state = "PASS"
            donor_detail = "donor material resolved and applied to the native mesh"
        elseif donor_status.material_ok then
            donor_state = "PASS"
            donor_detail = "donor content resolves; spawn Pusfume to apply it"
        else
            donor_state = "WARN"
            donor_detail = "donor package resolves; material loads with it when Pusfume spawns"
        end

        add(checks, "donor material content", donor_state, donor_detail)

        if donor_status.applied then
            add(checks, "whisker material", donor_status.whisker_applied and "PASS" or "FAIL",
                donor_status.whisker_applied
                    and "native skinned-alpha child is applied to p_whiskers"
                    or "native whisker child did not apply")
        end
    end

    local animation_status = native.animation_status()

    if animation_status.locomotion_events_enabled then
        local probes_off = not animation_status.manual_clip_probe
            and not animation_status.manual_skin_probe
        local locomotion_detail

        if not probes_off then
            locomotion_detail = "a manual diagnostic probe overrides the locomotion controller"
        elseif animation_status.locomotion_events_available then
            locomotion_detail = "compiled controller exposes idle/walk events; driver is active"
        else
            locomotion_detail = "spawn Pusfume to verify the compiled idle/walk events"
        end

        add(checks, "locomotion animation events",
            probes_off and (animation_status.locomotion_events_available and "PASS" or "WARN") or "WARN",
            locomotion_detail)
    end

    add(checks, "five-row grid hook", ui_status.legacy_hook_installed and "PASS" or "FAIL",
        ui_status.legacy_hook_installed and "CharacterSelectionStateCharacter hooked" or "class unavailable")
    add(checks, "five-row grid card", ui_status.legacy_card_seen and "PASS" or "WARN",
        ui_status.legacy_card_seen and string.format("overflow row=%d column=%d",
            ui_status.legacy_target_row, ui_status.target_column)
            or "not rendered yet; reopen the selection grid and rerun")
    add(checks, "Pusfume preview hook", ui_status.preview_hook_installed and "PASS" or "FAIL",
        ui_status.preview_hook_installed and "donor menu spawn is intercepted" or "preview hook unavailable")
    if native_enabled then
        add(checks, "native hero preview", ui_status.native_preview_enabled and "PASS" or "WARN",
            ui_status.native_preview_enabled and "stock 3D previewer requested the Pusfume cosmetic"
                or "select Pusfume, then rerun preflight")
    else
        add(checks, "Pusfume preview widget", ui_status.preview_widget_seen and "PASS" or "WARN",
            ui_status.preview_widget_seen and "model-derived texture widget initialized"
                or "not rendered yet; reopen the selection grid and rerun")
        add(checks, "donor preview suppression", ui_status.donor_preview_suppressed and "PASS" or "WARN",
            ui_status.donor_preview_suppressed and "Ranger Veteran menu unit cleared"
                or "select Pusfume, then rerun preflight")
    end
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

function M.install(registry, career_index, backend, compat, ui, native)
    mod:command("pusfume_preflight", "Run Pusfume registration and runtime checks.", function()
        registry.refresh_item_permissions()
        backend.install_runtime_guards(registry)
        compat.install(registry)
        ui.install(registry, native)

        local checks = M.collect(registry, career_index, backend, compat, ui, native)

        for _, check in ipairs(checks) do
            mod:echo("%s", string.format(
                "[%s] %s: %s", check.status, check.name, check.detail))
        end

        local totals = M.summarize(checks)

        mod:echo("%s", string.format(
            "Pusfume preflight: %d PASS, %d WARN, %d FAIL.",
            totals.PASS, totals.WARN, totals.FAIL))
    end)
end

function M.log_summary(registry, career_index, backend, compat, ui, native)
    local totals = M.summarize(M.collect(registry, career_index, backend, compat, ui, native))

    mod:info("[pusfume] preflight summary pass=%d warn=%d fail=%d", totals.PASS, totals.WARN, totals.FAIL)
end

return M
