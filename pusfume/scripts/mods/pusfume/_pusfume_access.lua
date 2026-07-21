local mod = get_mod("pusfume")
local localization = mod:dofile("scripts/mods/pusfume/pusfume_localization")

local M = {}
local pending_request

local function profile_requester()
    local network_manager = Managers.state and Managers.state.network
    local network = network_manager and (network_manager.network_server or network_manager.network_client)

    return network and network:profile_requester()
end

function M.install(registry, career_index, ui)
    local global_strings = {}

    -- Vanilla career panels call the game-global Localize rather than
    -- VMF's private mod:localize surface. Derive both paths from one table.
    for key, translations in pairs(localization) do
        if type(translations) == "table" and type(translations.en) == "string" then
            global_strings[key] = translations.en
        end
    end

    mod:hook(_G, "Localize", function(func, key, ...)
        return global_strings[key] or func(key, ...)
    end)

    mod:command("pusfume", "Switch to the Pusfume prototype career.", function()
        local player = Managers.player and Managers.player:local_player()
        local requester = profile_requester()
        local supported, mechanism_name = registry.is_supported_mechanism()

        if not supported then
            mod:echo(string.format("Pusfume currently supports Adventure/Keep only (current mechanism: %s).",
                tostring(mechanism_name)))
            return
        end

        if not player or not requester then
            mod:echo("Pusfume can only be selected after entering the keep or a mission.")
            return
        end

        local peer_id = player:network_id() or Network.peer_id()
        local local_player_id = player.local_player_id and player:local_player_id() or 1

        pending_request = {
            id = (requester._request_id or 0) + 1,
            requester = requester,
        }

        mod:echo("Requesting Pusfume from the host.")
        requester:request_profile(peer_id, local_player_id, registry.PROFILE_NAME, registry.CAREER_NAME, true)
    end)

    mod:command("pusfume_status", "Print Pusfume registration diagnostics.", function()
        local player = Managers.player and Managers.player:local_player()
        local active_career

        if player and player:profile_index() and player:career_index() then
            local profile = SPProfiles[player:profile_index()]
            local career = profile and profile.careers[player:career_index()]

            active_career = career and career.name
        end

        local current_index = registry.find_career_index() or career_index
        local _, mechanism_name = registry.is_supported_mechanism()
        local ui_status = ui.status()

        mod:echo(string.format(
            "Pusfume index=%d active=%s donor=%s mechanism=%s UI(card=%s selected=%s).",
            current_index, tostring(active_career or "none"), registry.DONOR_CAREER_NAME,
            tostring(mechanism_name), tostring(ui_status.card_seen), tostring(ui_status.selection_seen)))
    end)

    -- Issue #42 probe: the constant glow VFX is not spawned by any Pusfume Lua
    -- (no particle creation, overcharge is heat-gated screen-space, the abilities
    -- are gameplay buffs, cosmetics carry no effect fields), so it rides a
    -- compiled dark_pact skaven unit's flow. Retail has no per-unit particle
    -- enumeration, so this dumps the total world particle count plus the
    -- attachment/weapon units to name the source by elimination.
    mod:command("pusfume_glow_probe",
        "Hunt the constant glow VFX: report world particle count + Pusfume attachment/weapon units.",
        function()
            local player = Managers.player and Managers.player:local_player()
            local unit = player and player.player_unit

            if not unit or not Unit.alive(unit) then
                mod:echo("Pusfume glow probe: no local player unit; run it as Pusfume in the Keep or a mission.")
                return
            end

            -- Total live world particles. Stand still in an EMPTY Keep (no allies,
            -- not firing): a steady nonzero count is the glow's particle system.
            -- Re-run on a vanilla Bardin career to prove the delta is Pusfume's.
            local world = Managers.world and Managers.world:world("level_world")
            local particles = world and World.num_particles(world)
            mod:echo("Pusfume glow probe: world particles=%s", tostring(particles or "n/a"))

            -- First-person unit = the dark_pact skaven base/arms; a Pactsworn
            -- ambient warpstone glow would ride this compiled unit's flow.
            local first_person = ScriptUnit.has_extension(unit, "first_person_system")
            local first_person_unit = first_person
                and type(first_person.get_first_person_unit) == "function"
                and first_person:get_first_person_unit()
            mod:echo("  first_person(skaven arms) alive=%s",
                tostring((first_person_unit and Unit.alive(first_person_unit)) or false))

            -- Equipment slot units change per weapon, so a glow riding one of
            -- these is NOT the weapon-independent source; listed to rule slots out.
            local inventory = ScriptUnit.has_extension(unit, "inventory_system")
            local equipment = inventory and type(inventory.equipment) == "function"
                and inventory:equipment()
            local slots = equipment and equipment.slots

            if slots then
                for slot_name, slot_data in pairs(slots) do
                    if type(slot_data) == "table" then
                        local item = slot_data.item_data and slot_data.item_data.key
                        local unit_1p = slot_data.right_unit_1p or slot_data.left_unit_1p
                        local unit_3p = slot_data.right_unit_3p or slot_data.left_unit_3p

                        if item or unit_1p or unit_3p then
                            mod:echo("  slot=%s item=%s u1p=%s u3p=%s",
                                tostring(slot_name), tostring(item or "-"),
                                tostring((unit_1p and Unit.alive(unit_1p)) or false),
                                tostring((unit_3p and Unit.alive(unit_3p)) or false))
                        end
                    end
                end
            end

            mod:echo("Pusfume glow probe done. Nonzero idle particles in an empty Keep = "
                .. "a compiled-unit VFX (top suspect: the skaven 1P arms flow). "
                .. "Share the count and any weapon-slot units flagged alive.")
        end)

    if ProfileRequester then
        mod:hook_safe(ProfileRequester, "rpc_request_profile_reply", function(requester, channel_id, local_player_id,
                request_id, profile_index, response_career_index, force_respawn, result_id)
            if not pending_request or pending_request.requester ~= requester or pending_request.id ~= request_id then
                return
            end

            pending_request = nil

            local result = ProfileRequester.REQUEST_RESULTS[result_id] or "unknown"
            local expected_profile_index = FindProfileIndex(registry.PROFILE_NAME)
            local expected_career_index = registry.find_career_index()

            if profile_index == expected_profile_index and response_career_index == expected_career_index then
                mod:echo(string.format("Pusfume host response: %s.", result))
            else
                mod:echo("Pusfume request returned an unexpected profile; run /pusfume_preflight.")
            end
        end)
    end
end

return M
