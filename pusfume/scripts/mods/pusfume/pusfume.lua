local mod = get_mod("pusfume")

local MOD_VERSION = "0.2.0-dev"

mod:info("[pusfume] loading v%s", MOD_VERSION)

local registry = mod:dofile("scripts/mods/pusfume/_pusfume_registry")
local backend = mod:dofile("scripts/mods/pusfume/_pusfume_backend")
local access = mod:dofile("scripts/mods/pusfume/_pusfume_access")
local ui = mod:dofile("scripts/mods/pusfume/_pusfume_ui")
local career_index = registry.register()

backend.install(registry)
access.install(registry, career_index)
ui.install(registry)

mod:echo(string.format("Pusfume prototype v%s loaded. All lobby members need this mod.", MOD_VERSION))
