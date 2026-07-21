-- Dev gate for the cross-character weapon roster (issue #35).
--
-- Pusfume ships a hard rat-weapon allowlist because his runtime first-person
-- hands are the native Skaven Packmaster arms, whose rig lacks the hero weapon
-- first-person state-machine events. Opening every hero's weapon is only safe
-- once Janfon's HUMAN-rigged first-person arms land and the first-person unit
-- becomes a standard hero rig (state machines then install and play natively).
--
-- This dev build ships it ON to exercise the human hands against every hero
-- weapon. Flip it back to false for any public promotion: the flag is the only
-- switch, and with it off the hard allowlist in _pusfume_weapons.lua /
-- _pusfume_registry.lua is authoritative again.
return {
    open_all_hero_weapons = true,
}
