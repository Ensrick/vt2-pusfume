local mod = get_mod("pusfume")

local MOD_VERSION = "0.6.55-dev"

mod:info("[pusfume] loading v%s", MOD_VERSION)

local registry = mod:dofile("scripts/mods/pusfume/_pusfume_registry")
local gameplay = mod:dofile("scripts/mods/pusfume/_pusfume_gameplay")
local assets = mod:dofile("scripts/mods/pusfume/_pusfume_assets")
local native_config = mod:dofile("scripts/mods/pusfume/_pusfume_native_config")
local native = mod:dofile("scripts/mods/pusfume/_pusfume_native")
local weapons = mod:dofile("scripts/mods/pusfume/_pusfume_weapons")
local roster = mod:dofile("scripts/mods/pusfume/_pusfume_roster")
local backend = mod:dofile("scripts/mods/pusfume/_pusfume_backend")
local access = mod:dofile("scripts/mods/pusfume/_pusfume_access")
local compat = mod:dofile("scripts/mods/pusfume/_pusfume_compat")
local preflight = mod:dofile("scripts/mods/pusfume/_pusfume_preflight")
local ui = mod:dofile("scripts/mods/pusfume/_pusfume_ui")
weapons.set_roster(roster)
assets.install()
gameplay.install()
native.install(registry, native_config)
weapons.install(registry)
local career_index = registry.register()
roster.install(registry)
backend.install(registry, weapons)
compat.install(registry)
ui.install(registry, native)
access.install(registry, career_index, ui)
preflight.install(registry, career_index, backend, compat, ui, native, weapons)

local function refresh_runtime_integrations()
    registry.refresh_career_color()
    registry.refresh_item_permissions()
    assets.install()
    native.install(registry, native_config)
    weapons.install(registry)
    roster.install(registry)
    backend.install(registry, weapons)
    backend.install_runtime_guards(registry, weapons)
    compat.install(registry)
    ui.install(registry, native)
end

mod.on_all_mods_loaded = function()
    refresh_runtime_integrations()
    preflight.log_summary(registry, career_index, backend, compat, ui, native, weapons)
end

mod.on_game_state_changed = function()
    refresh_runtime_integrations()
end

mod.update = function()
    gameplay.update()
end

mod.on_unload = function()
    native.shutdown(native_config)
end

mod:echo(string.format(
    "Pusfume prototype v%s loaded. Run /pusfume_preflight in the Keep before selecting the career.",
    MOD_VERSION))
