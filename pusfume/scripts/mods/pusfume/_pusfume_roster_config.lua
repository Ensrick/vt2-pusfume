-- Dev gate for the cross-character weapon roster (issue #35).
--
-- Pusfume ships a hard rat-weapon allowlist because his runtime first-person
-- hands are the native Skaven Packmaster arms, whose rig lacks the hero weapon
-- first-person state-machine events. Opening every hero's weapon is only safe
-- once Janfon's HUMAN-rigged first-person arms land and the first-person unit
-- becomes a standard hero rig (state machines then install and play natively).
--
-- Until that rig ships, this stays false and the hard allowlist in
-- _pusfume_weapons.lua / _pusfume_registry.lua remains authoritative. Flip it
-- (or bake it from the human-rig build) to open the roster.
return {
    open_all_hero_weapons = false,
}
