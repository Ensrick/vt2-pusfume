local mod = get_mod("pusfume")

local portrait_textures = {
    "portrait_pusfume",
    "medium_portrait_pusfume",
    "small_portrait_pusfume",
}
local renderer_creators = {
    "ingame_ui",
    "ingame_ui_settings",
    "hero_view",
    "hero_view_state_loot",
    "hero_view_state_store",
    "hero_view_state_weave_forge",
    "start_game_state_settings_overview",
    "store_item_purchase_popup",
    "store_welcome_popup",
    "level_end_view_base",
    "level_end_view_versus",
    "game_mode_map_deus",
    "ui_manager",
}
local material_paths = {
    "materials/ui/portrait_pusfume",
    "materials/ui/medium_portrait_pusfume",
    "materials/ui/small_portrait_pusfume",
}
local injections = {}

for _, creator in ipairs(renderer_creators) do
    injections[#injections + 1] = {
        creator,
        unpack(material_paths),
    }
end

-- The source-only large preview uses its original renderer registrations.
injections[#injections + 1] = {
    "ingame_ui",
    "materials/pusfume/pusfume_model_preview",
}
injections[#injections + 1] = {
    "ingame_ui_settings",
    "materials/pusfume/pusfume_model_preview",
}

return {
    name = "Pusfume",
    description = mod:localize("mod_description"),
    is_togglable = false,
    custom_gui_textures = {
        textures = {
            "pusfume_model_preview",
            unpack(portrait_textures),
        },
        ui_renderer_injections = injections,
    },
}
