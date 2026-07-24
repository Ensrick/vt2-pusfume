from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
WEAPONS = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_weapons.lua").read_text()
BACKEND = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_backend.lua").read_text()
REGISTRY = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_registry.lua").read_text()
UI = (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_ui.lua").read_text()


class WeaponContractTests(unittest.TestCase):
    def test_prototype_items_use_shipped_rat_units_with_safe_hero_actions(self):
        self.assertIn('slot_melee = "vs_packmaster_claw"', WEAPONS)
        self.assertIn('slot_ranged = "vs_warpfire_thrower_gun"', WEAPONS)
        self.assertIn('source_item = "vs_ratling_gunner_gun"', WEAPONS)
        self.assertIn('source_item = "vs_poison_wind_globadier_orb"', WEAPONS)
        self.assertIn('source_item = "vs_gutter_runner_claws"', WEAPONS)
        self.assertIn('source_item = "dr_crossbow"', WEAPONS)
        self.assertIn("ItemMasterList", WEAPONS)
        self.assertIn("two_handed_axes_template_1", WEAPONS)
        self.assertIn("Weapons.vs_warpfire_thrower_gun", WEAPONS)
        self.assertNotIn('template = "vs_packmaster_claw"', WEAPONS)
        self.assertNotIn('template = "vs_warpfire_thrower_gun"', WEAPONS)

    def test_custom_items_are_complete_clones_of_the_native_versus_records(self):
        self.assertIn('resolve_versus_item("slot_melee")', WEAPONS)
        self.assertIn('resolve_versus_item("slot_ranged")', WEAPONS)
        self.assertIn("local melee = deep_clone(melee_source_items[variant_name])", WEAPONS)
        self.assertIn("local ranged = deep_clone(ranged_source_items[variant_name])", WEAPONS)
        self.assertIn("melee.source_item = definition.source_item", WEAPONS)
        self.assertIn("ranged.source_item = definition.source_item", WEAPONS)
        self.assertIn("melee.mechanisms = nil", WEAPONS)
        self.assertIn("ranged.mechanisms = nil", WEAPONS)

    def test_hero_actions_always_have_a_matching_wielded_hand_unit(self):
        self.assertIn("action_hand_contract_ready", WEAPONS)
        self.assertIn('local hand = action.weapon_action_hand or "right"', WEAPONS)
        self.assertIn("item_data.right_hand_unit", WEAPONS)
        self.assertIn("item_data.left_hand_unit", WEAPONS)
        self.assertIn("hand_contract_ready = hand_contract_ready and", WEAPONS)

    def test_warpfire_uses_native_versus_actions_with_adventure_inputs(self):
        self.assertIn("adapt_warpfire_template", WEAPONS)
        self.assertIn("template.actions.dark_pact_action_one", WEAPONS)
        self.assertIn("hero_warpfire_condition", WEAPONS)
        self.assertIn("template.actions.action_one = action_one", WEAPONS)
        self.assertIn("template.actions.weapon_reload = action_reload", WEAPONS)
        self.assertIn(
            "template.actions.dark_pact_action_one = deep_clone(action_one)",
            WEAPONS,
        )
        self.assertIn(
            "template.actions.dark_pact_reload = deep_clone(action_reload)",
            WEAPONS,
        )
        self.assertIn('bind_action_lookup_data(action_one, "action_one")', WEAPONS)
        self.assertNotIn("template.actions.dark_pact_action_one = nil", WEAPONS)
        self.assertIn('"action_one_hold"', WEAPONS)
        self.assertIn('"weapon_reload_hold"', WEAPONS)
        self.assertIn("template.synced_states.priming.enter = nil", WEAPONS)
        self.assertNotIn("template.synced_states = nil", WEAPONS)

    def test_warpfire_has_a_pusfume_only_adventure_enemy_target_adapter(self):
        self.assertIn("pusfume_warpfire_targets", WEAPONS)
        self.assertIn("side:enemy_units()", WEAPONS)
        self.assertIn("DamageUtils.is_enemy(player_unit, target_unit)", WEAPONS)
        self.assertIn("PerceptionUtils.is_position_in_line_of_sight", WEAPONS)
        self.assertIn('career_extension:career_name() == installed_registry.CAREER_NAME', WEAPONS)
        self.assertIn('mod:hook(ActionWarpfireThrower, "fire"', WEAPONS)
        self.assertIn("DamageUtils.add_damage_network(target.unit, owner_unit, 2", WEAPONS)
        self.assertIn('"warpfire_ground"', WEAPONS)
        self.assertIn("M.ITEM_KEYS.slot_ranged", WEAPONS)

    def test_packmaster_hook_keeps_safe_sweeps_and_animates_the_native_claw(self):
        self.assertIn("add_packmaster_weapon_events", WEAPONS)
        self.assertIn('action.kind == "sweep"', WEAPONS)
        self.assertIn('weapon_anim_event(owner_unit, "attack_grab")', WEAPONS)
        self.assertIn('action.anim_event_1p = "attack_grab"', WEAPONS)
        self.assertIn('template.wield_anim = "idle"', WEAPONS)
        self.assertIn('template.pusfume_role_pose = "to_packmaster"', WEAPONS)
        self.assertNotIn('"to_packmaster_claw"', WEAPONS)

    def test_packmaster_hook_has_an_adventure_damage_strike(self):
        self.assertIn("packmaster_hook_target", WEAPONS)
        self.assertIn("side:enemy_units()", WEAPONS)
        self.assertIn("distance <= 4.5", WEAPONS)
        self.assertIn("strike_with_packmaster_hook(owner_unit)", WEAPONS)
        self.assertIn("DamageUtils.add_damage_network(target_unit, owner_unit, 15", WEAPONS)
        self.assertIn('M.ITEM_KEYS.slot_melee', WEAPONS)
        self.assertIn('"light_slashing_smiter"', WEAPONS)
        self.assertNotIn('"light_slashing_smiter_pull"', WEAPONS)
        self.assertNotIn('"medium_slashing_smiter_2h", nil, attack_direction', WEAPONS)

    def test_ratling_and_globadier_have_adventure_adapters(self):
        self.assertIn("adapt_ratling_template", WEAPONS)
        self.assertIn('"filter_player_ray_projectile"', WEAPONS)
        self.assertIn("template.synced_states or {}", WEAPONS)
        self.assertIn('template.pusfume_role_pose = "to_ratling_gunner"', WEAPONS)
        self.assertIn("create_globadier_template", WEAPONS)
        self.assertIn("spawn_globadier_globe", WEAPONS)
        self.assertIn('template.pusfume_role_pose = "to_globadier"', WEAPONS)
        self.assertIn("template.ammo_data.infinite_ammo = false", WEAPONS)
        self.assertIn("install_ratling_audio_adapter", WEAPONS)
        self.assertIn('mod:hook(ActionMinigun, "_play_vo"', WEAPONS)

    def test_ratling_has_clip_and_reserve_ammo_economy(self):
        # 120-round clip + 120-round reserve = 240 total (issue 40). The pool
        # must be reserve-based (ammo_immediately_available false) so reload
        # pulls from the reserve and ammo boxes refill the reserve.
        self.assertIn("local RATLING_CLIP_AMMO = 120", WEAPONS)
        self.assertIn("local RATLING_RESERVE_AMMO = 120", WEAPONS)
        self.assertIn(
            "template.ammo_data.ammo_immediately_available = false", WEAPONS
        )
        self.assertIn(
            "template.ammo_data.ammo_per_clip = RATLING_CLIP_AMMO", WEAPONS
        )
        self.assertIn(
            "template.ammo_data.max_ammo = RATLING_CLIP_AMMO + RATLING_RESERVE_AMMO",
            WEAPONS,
        )
        self.assertIn(
            "template.ammo_data.starting_reserve_ammo = RATLING_RESERVE_AMMO",
            WEAPONS,
        )
        # Reload moves reserve into the clip instead of the Versus infinite
        # hopper refill (add_ammo with no amount, which would top the reserve).
        self.assertIn("ratling_reload_finish", WEAPONS)
        self.assertIn("ammo_extension:instant_reload(false)", WEAPONS)
        self.assertIn(
            "action_reload.default.finish_function = ratling_reload_finish", WEAPONS
        )

    def test_ratling_restores_sanitized_wwise_fire_audio(self):
        # The Versus synced-state callbacks are wiped (they crash on VCE and the
        # Pactsworn "fire" ability), then the fire audio is restored (issue 41).
        self.assertIn(
            "template.synced_states.firing.enter = ratling_firing_enter", WEAPONS
        )
        self.assertIn(
            "template.synced_states.firing.update = ratling_firing_update", WEAPONS
        )
        self.assertIn(
            "template.synced_states.winding.enter = ratling_winding_enter", WEAPONS
        )
        self.assertIn('"Play_player_ratling_gunner_shooting_loop"', WEAPONS)
        self.assertIn('"Stop_player_ratling_gunner_shooting_loop"', WEAPONS)
        self.assertIn('"Play_player_ratling_gunner_weapon_ready"', WEAPONS)
        self.assertIn('"ratling_gun_shooting_loop_parameter"', WEAPONS)

    def test_warpfire_substitutes_resident_drakegun_flame_loop(self):
        # The Versus warpfire soundbank is not resident in Adventure, so the
        # resident hero drakegun flamethrower loop is played over the fire action
        # and its wwise bank is declared as a dependency (issue 41).
        self.assertIn(
            'local DRAKEGUN_FLAME_LOOP_START = "Play_player_combat_weapon_drakegun_flamethrower_shoot"',
            WEAPONS,
        )
        self.assertIn(
            'local DRAKEGUN_FLAME_LOOP_STOP = "Stop_player_combat_weapon_drakegun_flamethrower_shoot"',
            WEAPONS,
        )
        self.assertIn('local DRAKEGUN_FLAME_WWISE_PACKAGE = "wwise/flamethrower"', WEAPONS)
        self.assertIn("ensure_flamethrower_wwise_dep(template)", WEAPONS)
        self.assertIn(
            'mod:hook(ActionWarpfireThrower, "client_owner_start_action"', WEAPONS
        )
        self.assertIn('mod:hook(ActionWarpfireThrower, "finish"', WEAPONS)

    def test_assassin_claws_use_complete_native_units_and_safe_actions(self):
        self.assertIn("M.MELEE_VARIANTS", WEAPONS)
        self.assertIn('source_item = "vs_gutter_runner_claws"', WEAPONS)
        self.assertIn("Weapons.vs_gutter_runner_claws", WEAPONS)
        self.assertIn("Weapons.dual_wield_daggers_template_1", WEAPONS)
        self.assertIn("prepare_assassin_claw_actions", WEAPONS)
        self.assertIn('heavy_attack_stab = "claws_light_attack_stab_left_hit"', WEAPONS)
        self.assertIn('light_attack_left = "claws_light_attack_right_first"', WEAPONS)
        self.assertIn('light_attack_right = "claws_light_attack_right_second"', WEAPONS)
        self.assertIn('light_attack_quick_left = "claws_light_attack_stab_left"', WEAPONS)
        self.assertIn('light_attack_last = "claws_light_attack_last"', WEAPONS)
        self.assertIn('push_stab = "claws_light_attack_stab_left_hit"', WEAPONS)
        self.assertIn("action.anim_end_event = nil", WEAPONS)
        self.assertIn('template.wield_anim = "claws_equip"', WEAPONS)
        self.assertIn('template.pusfume_role_pose = "to_gutter_runner"', WEAPONS)

    def test_every_weapon_chain_target_is_validated_before_registration(self):
        self.assertIn("local function validate_action_graph(actions)", WEAPONS)
        self.assertIn("local target = actions[target_name]", WEAPONS)
        self.assertIn("state.action_graph_ready = melee_graph_ready and ranged_graph_ready", WEAPONS)
        self.assertIn("if not state.action_graph_ready then", WEAPONS)

    def test_warpfire_guards_pactsworn_only_status_api_in_adventure(self):
        self.assertIn(
            'type(status_extension.is_climbing) == "function"',
            WEAPONS,
        )
        self.assertIn("hero_warpfire_reload_condition", WEAPONS)
        self.assertEqual(
            WEAPONS.count(
                'type(overcharge_extension.get_overcharge_value) == "function"'
            ),
            2,
        )

    def test_packmaster_adapter_removes_hero_only_hit_animation_events(self):
        self.assertIn("sanitize_packmaster_melee_actions", WEAPONS)
        self.assertIn("PACKMASTER_UNSAFE_HIT_ANIMATION_FIELDS", WEAPONS)
        for field_name in (
            "dual_hit_stop_anims",
            "first_person_hit_anim",
            "hit_armor_anim",
            "hit_shield_stop_anim",
            "hit_stop_anim",
            "hit_stop_kill_anim",
        ):
            self.assertIn(f'"{field_name}"', WEAPONS)
        self.assertIn("action[field_name] = nil", WEAPONS)

    def test_weapon_items_are_pusfume_only_and_ranger_weapons_are_not_inherited(self):
        self.assertEqual(WEAPONS.count("can_wield = { registry.CAREER_NAME }"), 2)
        self.assertIn(
            'local is_weapon = item.slot_type == "melee" or item.slot_type == "ranged"',
            REGISTRY,
        )
        self.assertIn("if not is_weapon and type(can_wield)", REGISTRY)
        self.assertIn('string.find(item_filter, "slot_type == melee"', BACKEND)
        self.assertIn('string.find(item_filter, "slot_type == ranged"', BACKEND)
        self.assertIn(
            '"can_wield_by_current_hero", "can_wield_by_current_career"',
            BACKEND,
        )
        self.assertIn("weapons.allowed_item_keys(slot_name)", BACKEND)
        self.assertIn('"item_key == " .. item_key', BACKEND)
        self.assertIn("weapons.select_backend_id(slot_name, backend_id)", BACKEND)
        self.assertIn("weapons.select_item_key(slot_name, item_key)", BACKEND)
        runtime_install = BACKEND[BACKEND.index("function M.install_runtime_guards") :]
        install_call = runtime_install.index("install_weapon_grid_guard(registry, weapons)")
        early_return = runtime_install.index("if status.runtime_guards_installed then")
        self.assertLess(install_call, early_return)

    def test_weapon_roster_contains_two_melee_and_four_ranged_variants(self):
        for key in (
            "pusfume_packmaster_hook",
            "pusfume_warpfire_thrower",
            "pusfume_ratling_gun",
            "pusfume_poison_wind_globe",
            "pusfume_assassin_claws",
            "pusfume_crossbow",
        ):
            self.assertIn(key, WEAPONS)
        self.assertIn("M.MELEE_VARIANT_ORDER", WEAPONS)
        self.assertIn("function M.allowed_backend_ids(slot_name)", WEAPONS)
        self.assertIn("function M.allowed_item_keys(slot_name)", WEAPONS)
        self.assertIn("function M.select_backend_id(slot_name, backend_id)", WEAPONS)

    def test_crossbow_stand_in_isolated_from_bardin_animation_controller(self):
        self.assertIn('template_name = "pusfume_crossbow_template"', WEAPONS)
        self.assertIn("local crossbow_source = Weapons and Weapons.crossbow_template_1", WEAPONS)
        self.assertIn("sanitize_placeholder_animation_events", WEAPONS)
        self.assertIn("installed_crossbow.state_machine = nil", WEAPONS)
        self.assertIn("installed_crossbow.load_state_machine = false", WEAPONS)
        self.assertIn('installed_crossbow.wield_anim = "idle"', WEAPONS)
        self.assertIn('installed_crossbow.reload_event = "idle"', WEAPONS)

    def test_custom_items_have_network_and_backend_registration(self):
        self.assertIn("append_lookup(NetworkLookup.item_names, item_key)", WEAPONS)
        self.assertIn("append_lookup(NetworkLookup.damage_sources, item_key)", WEAPONS)
        self.assertIn("weapons.inject_backend_items", BACKEND)
        self.assertIn("weapons.backend_id_for_slot(slot_name)", BACKEND)
        self.assertIn("weapons.overlay_loadout_collection", BACKEND)

    def test_old_weapon_visibility_diagnostics_are_disabled(self):
        self.assertNotIn("Unit.set_unit_visibility(weapon_unit, false)", UI)
        self.assertIn(
            "extension:unhide_weapons(FIRST_PERSON_WEAPON_HIDE_REASON)",
            (ROOT / "pusfume/scripts/mods/pusfume/_pusfume_native.lua").read_text(),
        )


if __name__ == "__main__":
    unittest.main()
