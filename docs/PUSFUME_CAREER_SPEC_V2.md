# Pusfume Career Specification v2.0

Source authority: `C:\Users\danjo\Downloads\Pusfume, the Under-Empire Reject.docx`

Source modified: 2026-07-17 15:20:31 America/Chicago

This document records the implementation-facing requirements extracted from the current product specification. The DOCX remains authoritative if this summary conflicts with it.

## Career identity

- Career: Under-Empire Reject.
- Character: Pusfume.
- Role: ranged-focused universal Skaven drawing on Clans Skryre, Moulder, Eshin, and Pestilens.
- Health: 100.
- Activated ability cooldown: 90 seconds.

## Core kit

- Aggressive Iteration: killing a Special captures a minor version of that Special's power for Pusfume's next ranged attack.
- Moulder Ingenuity: ready the Tool Bag and augment the next selected consumable.
- Hell Pit Native: immunity to poison damage.
- Scaredy-rat: no movement-speed penalty on hit; taking melee damage grants 20% movement speed for 3 seconds.
- Swift Claws: 15% faster reload speed.

Aggressive Iteration payloads are specified for Globadier, Warpfire Thrower, Ratling Gunner, Gutter Runner, Packmaster, Lifeleech, Blightstormer, Sack Rat, and Wargor kills. Each payload needs isolated gameplay and network validation before release.

Moulder Ingenuity transformations are specified for healing draughts, medical supplies, potions, bombs, and incendiary bombs. They require inventory-state handling, networking, balance validation, and new first-person animation, mesh, material, shader, and effect assets.

## Talents

- Level 5: the Huntsman level-5 row (Second Wind, Execute, Cleave).
- Level 10: Crafty Claws, Coward at Heart, Elusive Nature.
- Level 15: Smiter, Mainstay, Enhanced Power.
- Level 20: Opportunism, Enhanced Cunning, Run It Through a Filter.
- Level 25: Warpstone Bullets, Open Wounds, Last Ditch Effort.
- Level 30: Expert Craftsmanship, From Scraps, Make It Two-Two!

The custom tree is registered as Pusfume's fifth deterministic Bardin-profile
tree. All 18 slots have localization and placeholder icons. Eight slots use
stock engine-backed buff contracts; ten complex slots are visibly labeled and
registered with empty buff lists until their multiplayer contracts are safe.

## Weapons

Melee candidates: Wrenchy-tool, Packmaster's Whip, Skaven Spear, Dagger, one-handed sword, one-handed spear, and two-handed mace.

Ranged candidates: Man-thing Crossbow, Man-thing Hunting Rifle, Warplock Jezzail, Warpfire Flamethrower, and Ratling Gunner weapon if technically feasible.

The roster requires item definitions, wield permissions, first- and third-person units, animations, action templates, balance profiles, icons, illusions, and multiplayer validation. Existing Skaven weapon models may be reused where licensing and asset provenance allow.

## Current implementation boundary

Implemented from v2.0 in source:

- Explicit 100 HP and 90-second cooldown.
- Updated names and descriptions.
- Aggressive Iteration special-kill capture and ready-state scaffold.
- Moulder Ingenuity armed-consumable state scaffold.
- Hell Pit Native poison immunity.
- Scaredy-rat no-hit-slow perk plus 20%/3-second speed buff.
- Swift Claws 15% faster reload.

Blocked pending focused implementation or live testing:

- Aggressive Iteration ranged-attack payload execution.
- Consumable transformations and all supporting assets.
- Ten guarded custom talent effects and final authored icons.
- Custom weapon roster and assets.
- Voice, interaction, and narrative content.
