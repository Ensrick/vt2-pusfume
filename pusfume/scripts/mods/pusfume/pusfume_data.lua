local mod = get_mod("pusfume")

return {
    name = "Pusfume",
    description = mod:localize("mod_description"),
    is_togglable = false,
    custom_gui_textures = {
        textures = {
            "pusfume_model_preview",
        },
        ui_renderer_injections = {
            {
                "ingame_ui",
                "materials/pusfume/pusfume_model_preview",
            },
            {
                "ingame_ui_settings",
                "materials/pusfume/pusfume_model_preview",
            },
        },
    },
}
