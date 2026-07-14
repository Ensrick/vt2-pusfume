local mod = get_mod("pusfume")

local M = {}

local function profile_requester()
    local network_manager = Managers.state and Managers.state.network
    local network = network_manager and (network_manager.network_server or network_manager.network_client)

    return network and network:profile_requester()
end

function M.install(registry, career_index)
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

        if not player or not requester then
            mod:echo("Pusfume can only be selected after entering the keep or a mission.")
            return
        end

        local peer_id = player:network_id() or Network.peer_id()
        local local_player_id = player.local_player_id and player:local_player_id() or 1

        requester:request_profile(peer_id, local_player_id, registry.PROFILE_NAME, registry.CAREER_NAME, true)
        mod:echo("Requested Pusfume. The host will respawn you if the profile is available.")
    end)

    mod:command("pusfume_status", "Print Pusfume registration diagnostics.", function()
        local player = Managers.player and Managers.player:local_player()
        local active_career

        if player and player:profile_index() and player:career_index() then
            local profile = SPProfiles[player:profile_index()]
            local career = profile and profile.careers[player:career_index()]

            active_career = career and career.name
        end

        mod:echo(string.format("Pusfume registered at Bardin career %d; active career: %s; donor: %s.",
            career_index, tostring(active_career or "none"), registry.DONOR_CAREER_NAME))
    end)
end

return M

