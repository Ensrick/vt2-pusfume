local mod = get_mod("pusfume")

local MOD_VERSION = "0.3.0-dev"

mod:info("[pusfume] loading v%s", MOD_VERSION)

local registry = mod:dofile("scripts/mods/pusfume/_pusfume_registry")
local assets = mod:dofile("scripts/mods/pusfume/_pusfume_assets")
local backend = mod:dofile("scripts/mods/pusfume/_pusfume_backend")
local access = mod:dofile("scripts/mods/pusfume/_pusfume_access")
local compat = mod:dofile("scripts/mods/pusfume/_pusfume_compat")
local preflight = mod:dofile("scripts/mods/pusfume/_pusfume_preflight")
local ui = mod:dofile("scripts/mods/pusfume/_pusfume_ui")
local career_index = registry.register()

assets.install()
backend.install(registry)
compat.install(registry)
ui.install(registry)
access.install(registry, career_index, ui)
preflight.install(registry, career_index, backend, compat, ui)

local function refresh_runtime_integrations()
    assets.install()
    compat.install(registry)
    ui.install(registry)
end

mod.on_all_mods_loaded = function()
    refresh_runtime_integrations()
    preflight.log_summary(registry, career_index, backend, compat, ui)
end

mod.on_game_state_changed = function()
    refresh_runtime_integrations()
end

mod:echo(string.format(
    "Pusfume prototype v%s loaded. Run /pusfume_preflight in the Keep before selecting the career.",
    MOD_VERSION))
