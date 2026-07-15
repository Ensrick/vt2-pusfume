local mod = get_mod("pusfume")

local M = {}
local pending_request

local function profile_requester()
    local network_manager = Managers.state and Managers.state.network
    local network = network_manager and (network_manager.network_server or network_manager.network_client)

    return network and network:profile_requester()
end

function M.install(registry, career_index, ui)
    local global_strings = {
        pusfume = "Pusfume",
        pusfume_description = "A devious Clan Moulder inventor testing unstable battlefield concoctions.",
    }

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
