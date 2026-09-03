-- Dev gate for the cross-character weapon roster (issue #35).
--
-- The native Versus and human hero controllers are incompatible, so the live
-- build switches complete first-person rigs by weapon family. Rat prototypes
-- use their role-specific Skaven arms; hero weapons use Janfon's human rig.
--
-- This dev build ships it ON to exercise the human hands against every hero
-- weapon. Flip it back to false for any public promotion: the flag is the only
-- switch, and with it off the hard allowlist in _pusfume_weapons.lua /
-- _pusfume_registry.lua is authoritative again.
return {
    open_all_hero_weapons = true,
}
