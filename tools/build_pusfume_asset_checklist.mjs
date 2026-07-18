import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const toolsRoot = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(toolsRoot, "..");
const vt2Root = process.env.VT2_SOURCE_ROOT
  ? path.resolve(process.env.VT2_SOURCE_ROOT)
  : path.resolve(repoRoot, "..", "Vermintide-2-Source-Code");
const outputDir = path.join(repoRoot, "outputs/pusfume-career-assets");
const qaDir = path.join(outputDir, "qa");
const outputPath = path.join(outputDir, "Pusfume_Career_Asset_Checklist.xlsx");

const COLORS = {
  ink: "#17212B",
  navy: "#213547",
  teal: "#167D7F",
  tealLight: "#DCEEEE",
  parchment: "#F4F0E6",
  gold: "#C99738",
  white: "#FFFFFF",
  gray: "#6B7280",
  line: "#D7DCE0",
  green: "#DCEFE2",
  amber: "#FFF0C7",
  red: "#F8D7DA",
  blue: "#DDEAF7",
};

const COLUMNS = [
  "ID",
  "Workstream",
  "Asset / Motion",
  "Perspective",
  "Variant / Direction",
  "Requirement",
  "Priority",
  "Status",
  "Owner",
  "Deliverable / Format",
  "Acceptance Criteria",
  "VT2 Source Reference",
  "Notes",
];

const SOURCES = {
  states: "SRC-001: scripts/unit_extensions/default_player_unit/states/",
  firstPerson: "SRC-002: scripts/unit_extensions/default_player_unit/player_unit_first_person.lua",
  helper: "SRC-003: scripts/unit_extensions/default_player_unit/states/player_character_state_helper.lua",
  careers: "SRC-004: scripts/settings/profiles/career_settings.lua",
  versusCareers: "SRC-005: scripts/settings/profiles/career_settings_vs.lua",
  profiles: "SRC-006: scripts/settings/profiles/sp_profiles.lua",
  versusProfiles: "SRC-007: scripts/settings/profiles/vs_profiles.lua",
  cosmetics: "SRC-008: scripts/settings/equipment/cosmetics.lua",
  weapons: "SRC-009: scripts/settings/equipment/weapon_templates/",
  hud: "SRC-010: scripts/ui/hud_ui/",
  hero: "SRC-011: scripts/ui/views/hero_view/",
  talents: "SRC-012: scripts/managers/talents/ and scripts/ui/views/hero_view/windows/hero_window_talents.lua",
  dialogue: "SRC-013: scripts/settings/dialogue_settings.lua",
  interactions: "SRC-014: scripts/unit_extensions/generic/interactions.lua",
  locomotion: "SRC-015: scripts/helpers/locomotion_utils.lua",
  ragdoll: "SRC-016: scripts/settings/profiles/base_units.lua",
  ability: "SRC-017: scripts/ui/hud_ui/ability_ui.lua and career_ability_bar_ui.lua",
  inventory: "SRC-018: scripts/settings/inventory_settings.lua and scripts/ui/views/player_inventory_ui.lua",
  versusHud: "SRC-019: scripts/ui/hud_ui/component_list_definitions/hud_component_list_versus.lua",
  pipeline: "SRC-020: vt2-pusfume-1p/docs/ASSET_PIPELINE.md",
  handoff: "SRC-021: vt2-pusfume-1p/docs/MODEL_HANDOFF.md",
  spec: "SRC-022: vt2-pusfume-1p/docs/PUSFUME_CAREER_SPEC_V2.md",
  kit: "SRC-023: vt2-pusfume-1p/docs/CAREER_KIT.md",
  portrait: "SRC-024: vt2-pusfume-1p/tools/Build-PusfumePortrait.ps1",
  blender: "SRC-025: vt2-pusfume-1p/tools/prepare_animated_pusfume_fbx.py",
  firstPersonBuild: "SRC-026: vt2-pusfume-1p/tools/prepare_pusfume_1p_blend.py",
  build: "SRC-027: vt2-pusfume-1p/tools/Build-NativePusfume.ps1",
  atlas: "SRC-028: vt2-pusfume-1p/tools/pusfume_atlas_layout.json",
  milestone: "SRC-029: vt2-pusfume-1p/docs/NATIVE_CHARACTER_MILESTONE.md",
};

const rows = (prefix) => {
  let n = 0;
  return (workstream, asset, perspective, variant, requirement, priority, owner, deliverable, acceptance, source, notes = "", status = "Not Started") => [
    `${prefix}-${String(++n).padStart(3, "0")}`,
    workstream,
    asset,
    perspective,
    variant,
    requirement,
    priority,
    status,
    owner,
    deliverable,
    acceptance,
    source,
    notes,
  ];
};

function buildAnimationRows() {
  const add = rows("ANIM");
  const out = [];
  const push = (...args) => out.push(add(...args));
  const views = ["Third person", "First person"];
  const eightDirections = ["Forward", "Forward-left", "Left", "Back-left", "Backward", "Back-right", "Right", "Forward-right"];

  for (const view of views) {
    push("Core locomotion", "Neutral idle loop", view, "Standing", "Required", "P0", "Janfon", "Looping FBX clip", "Loops without a visible pop; root stays planted; hands and tail remain stable.", `${SOURCES.states}; ${SOURCES.firstPerson}`, "Provide at least two subtle variants to reduce repetition.");
    push("Core locomotion", "Alert/combat idle loop", view, "Weapon-ready", "Required", "P0", "Janfon", "Looping FBX clip", "Matches ready stance and blends cleanly into attacks, block, walk, and dodge.", `${SOURCES.states}; ${SOURCES.weapons}`);
    push("Core locomotion", "Idle variation", view, "Look / sniff / fidget", "Optional", "P2", "Janfon", "3 additive or full-body clips", "No locomotion root motion; safe to interrupt at authored exit markers.", `${SOURCES.careers}; ${SOURCES.hero}`);
    for (const speed of ["Walk", "Run", "Crouch walk"]) {
      for (const direction of eightDirections) {
        push("Core locomotion", `${speed} cycle`, view, direction, speed === "Crouch walk" ? "Conditional" : "Required", speed === "Run" ? "P0" : "P1", "Janfon", "Looping FBX clip", `Direction reads clearly at gameplay distance; foot contacts do not slide; cycle blends with adjacent ${speed.toLowerCase()} directions.`, `${SOURCES.states}; ${SOURCES.locomotion}`);
      }
    }
    for (const variant of ["Idle to walk", "Idle to run", "Walk/run to idle", "180-degree turn left", "180-degree turn right", "Turn in place left", "Turn in place right"]) {
      push("Core locomotion", "Locomotion transition", view, variant, "Required", "P1", "Janfon", "One-shot FBX clip", "No teleport or scale key; feet settle at the donor transition timing.", `${SOURCES.states}; ${SOURCES.locomotion}`);
    }
    for (const direction of eightDirections) {
      push("Evasion", "Dodge", view, direction, "Required", "P0", "Janfon", "One-shot FBX clip", "Silhouette communicates dodge direction; blends back to idle/run without arm snapping.", `${SOURCES.states}player_character_state_dodging.lua`);
    }
    for (const phase of ["Jump anticipation", "Jump takeoff", "Airborne rise", "Airborne apex", "Falling loop", "Short landing", "Long landing", "Hard landing / stagger"]) {
      push("Air movement", phase, view, "Forward/default", "Required", phase.includes("Hard") ? "P1" : "P0", "Janfon", "One-shot or loop FBX clip", "Matches vertical state transition; root motion is engine-driven; no pose pop at takeoff/apex/landing.", `${SOURCES.states}player_character_state_jumping.lua; ${SOURCES.states}player_character_state_falling.lua`);
    }
  }

  for (const variant of ["Enter bottom", "Enter top", "Climb up loop", "Climb down loop", "Ladder idle", "Exit bottom", "Exit top left", "Exit top right"]) {
    push("Traversal", "Ladder movement", "Third person", variant, "Required", "P1", "Janfon", "FBX clip", "Hands and feet meet ladder spacing; root alignment matches engine-controlled ladder state.", `${SOURCES.states}player_character_state_climbing_ladder.lua; ${SOURCES.states}player_character_state_enter_ladder_top.lua; ${SOURCES.states}player_character_state_leaving_ladder_top.lua`);
  }
  for (const variant of ["Grab", "Hang idle", "Shimmy left", "Shimmy right", "Pull up", "Drop to fall", "Forced release"]) {
    push("Traversal", "Ledge movement", "Third person", variant, "Required", "P1", "Janfon", "FBX clip", "Hands align to ledge plane and transition without shoulder inversion.", `${SOURCES.states}player_character_state_ledge_hanging.lua; ${SOURCES.states}player_character_state_leave_ledge_hanging_pull_up.lua`);
  }
  for (const variant of ["Catapulted", "Using transport", "Hanging cage idle", "Hanging cage release"]) {
    push("Traversal", "Special traversal", "Third person", variant, "Conditional", "P2", "Janfon", "FBX clip", "Preserves attachment alignment and enters/exits falling or standing correctly.", `${SOURCES.states}player_character_state_catapulted.lua; ${SOURCES.states}player_character_state_using_transport.lua; ${SOURCES.states}player_character_state_in_hanging_cage.lua`);
  }

  const meleeFamilies = ["One-handed melee", "Two-handed melee", "Dual wield", "Shielded melee"];
  const meleeActions = [
    ["Equip / draw", "Default"], ["Unequip / stow", "Default"], ["Weapon idle", "Default"],
    ["Light attack", "Left-to-right"], ["Light attack", "Right-to-left"], ["Light attack", "Overhead"], ["Light attack", "Stab"],
    ["Heavy charge pose", "Left"], ["Heavy charge pose", "Right"], ["Heavy attack", "Diagonal"], ["Heavy attack", "Overhead"], ["Heavy attack", "Stab"],
    ["Block enter", "Default"], ["Block idle", "Default"], ["Block hit reaction", "Light"], ["Block hit reaction", "Heavy"],
    ["Push", "Default"], ["Push-follow-up", "Default"], ["Parry", "Default"], ["Attack cancel / recover", "Default"],
  ];
  for (const family of meleeFamilies) {
    for (const [asset, variant] of meleeActions) {
      for (const view of views) {
        push("Weapon combat", `${family}: ${asset}`, view, variant, family === "Shielded melee" ? "Conditional" : "Required", asset.includes("idle") || asset.includes("Light") || asset.includes("Heavy attack") ? "P0" : "P1", "Janfon", "FBX clip on canonical Pusfume rig", "Animation event resolves, weapon grip remains aligned, and blend/recovery timing matches the selected weapon template.", SOURCES.weapons, "Author against the final supported weapon roster; reuse only after in-game grip and silhouette validation.");
      }
    }
  }

  const rangedActions = ["Equip / draw", "Weapon idle", "Aim enter", "Aim idle", "Aim exit", "Fire / release", "Recoil", "Reload start", "Reload loop", "Reload finish", "Dry fire", "Cancel / lower", "Throw charge", "Throw release"];
  for (const family of ["Bow/crossbow", "Firearm", "Thrown weapon"]) {
    for (const action of rangedActions) {
      const conditional = family === "Thrown weapon" && !action.startsWith("Throw") && !["Equip / draw", "Weapon idle", "Aim enter", "Aim idle", "Aim exit", "Cancel / lower"].includes(action);
      if (conditional) continue;
      for (const view of views) {
        push("Weapon combat", `${family}: ${action}`, view, "Default", "Conditional", action.includes("idle") || action === "Fire / release" || action === "Throw release" ? "P1" : "P2", "Janfon", "FBX clip on canonical Pusfume rig", "Sight/hand alignment remains usable in first person; third-person recoil and reload communicate state to teammates.", SOURCES.weapons);
      }
    }
  }

  const reactions = [
    ["Light stagger", ["Front", "Back", "Left", "Right"]],
    ["Heavy stagger", ["Front", "Back", "Left", "Right"]],
    ["Stunned loop", ["Default"]],
    ["Knockdown enter", ["Front", "Back"]],
    ["Knocked-down idle", ["Default"]],
    ["Downed crawl", ["Forward", "Backward"]],
    ["Revive receive", ["Default"]],
    ["Revive teammate", ["Default"]],
    ["Death", ["Front", "Back", "Left", "Right"]],
    ["Assisted respawn idle", ["Default"]],
  ];
  for (const [asset, variants] of reactions) {
    for (const variant of variants) {
      push("Damage and recovery", asset, "Third person", variant, "Required", asset === "Death" ? "P1" : "P0", "Janfon", "FBX clip", "Readable hit direction and clean transition into standing, downed, dead, or respawn state.", `${SOURCES.states}player_character_state_stunned.lua; ${SOURCES.states}player_character_state_knocked_down.lua; ${SOURCES.states}player_character_state_dead.lua`);
    }
  }

  const disables = ["Grabbed by Packmaster", "Pounced by Gutter Runner", "Grabbed by Chaos Spawn", "Grabbed by Corruptor", "Grabbed by tentacle", "In vortex", "Overpowered"];
  for (const asset of disables) {
    push("Disabled states", asset, "Third person", "Enter / loop / exit", "Required", "P1", "Janfon", "3 FBX clips or compatible state sequence", "Attachment points stay valid during enemy carry/hold; exit blends to fall, downed, or standing.", SOURCES.states);
  }

  for (const action of ["Interact start", "Interact loop", "Interact complete", "Interact cancel", "Inspect weapon", "Carry objective idle", "Carry objective walk", "Pickup", "Drop", "Use potion", "Use healing item", "Revive self", "Emote neutral", "Emote celebration"]) {
    push("Interaction and social", action, "Third person", "Default", action.startsWith("Carry") ? "Conditional" : "Required", "P2", "Janfon", "FBX clip", "Hands meet interaction target or carried item; event can be interrupted without a persistent bad pose.", `${SOURCES.states}player_character_state_interacting.lua; ${SOURCES.states}player_character_state_inspecting.lua; ${SOURCES.states}player_character_state_emote.lua`);
  }

  const skillActions = [
    ["Bag ready", "Equip / present"], ["Bag deploy", "Place on ground"], ["Bag deploy recovery", "Return to weapon-ready"],
    ["Bag use by Pusfume", "Interact"], ["Bag use by ally", "Interact"], ["Potion enchant", "Drinkable inventory"],
    ["Bomb upgrade", "Standard to gas bomb"], ["Gas-trap craft", "Trap inventory"], ["Gas-trap place", "Ground placement"],
    ["Craft success", "Celebrate / acknowledge"], ["Craft failure", "No valid item"], ["Bag pickup", "Recover station"], ["Bag interrupted", "Damage/cancel"],
  ];
  for (const [asset, variant] of skillActions) {
    for (const view of views) {
      push("Career skill", `Skaven Ingenuity: ${asset}`, view, variant, "Required", "P0", "Janfon", "FBX clip", "Gameplay notify timing is marked; hands contact bag/item; no weapon or bag clipping at the event frame.", `${SOURCES.spec}; ${SOURCES.kit}; ${SOURCES.ability}`);
    }
  }
  for (const asset of ["Career-select idle", "Hero-view idle", "Inventory inspection idle", "Victory pose", "Defeat pose", "Level-up / unlock pose"]) {
    push("Presentation", asset, "Third person", "Menu", "Required", asset.includes("idle") ? "P0" : "P2", "Janfon", "Loop or one-shot FBX clip", "Framing fits VT2 hero-view camera; face, whiskers, fur, and tail remain stable; no gameplay root motion.", `${SOURCES.careers}; ${SOURCES.hero}`);
  }
  return out;
}

function buildModelRows() {
  const add = rows("MODEL");
  const out = [];
  const push = (...args) => out.push(add(...args));
  const assets = [
    ["Character mesh", "Pusfume third-person body", "Third person", "Base body + outfit", "Required", "P0", "Janfon", "pusfume_3p.fbx + .blend", "Single authoritative skinned mesh set; no unweighted vertices; silhouette reads at gameplay distance.", "Prototype currently exists; final armature overhaul remains."],
    ["Character mesh", "Pusfume first-person arms and hands", "First person", "Left and right", "Required", "P0", "Janfon", "pusfume_1p_arms.fbx + .blend", "Correct donor rest pose, scale and camera framing; no stretched fingers/forearms; weapon grips align.", "Prototype exists but live deformation still needs correction."],
    ["Character mesh", "Head and face", "Third person", "Expression-ready", "Required", "P0", "Janfon", "Skinned mesh", "Jaw, eyelids, ears, whisker roots, and snout deform without gaps.", "Keep topology suitable for future facial animation."],
    ["Character mesh", "Eyes", "Both", "Left/right emissive", "Required", "P1", "Janfon", "Separate mesh/material slots", "No z-fighting; emissive remains controlled; eye direction is consistent.", ""],
    ["Character mesh", "Teeth and tongue", "Third person", "Upper/lower mouth", "Required", "P2", "Janfon", "Separate or joined skinned meshes", "No mouth gaps during jaw motion; normals face outward.", ""],
    ["Character mesh", "Claws and nails", "Both", "Hands/feet", "Required", "P1", "Janfon", "Skinned geometry", "First-person silhouette is clean and weapon grips remain unobstructed.", ""],
    ["Character mesh", "Tail", "Third person", "Primary tail chain", "Required", "P0", "Janfon", "Skinned mesh + tail bones", "No hard kinks; follows locomotion and reacts without penetrating torso.", ""],
    ["Character mesh", "Whisker cards", "Third person", "Left/right", "Required", "P1", "Janfon", "Alpha-card mesh", "Cards are rooted to face, animate with head, and do not look like reflective tape.", "Requires cutout material and suitable card normals."],
    ["Character mesh", "Fur cards/shell", "Third person", "Head/neck/body", "Required", "P1", "Janfon", "Alpha-card mesh or approved fur geometry", "Fur follows body and physics bones; no floating cards, overbright alpha, or costume clipping.", ""],
    ["Career prop", "Skaven Ingenuity bag", "Both", "Held, deployed, world", "Required", "P0", "Janfon", "3p/1p/world FBX units", "One design supports hand carry, ground station, and interaction camera distances.", ""],
    ["Career prop", "Gas bomb", "Both", "Inventory and world", "Required", "P1", "Janfon", "3p/1p/world FBX units", "Readable as upgraded bomb; pivot and throw origin match VT2 throwable conventions.", ""],
    ["Career prop", "Gas trap", "Both", "Inventory, placement ghost, armed", "Required", "P1", "Janfon", "3p/1p/world FBX units", "Ground contact and activation center are unambiguous; no terrain hover.", ""],
    ["Career prop", "Potion enchant attachment", "First person", "Potion interaction", "Required", "P2", "Janfon", "Optional hand-held tool/FX anchor", "Fits hand pose and leaves a named VFX node.", ""],
    ["Cosmetics", "Base hat/headgear", "Third person", "Default", "Required", "P1", "Janfon", "Separate FBX attachment", "Uses stable head attachment; does not clip ears, whiskers, or fur at idle and run extremes.", ""],
    ["Cosmetics", "Head/ear/fur hide masks", "Third person", "Per cosmetic", "Required", "P1", "Janfon", "Named mesh sections or mask metadata", "Each cosmetic can hide only intersecting geometry without deleting face or whisker roots.", ""],
    ["Network model", "Third-person husk compatibility", "Third person", "Remote player", "Required", "P0", "Engineering", "Same skeleton/attachment contract", "Remote clients see the same body, materials, animation, equipment, and career prop states.", ""],
    ["Network model", "Bot model compatibility", "Third person", "Bot", "Required", "P1", "Engineering", "Bot-compatible unit configuration", "Bot spawns, equips items, navigates, revives, and ragdolls without missing unit resources.", ""],
  ];
  for (const [workstream, asset, perspective, variant, requirement, priority, owner, deliverable, acceptance, notes] of assets) {
    push(workstream, asset, perspective, variant, requirement, priority, owner, deliverable, acceptance, `${SOURCES.handoff}; ${SOURCES.cosmetics}`, notes, asset.includes("third-person body") ? "Prototype Ready" : asset.includes("first-person") ? "In Progress" : "Not Started");
  }
  const rigItems = [
    ["Canonical full-body armature", "Untouched Skaven-compatible hierarchy", "82+ deform/physics bones; exact names, hierarchy, rest matrices, and transforms documented."],
    ["Canonical first-person armature", "VT2 first-person donor-compatible", "Shared donor nodes reproduce compiled rest matrices within 0.0001; no object-scale compensation that deforms skin."],
    ["Root / trajectory bone", "Origin and facing", "Root stays at world origin, unit scale, and engine-forward orientation; locomotion clips do not bake unintended translation."],
    ["Pelvis/spine/neck/head chains", "Deformation", "Natural arc with no volume collapse during crouch, aim, and stagger extremes."],
    ["Left/right arm chains", "Mirrored controls", "Deform bones retain VT2-compatible names/rest; author controls may be custom but are excluded from game export."],
    ["Left/right hand and finger chains", "Weapon grip", "All required finger bones are weighted and tested against one- and two-handed grips."],
    ["Leg/foot/toe chains", "Foot planting", "Knee direction and toe roll remain stable in all eight locomotion directions."],
    ["Tail chain", "Secondary motion", "Sufficient segments for silhouette and procedural/animated sway; no scale keys."],
    ["Whisker root bones", "Secondary motion", "Symmetric named roots; card movement never exposes bright alpha planes."],
    ["Fur/accessory physics bones", "Secondary motion", "Only approved accessory bones; deterministic hierarchy; collision-safe limits documented."],
    ["Weapon attachment nodes", "Right/left/back/hip", "Named nodes match supported weapon templates and preserve handedness."],
    ["Career prop attachment nodes", "Bag/tool/trap", "Stable hand, back, and ground anchors with documented forward/up axes."],
    ["VFX nodes", "Muzzle/hand/bag/gas", "Named nodes exist for career skill and weapon effects; no dependency on render-only mesh names."],
    ["Four-influence skinning", "All meshes", "Every vertex has 1-4 normalized deform weights; no orphan groups or zero-weight vertices."],
    ["Inverse bind validation", "All skinned exports", "Blender rest skin, exported FBX, and compiled unit agree; no 100x local bone length or bind-space mismatch."],
    ["Left/right naming validation", "j_left / j_right and legacy names", "Mirroring workflow is author-friendly while exported deform names remain exactly compatible."],
  ];
  for (const [asset, variant, acceptance] of rigItems) {
    push("Rig and skinning", asset, "Both", variant, "Required", asset.includes("first-person") || asset.includes("Inverse") ? "P0" : "P1", asset.includes("validation") || asset.includes("Inverse") ? "Engineering" : "Janfon", ".blend source + export-ready deform rig", acceptance, `${SOURCES.pipeline}; ${SOURCES.firstPersonBuild}; ${SOURCES.blender}`);
  }
  for (const [asset, variant, acceptance] of [
    ["Ragdoll rig", "Dead player", "Bodies settle without explosion, stretching, or detached accessories."],
    ["Ragdoll collision bodies", "Torso/head/limbs/tail", "Collision shapes approximate mass and do not snag excessively on stairs or ledges."],
    ["Hit collision volumes", "Gameplay body", "Hit zones match visible silhouette and do not change gameplay reach unintentionally."],
    ["Character controller clearance", "Standing/crouching", "Visual mesh fits vanilla player capsule through doors, ladders, and ledges."],
    ["Fur/whisker collision", "Head/shoulders", "Secondary meshes do not pass through face/torso during normal movement."],
    ["Physics fallback pose", "Low detail / disabled physics", "Cards and tail remain acceptable when secondary simulation is unavailable."],
  ]) push("Physics and collision", asset, "Third person", variant, "Required", "P1", "Janfon", "Rig/physics setup and test scene", acceptance, `${SOURCES.ragdoll}; ${SOURCES.handoff}`);

  for (const [lod, target] of [["LOD0", "Hero view / near"], ["LOD1", "Normal combat"], ["LOD2", "Mid-distance"], ["LOD3", "Far-distance"]]) {
    push("Optimization", `Third-person ${lod}`, "Third person", target, lod === "LOD0" ? "Required" : "Conditional", lod === "LOD0" ? "P0" : "P2", "Janfon", `Optimized ${lod} mesh`, "Preserves silhouette and material boundaries; bone palette and alpha-card cost stay within donor-character range.", `${SOURCES.handoff}; ${SOURCES.cosmetics}`);
  }
  for (const asset of ["Shadow-caster mesh", "First-person shadow policy", "Mesh bounds", "Animation bounds", "Unit pivots", "Material slot naming", "Topology/normal cleanup", "UV set validation"]) {
    push("Technical model", asset, "Both", "Build gate", "Required", "P1", asset.includes("naming") || asset.includes("bounds") ? "Engineering" : "Janfon", "Validated source and compiler report", "No culling, shadow, tangent, pivot, winding, duplicate-face, or UV-set regressions in hero view and gameplay.", `${SOURCES.build}; ${SOURCES.pipeline}`);
  }
  return out;
}

function buildTextureRows() {
  const add = rows("TEX");
  const out = [];
  const push = (...args) => out.push(add(...args));
  const materialSets = ["Body/skin", "Outfit cloth", "Armor metal", "Globadier equipment", "Ammo box A", "Ammo box B", "Eyes", "Teeth/mouth", "Claws", "Tail", "Career bag", "Gas bomb", "Gas trap", "Base cosmetic"];
  const maps = [
    ["Base color / diffuse", "sRGB color, no baked lighting", "Required", "P0"],
    ["Normal + gloss", "VT2 channel orientation and packed gloss verified", "Required", "P0"],
    ["Specular / response", "Material response separates skin, cloth, metal, tooth, and leather", "Required", "P1"],
    ["Emissive / mask", "Black where unused; eyes/gas only where intentional", "Conditional", "P1"],
    ["Opacity / cutout mask", "Hard, clean coverage without gray fringe", "Conditional", "P1"],
  ];
  for (const material of materialSets) {
    for (const [mapName, criterion, requirement, priority] of maps) {
      if (mapName.startsWith("Opacity") && !["Outfit cloth", "Base cosmetic"].includes(material)) continue;
      if (mapName.startsWith("Emissive") && !["Eyes", "Globadier equipment", "Career bag", "Gas bomb", "Gas trap"].includes(material)) continue;
      push("Texture set", `${material}: ${mapName}`, "Both", "Final UV layout", requirement, priority, "Janfon", "Lossless source PNG/TGA plus compiled texture recipe input", `${criterion}; seams remain clean under mipmapping and 4K hero-view inspection.`, `${SOURCES.handoff}; ${SOURCES.atlas}`);
    }
  }
  for (const [asset, criterion] of [
    ["Whisker base color + opacity", "No bright fringe, tape-like specular, or visible card rectangle; alpha coverage survives mipmaps."],
    ["Whisker normal/response", "Near-neutral normal and restrained response prevent cards catching light as solid sheets."],
    ["Fur base color + opacity", "Card roots match underlying body; tips fade cleanly without halos."],
    ["Fur normal/response", "Lighting reads as soft fur rather than plastic planes; tangent orientation is consistent."],
    ["Fur/body color match", "Fur remains attached visually under hero-view and dark in-game lighting; no overbright legacy donor color."],
  ]) push("Alpha materials", asset, "Third person", "Cutout", "Required", "P0", "Janfon", "Dedicated texture maps and material assignment", criterion, `${SOURCES.handoff}; ${SOURCES.pipeline}`);

  for (const [asset, criterion] of [
    ["4096 opaque atlas", "All opaque material islands retain intended texel density and padding; no cross-tile bleed."],
    ["Atlas guard tiles", "Out-of-range/repeating UV islands sample their own material region instead of neighbors."],
    ["Atlas layout manifest", "Every material slot, source map, rectangle, padding, and transform is recorded and reproducible."],
    ["Neutral black emissive", "Donor Globadier green emissive is eliminated except where intentionally authored."],
    ["Normal-map channel validation", "Green/channel orientation is confirmed with a directional-light test, not judged from RGB appearance."],
    ["sRGB/linear import validation", "Color maps use sRGB; normal, masks, and packed response maps use linear sampling."],
    ["Mip and edge padding", "No seams or transparent halos at gameplay distance and reduced texture quality."],
    ["First/third-person consistency", "Hands and body share matching skin values without duplicate conflicting source maps."],
  ]) push("Material integration", asset, "Both", "Build pipeline", "Required", asset.includes("emissive") || asset.includes("Normal") ? "P0" : "P1", asset.includes("manifest") ? "Engineering" : "Janfon", "Source maps + verified compiled material", criterion, `${SOURCES.atlas}; ${SOURCES.build}; ${SOURCES.pipeline}`);

  for (const asset of ["Diffuse UV test grid", "Normal orientation sphere", "Alpha-card lighting test", "Dark keep lighting reference", "Bright hero-view lighting reference", "Colorblind/readability reference", "Texture compression comparison", "Seam/mipmap comparison"]) {
    push("Texture QA", asset, "Both", "Reference capture", "Required", "P2", "Janfon", "PNG comparison capture", "Clearly identifies pass/fail and build version; reusable for regression checks.", `${SOURCES.handoff}; ${SOURCES.milestone}`);
  }
  return out;
}

function buildUiRows() {
  const add = rows("UI");
  const out = [];
  const push = (...args) => out.push(add(...args));
  const fixed = [
    ["Portrait", "Hero-select picking portrait", "Hero select", "picking_portrait_pusfume", "Required", "P0", "Janfon", "Atlas-ready PNG", "Clickable portrait uses supplied Pusfume art, correct frame/mask, and no crop clipping.", SOURCES.careers],
    ["Portrait", "HUD unit-frame portrait", "HUD", "86x108 mask target", "Required", "P0", "Janfon", "Transparent PNG / atlas source", "Face remains readable at gameplay scale; alpha follows vanilla unit-frame mask.", SOURCES.portrait],
    ["Portrait", "Small/party portrait", "HUD", "60x70 mask target", "Required", "P0", "Janfon", "Transparent PNG / atlas source", "Readable in compact team frames, scoreboard, and spectator contexts.", SOURCES.portrait],
    ["Portrait", "Downed/dead portrait treatment", "HUD", "State overlay safe", "Required", "P1", "Janfon", "Portrait variant or overlay-safe base", "Vanilla downed/dead overlays remain legible and do not obscure identity.", SOURCES.hud],
    ["Career identity", "Career icon", "Menus/HUD", "Under-Empire Reject", "Required", "P0", "Janfon", "Monochrome + color atlas sources", "Legible at small size and visually distinct from Bardin and Versus enemy icons.", `${SOURCES.careers}; ${SOURCES.hero}`],
    ["Career identity", "Hero-select slot ornament/state", "Hero select", "Normal/hover/selected/disabled", "Required", "P0", "Janfon", "Atlas-ready icon states", "Selection, hover, focus, gamepad navigation, and unavailable state are visually clear at 1080p UI coordinates and 4K render.", SOURCES.hero],
    ["Career identity", "Friends-only TEST Workshop thumbnail", "Steam Workshop", "TEST", "Required", "P0", "Janfon", "Steam-ready PNG/JPG", "Clearly communicates development status without obscuring mod identity.", SOURCES.pipeline],
    ["Ability", "Skaven Ingenuity career skill icon", "HUD/talents", "Ready/cooldown", "Required", "P0", "Janfon", "Atlas-ready icon", "Reads as bag/crafting ability; cooldown fill and key prompt remain legible.", SOURCES.ability],
    ["Passive", "The Great Scheme icon", "Talents/HUD", "Quest system", "Required", "P0", "Janfon", "Atlas-ready icon", "Distinct from career skill and supports quest panel display.", SOURCES.spec],
    ["Perk", "Hell Pit Native icon", "Talents/HUD", "Poison immunity", "Required", "P1", "Janfon", "Atlas-ready icon", "Communicates poison/gas immunity without relying on text.", SOURCES.spec],
    ["Perk", "Scaredy-rat icon", "Talents/HUD", "Speed after damage", "Required", "P1", "Janfon", "Atlas-ready icon", "Communicates panic/speed and remains readable as a timed buff icon.", SOURCES.spec],
    ["Perk", "Insider Knowledge icon", "Talents/HUD", "Team Skaven vulnerability", "Required", "P1", "Janfon", "Atlas-ready icon", "Communicates team-wide knowledge/debuff and distinguishes Skaven target scope.", SOURCES.spec],
  ];
  for (const r of fixed) push(...r);
  for (let tier = 1; tier <= 6; tier++) {
    for (let choice = 1; choice <= 3; choice++) {
      push("Talent", `Talent icon T${tier}-${choice}`, "Talent grid", `Tier ${tier}, choice ${choice}`, "Required", tier <= 2 ? "P1" : "P2", "Janfon", "Atlas-ready icon + layered source", "Unique silhouette at talent-grid size; supports selected, hovered, locked, and equipped presentation.", SOURCES.talents);
    }
  }
  const questIcons = ["Kill Skaven", "Kill specials", "Kill elites", "Collect supplies", "Use bombs", "Use potions", "Complete without poison damage", "Team objective complete"];
  for (const quest of questIcons) push("Quest", `The Great Scheme quest icon: ${quest}`, "Quest panel/HUD", "Placeholder quest", "Required", "P1", "Janfon", "Atlas-ready icon", "Goal is recognizable without text and supports complete/incomplete state treatment.", `${SOURCES.spec}; ${SOURCES.kit}`);
  for (const asset of ["Bag interaction prompt", "Potion enchant option", "Bomb upgrade option", "Gas-trap craft option", "Invalid item state", "Craft success marker", "Craft failure marker", "Bag owner marker", "Bag cooldown/charges marker", "Gas trap placement reticle"]) {
    push("Career interaction UI", asset, "HUD/world marker", "Normal/hover/disabled", "Required", "P1", "Janfon", "Atlas-ready icon or reticle", "Readable on keyboard/mouse and gamepad; does not reuse ambiguous inventory symbols.", `${SOURCES.interactions}; ${SOURCES.hud}; ${SOURCES.inventory}`);
  }
  for (const asset of ["Career nameplate lockup", "Pusfume character-name lockup", "Loading-screen portrait", "Scoreboard portrait", "Spectator portrait", "Respawn portrait", "Chat/voice indicator portrait", "Accessibility contrast pass"]) {
    push("Presentation UI", asset, "Menus/HUD", "Localized layout", asset.includes("Loading") ? "Conditional" : "Required", "P2", "Janfon", "Atlas source or layout-safe artwork", "Works with UNDER-EMPIRE REJECT and Pusfume localization, long-string fallback, and 1080p logical UI scaling.", `${SOURCES.hero}; ${SOURCES.hud}; ${SOURCES.versusHud}`);
  }
  return out;
}

function buildAudioRows() {
  const add = rows("AUD");
  const out = [];
  const push = (...args) => out.push(add(...args));
  push("Temporary VO routing", "Playable Globadier combat voice substitution", "Player", "character_vo=vs_poison_wind_globadier", "Required", "P0", "Engineering", "Runtime routing; no new audio file", "Weapon exertions and non-dialogue rat vocalizations replace Bardin where compatible, without changing Bardin's shared profile globally.", `${SOURCES.versusProfiles}; ${SOURCES.versusCareers}`, "Temporary implementation reference until original Pusfume VO is recorded.", "In Progress");
  const categories = {
    "Movement exertion": ["Jump", "Dodge", "Sprint/run", "Hard landing", "Climb/ledge pull-up", "Carry strain"],
    "Melee exertion": ["Light attack short", "Light attack long", "Heavy charge", "Heavy release", "Push", "Block impact", "Parry", "Attack whiff"],
    "Ranged exertion": ["Aim", "Fire/release", "Recoil", "Reload effort", "Throw charge", "Throw release", "Dry fire reaction"],
    "Damage VO": ["Light hurt", "Heavy hurt", "Poison/gas reaction", "Fire reaction", "Friendly-fire reaction", "Stagger", "Downed", "Revived", "Death"],
    "Disabled VO": ["Packmaster grab", "Gutter Runner pounce", "Chaos Spawn grab", "Corruptor grab", "Tentacle grab", "Vortex", "Hanging/ledge distress"],
    "Career skill VO": ["Bag ready", "Bag deploy", "Invite ally to use bag", "Potion enchanted", "Bomb upgraded", "Gas trap crafted", "Craft failed", "Bag recovered", "Ability interrupted"],
    "Quest VO": ["Quest assigned", "Quest progress", "Quest complete", "All quests complete", "Quest failed"],
    "Team VO": ["Enemy spotted", "Special spotted", "Elite spotted", "Boss spotted", "Ammo callout", "Healing callout", "Potion callout", "Bomb callout", "Revive callout", "Thanks", "Apology", "Friendly fire dealt", "Friendly fire received"],
    "Social VO": ["Keep idle bark", "Mission start", "Mission complete", "Mission failed", "Hero-select confirmation", "Emote acknowledgement"],
  };
  for (const [category, clips] of Object.entries(categories)) {
    for (const clip of clips) {
      push(category, clip, "Player/3D VO", "3-6 variations", category === "Social VO" || category === "Team VO" ? "Conditional" : "Required", category.includes("skill") || category.includes("Damage") || category.includes("Melee") ? "P1" : "P2", "Audio", "48 kHz mono WAV masters + Wwise event plan", "No Bardin performance remains; variation avoids obvious repetition; loudness, distance curve, and interruption behavior match VT2 player VO.", `${SOURCES.dialogue}; ${SOURCES.versusProfiles}`);
    }
  }
  const foley = ["Bare paw footsteps stone", "Bare paw footsteps wood", "Bare paw footsteps dirt", "Bare paw footsteps snow", "Bare paw footsteps metal", "Armor/cloth movement", "Bag equipment rattle", "Tail/fur movement", "Weapon draw/stow sweetener", "Hand contact/interaction", "Body fall/ragdoll", "Ladder/ledge contact"];
  for (const clip of foley) push("Foley", clip, "3D SFX", "Surface or intensity variants", "Required", "P2", "Audio", "48 kHz WAV set + Wwise event", "Timing matches animation contacts and does not mask gameplay-critical enemy cues.", `${SOURCES.states}; ${SOURCES.dialogue}`);
  const abilitySfx = ["Bag equip", "Bag placement", "Bag ground impact", "Bag ambient loop", "Bag interaction start", "Enchant processing loop", "Enchant success", "Enchant failure", "Bomb upgrade", "Gas trap craft", "Gas trap place", "Gas trap arm", "Gas trap trigger", "Gas release loop", "Gas dissipate", "Ability cooldown ready", "Quest progress stinger", "Quest complete stinger"];
  for (const clip of abilitySfx) push("Career SFX", clip, "2D/3D SFX", "Local and remote mix", "Required", clip.includes("place") || clip.includes("success") || clip.includes("trigger") ? "P1" : "P2", "Audio", "48 kHz WAV + Wwise event", "Has clear gameplay timing, remote attenuation, and no collision with existing Globadier warning language.", `${SOURCES.ability}; ${SOURCES.interactions}; ${SOURCES.spec}`);
  return out;
}

function buildVfxRows() {
  const add = rows("VFX");
  const out = [];
  const push = (...args) => out.push(add(...args));
  const vfx = [
    ["Skaven Ingenuity bag", "Placement ghost", "Valid/invalid ground"], ["Skaven Ingenuity bag", "Deploy burst", "Placement event"], ["Skaven Ingenuity bag", "Idle active effect", "Available"],
    ["Skaven Ingenuity bag", "Cooldown/inactive effect", "Unavailable"], ["Skaven Ingenuity bag", "Interaction beam/highlight", "User targeting"], ["Skaven Ingenuity bag", "Despawn/pickup", "End state"],
    ["Potion enchant", "Processing effect", "Held potion"], ["Potion enchant", "Success effect", "Inventory update"], ["Potion enchant", "Failure effect", "Invalid inventory"],
    ["Gas bomb", "Upgrade effect", "Bomb conversion"], ["Gas bomb", "Projectile trail", "Thrown"], ["Gas bomb", "Impact burst", "Detonation"], ["Gas bomb", "Poison cloud", "Area lifetime"], ["Gas bomb", "Cloud edge/readability", "Team-safe telegraph"],
    ["Gas trap", "Placement ghost", "Valid/invalid"], ["Gas trap", "Armed indicator", "Owner/team"], ["Gas trap", "Trigger flash", "Activation"], ["Gas trap", "Gas cloud", "Area lifetime"], ["Gas trap", "Expiry/destruction", "End state"],
    ["Perk feedback", "Hell Pit Native immunity", "Blocked poison damage"], ["Perk feedback", "Scaredy-rat proc", "20% speed / 3 seconds"], ["Perk feedback", "Insider Knowledge target mark", "Skaven team vulnerability"],
    ["Quest feedback", "The Great Scheme progress", "Increment"], ["Quest feedback", "The Great Scheme complete", "Completion"],
  ];
  for (const [asset, effect, variant] of vfx) push("VFX", `${asset}: ${effect}`, "First/third/world", variant, "Required", asset.includes("bag") || effect.includes("cloud") ? "P0" : "P1", "VFX", "Particle/material/light asset + event binding", "Readable in bright and dark maps, colorblind-safe, bounded for performance, and synchronized for remote clients.", `${SOURCES.spec}; ${SOURCES.ability}; ${SOURCES.interactions}`);
  const gameplay = [
    ["Bag world unit", "Collision, interaction volume, owner, lifetime, charges"],
    ["Potion enchant recipe set", "Every supported potion and invalid-item fallback"],
    ["Gas bomb item definition", "Inventory icon, projectile, explosion, damage-over-time and friendly-fire policy"],
    ["Gas trap item definition", "Inventory, placement, arm delay, trigger, lifetime, network ownership"],
    ["Gas cloud damage profile", "Poison type, tick rate, radius, falloff, stacking, immunity interaction"],
    ["Hell Pit Native buff", "Globadier gas and poison immunity scope verified"],
    ["Scaredy-rat buff", "20% movement speed for 3 seconds after damage; cooldown/stacking defined"],
    ["Insider Knowledge debuff", "All team members deal 5% more damage to Skaven; stacking defined"],
    ["The Great Scheme quest pool", "Skaven-themed placeholder objectives, progress, completion, reset"],
    ["Quest selection UI data", "Active quest visibility and localized descriptions"],
    ["Career skill cooldown/charges", "Authoritative server logic and HUD synchronization"],
    ["Career skill interruption", "Damage, ledge, disable, death, item swap, and disconnect handling"],
    ["Network RPC/state replication", "Bag, recipes, traps, clouds, buffs, quest progress"],
    ["Bot behavior", "Bag deploy/use, trap placement, and quest participation policy"],
    ["Friendly-fire policy", "Gas bomb/trap damage and ally visibility"],
    ["Save/load/backend policy", "Career loadout, talents, quests, and unlock fallback"],
    ["Localization keys", "Names, descriptions, prompts, quest text, talent text, errors"],
    ["Telemetry/debug commands", "Spawn, trigger, complete quest, inspect bag, clear VFX"],
  ];
  for (const [asset, acceptance] of gameplay) push("Gameplay integration", asset, "Runtime", "Server/client", "Required", asset.includes("Network") || asset.includes("world unit") || asset.includes("cooldown") ? "P0" : "P1", "Engineering", "Lua settings/actions/buffs/tests", `${acceptance}; regression tests cover host, client, bot, death, and reconnect where applicable.`, `${SOURCES.spec}; ${SOURCES.kit}; ${SOURCES.ability}`);
  return out;
}

function buildExportRows() {
  const add = rows("EXP");
  const out = [];
  const push = (...args) => out.push(add(...args));
  const specs = [
    ["Blender version", "5.2.0", "Open, validate, and export with the supported Pusfume add-on under Blender 5.2.0."],
    ["Source preservation", ".blend committed via Git LFS", "Never overwrite the authored source during cleanup or game export."],
    ["FBX version", "Binary FBX 7.4 / 2014", "Importer accepts the file and reports expected meshes, bones, UVs, and actions."],
    ["Selection", "Selected Objects only", "Export contains only intended meshes, armature, and required animation data."],
    ["Axes", "Forward -Y; Up Z", "Round-trip orientation matches VT2/Stingray without corrective runtime rotation."],
    ["Unit scale", "Meters; effective object scale 1", "Mesh, local bones, bind matrices, and compiled node transforms agree; no 100x compensation."],
    ["Root placement", "Origin, unit scale, no unintended rotation", "Root starts at 0,0,0 and does not drift for in-place clips."],
    ["Transforms", "Apply mesh/armature object transforms before final bind", "No non-uniform or negative scale remains on export objects."],
    ["Leaf bones", "Disabled", "No synthetic end bones appear in the exported skeleton."],
    ["Deform bones", "Only deform hierarchy exported to game", "Control/driver/helper bones are either excluded or explicitly approved."],
    ["Bone names", "Exact VT2-compatible names", "Case, prefixes, left/right mapping, and hierarchy pass validator."],
    ["Rest pose", "Canonical donor-compatible rest matrices", "All shared bones remain within 0.0001 matrix error after compile."],
    ["Animation rate", "30 FPS canonical", "Clip duration and sample count match exported frames; no unintended resampling."],
    ["Animation baking", "Bake authored deform motion", "Rotation and required translation channels survive without drivers/constraints at runtime."],
    ["NLA/actions", "One canonical named action per exported clip", "No duplicate near-identical actions or accidental active action."],
    ["Loop clips", "First/last pose continuity", "Position, rotation, and visible mesh deformation close without a pop."],
    ["Root motion", "In-place unless explicitly specified", "Engine locomotion remains authoritative; exceptions are documented per clip."],
    ["Scale keys", "No animated scale keys", "Scale channels are absent or exactly constant and validated before export."],
    ["Rotation interpolation", "Stable quaternion/Euler bake", "No 180-degree flip, gimbal discontinuity, or left/right inversion."],
    ["Mesh triangulation", "Triangulated final export", "Triangle count and material assignment are deterministic."],
    ["Custom normals", "Preserved", "Hero-view lighting shows no unexpected hard edges or flipped tangents."],
    ["UV sets", "One intentional UV set per current pipeline", "No empty/duplicate UV map; out-of-range islands are documented for atlas guards."],
    ["Weights", "1-4 normalized influences per vertex", "No unweighted vertices; discarded weights remain below approved error threshold."],
    ["Material slots", "Stable canonical names", "Slots map deterministically to atlas/material recipes; no auto-renamed .001 suffixes."],
    ["Embedded media", "Disabled", "Textures are delivered separately and not duplicated in FBX."],
    ["Texture source", "Lossless PNG/TGA, semantic suffixes", "Base color, normal/gloss, response, emissive, and alpha roles are explicit."],
    ["1p/3p separation", "Separate character exports", "First-person arms exclude full body and third-person body excludes camera-only helpers."],
    ["Equipment separation", "Separate weapon/prop units", "Bag, bomb, trap, hats, and weapons can be hidden/attached independently."],
    ["Ragdoll/physics separation", "Documented game setup", "Render skeleton and physics/collision data agree without exporting Blender-only simulation."],
    ["File naming", "snake_case; pusfume_[view]_[action]", "Names are stable, unique, ASCII, and match recipe/controller events."],
    ["Folder layout", "art_source/, units/, textures/", "Handoff matches repository pipeline and Git LFS rules."],
    ["Validation pass", "Run add-on validation before export", "Errors block export; warnings remain visible and actionable, never softlock the add-on."],
    ["Cleanup behavior", "Non-destructive and recoverable", "Validation may propose/fix safe issues but never silently delete authored data."],
    ["Round-trip test", "Re-import exported FBX into clean Blender scene", "Bone names, local lengths, materials, weights, actions, FPS, and bounds match expectations."],
    ["Compiler test", "VT2 SDK compiler succeeds", "Unit, skeleton, animation, state machine, materials, and package compile without missing resources."],
    ["Rest-matrix test", "validate_compiled_1p_rest.py / equivalent", "Compiled first-person nodes remain within tolerance of donor source."],
    ["Live animation test", "Hero preview + 1p + 3p + remote client", "Actual skin deformation, not merely controller time, is visible in every context."],
    ["Material test", "Bright and dark map lighting", "No donor-green emissive, UV bleed, alpha tape, or overbright fur."],
    ["Performance test", "Near/mid/far, hordes, remote clients", "No unacceptable CPU, GPU, memory, package-size, or hitch regression."],
    ["Handoff manifest", "JSON/CSV plus workbook status", "Every delivered file has owner, version, source, license, checksum, and acceptance result."],
  ];
  for (const [asset, variant, acceptance] of specs) push("Export contract", asset, "Pipeline", variant, "Required", ["Unit scale", "Rest pose", "Weights", "Live animation test"].includes(asset) ? "P0" : "P1", asset.includes("Texture") || asset.includes("Material") ? "Janfon" : "Janfon + Engineering", "Validated source/export artifact", acceptance, `${SOURCES.pipeline}; ${SOURCES.firstPersonBuild}; ${SOURCES.blender}; ${SOURCES.build}`);
  const docs = [
    ["Autodesk Stingray character setup", "https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/animation/set_up_character.html"],
    ["Autodesk Stingray animation controllers", "https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/animation/animation_controllers.html"],
    ["Autodesk Stingray Unit Lua API", "https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/lua_ref/obj_stingray_Unit.html"],
    ["Git LFS", "https://git-lfs.com/"],
  ];
  for (const [asset, url] of docs) push("External reference", asset, "Pipeline", "Authoritative documentation", "Required", "P2", "Janfon + Engineering", "Read/reference", "Relevant constraints are incorporated into source scene, export preset, and validation evidence.", url, "Plain-text URL retained for auditability.");
  return out;
}

function buildSourceRows() {
  const add = rows("SRC");
  const out = [];
  const entries = [
    ["SRC-001", "Player character states", `${vt2Root}/scripts/unit_extensions/default_player_unit/states/`, "31 concrete state files: standing, walking, dodging, jumping, falling, ladders, ledges, disabled, downed, dead, interaction, emote, transport."],
    ["SRC-002", "First-person extension", `${vt2Root}/scripts/unit_extensions/default_player_unit/player_unit_first_person.lua`, "First-person animation events, state changes, visibility, aim, camera rig, and jump handling."],
    ["SRC-003", "Character state helper", `${vt2Root}/scripts/unit_extensions/default_player_unit/states/player_character_state_helper.lua`, "Shared first/third-person animation dispatch and movement helpers."],
    ["SRC-004", "Base career settings", `${vt2Root}/scripts/settings/profiles/career_settings.lua`, "Career display name, portraits, profile name, sound character, preview idle animation, talents, passives, and ability data."],
    ["SRC-005", "Versus career settings", `${vt2Root}/scripts/settings/profiles/career_settings_vs.lua`, "Playable rat career precedent, including Globadier portrait, preview idle, profile and sound routing."],
    ["SRC-006", "Hero profiles", `${vt2Root}/scripts/settings/profiles/sp_profiles.lua`, "Hero identity, ingame names, career registration, character/camera state validation."],
    ["SRC-007", "Versus profiles", `${vt2Root}/scripts/settings/profiles/vs_profiles.lua`, "Playable Globadier character_vo, display names, base units and career association."],
    ["SRC-008", "Cosmetics", `${vt2Root}/scripts/settings/equipment/cosmetics.lua`, "Separate 1p/3p units, attachments, material changes, skins, and cosmetic package references."],
    ["SRC-009", "Weapon templates", `${vt2Root}/scripts/settings/equipment/weapon_templates/`, "Attack, charge, block, push, parry, aim, fire, reload, throw and 3p animation-event contracts."],
    ["SRC-010", "HUD UI", `${vt2Root}/scripts/ui/hud_ui/`, "Unit frames, portraits, ability UI, buffs, interactions, world markers, scoreboard and Versus HUD components."],
    ["SRC-011", "Hero view", `${vt2Root}/scripts/ui/views/hero_view/`, "Hero/career selection, inventory, cosmetics, talents, preview model and menu presentation."],
    ["SRC-012", "Talent system/UI", `${vt2Root}/scripts/managers/talents/`, "Talent tiers/settings and presentation expectations."],
    ["SRC-013", "Dialogue settings", `${vt2Root}/scripts/settings/dialogue_settings.lua`, "Dialogue/VO system configuration and character routing context."],
    ["SRC-014", "Interactions", `${vt2Root}/scripts/unit_extensions/generic/interactions.lua`, "Interaction types, timings, completion/cancel behavior and HUD prompts."],
    ["SRC-015", "Locomotion helpers", `${vt2Root}/scripts/helpers/locomotion_utils.lua`, "Movement direction/speed helpers used by player states."],
    ["SRC-016", "Base units", `${vt2Root}/scripts/settings/profiles/base_units.lua`, "Player base-unit and ragdoll/unit resource conventions."],
    ["SRC-017", "Ability HUD", `${vt2Root}/scripts/ui/hud_ui/ability_ui.lua`, "Career ability icon, cooldown/charge display and activation feedback."],
    ["SRC-018", "Inventory", `${vt2Root}/scripts/settings/inventory_settings.lua`, "Inventory slot/item context needed by potion, bomb and trap conversion."],
    ["SRC-019", "Versus HUD components", `${vt2Root}/scripts/ui/hud_ui/component_list_definitions/hud_component_list_versus.lua`, "Playable-rat HUD composition and dark-pact presentation precedent."],
    ["SRC-020", "Pusfume asset pipeline", `${repoRoot}/docs/ASSET_PIPELINE.md`, "Validated FBX, Blender, Stingray, atlas, compiler, Workshop, and animation-controller rules."],
    ["SRC-021", "Pusfume model handoff", `${repoRoot}/docs/MODEL_HANDOFF.md`, "Current mesh, rig, material slots, textures, fur/whisker constraints and donor architecture."],
    ["SRC-022", "Pusfume career spec V2", `${repoRoot}/docs/PUSFUME_CAREER_SPEC_V2.md`, "Current career identity, passive, perks, skill, quests, talents and gameplay requirements."],
    ["SRC-023", "Pusfume career kit", `${repoRoot}/docs/CAREER_KIT.md`, "Implementation-facing career data and placeholder asset needs."],
    ["SRC-024", "Portrait builder", `${repoRoot}/tools/Build-PusfumePortrait.ps1`, "Validated Pusfume portrait masks and atlas-generation workflow."],
    ["SRC-025", "Animated 3p preparation", `${repoRoot}/tools/prepare_animated_pusfume_fbx.py`, "Action transfer, fur deformation and skinned FBX export gates."],
    ["SRC-026", "First-person preparation", `${repoRoot}/tools/prepare_pusfume_1p_blend.py`, "Donor rest matrices, 1p mesh validation, weight normalization and export."],
    ["SRC-027", "Native build", `${repoRoot}/tools/Build-NativePusfume.ps1`, "VT2 SDK compile, materials, controller, package staging, deploy and Workshop integration."],
    ["SRC-028", "Atlas layout", `${repoRoot}/tools/pusfume_atlas_layout.json`, "Opaque material UV layout, source regions and guard-tile contract."],
    ["SRC-029", "Native character milestone", `${repoRoot}/docs/NATIVE_CHARACTER_MILESTONE.md`, "Empirical proof boundary for animated model/material integration and remaining limitations."],
    ["SRC-030", "Bitsquid Blender tools", "C:/Users/danjo/source/repos/_bitsquid_blender_tools", "Local legacy Bitsquid Blender integration reference; use for research, not as sole compatibility proof."],
    ["SRC-031", "Bitsquid Blender tools wiki", "C:/Users/danjo/source/repos/_bitsquid_blender_tools_wiki", "Local workflow notes for Bitsquid asset exchange."],
    ["SRC-032", "Stingray reverse engineering", "C:/Users/danjo/source/repos/_stingray_reverse_engineering", "Local experiments and format diagnostics; empirical support only."],
    ["SRC-033", "First-person scale experiment", `${repoRoot}/tools/experiment_pusfume_1p_scale.py`, "Current empirical investigation of bind-space/object-scale alternatives."],
    ["SRC-034", "Compiled rest validator", `${repoRoot}/tools/validate_compiled_1p_rest.py`, "Checks first-person compiled scene graph against donor rest transforms."],
  ];
  for (const [id, asset, location, purpose] of entries) {
    const row = add("Source map", asset, "Reference", id, "Required", "P1", "Engineering", location, purpose, location, "Reviewed locally for this workbook.", "Complete");
    row[0] = id;
    out.push(row);
  }
  return out;
}

const datasets = [
  { name: "Animations", title: "Animation Checklist", subtitle: "Authoring inventory for first person, third person, locomotion, combat, traversal, incapacitation, interaction, and career presentation.", rows: buildAnimationRows() },
  { name: "Models-Rig-Physics", title: "Models, Rig & Physics", subtitle: "Character geometry, canonical rigs, attachments, skinning, secondary motion, collision, ragdoll, LOD, and technical model gates.", rows: buildModelRows() },
  { name: "Textures-Materials", title: "Textures & Materials", subtitle: "Per-surface map requirements, alpha-card treatment, atlas integration, color-space rules, and visual regression references.", rows: buildTextureRows() },
  { name: "UI-Icons", title: "UI, Portraits & Icons", subtitle: "Hero-select, HUD, career identity, talents, quests, career interactions, Workshop presentation, and localization-safe assets.", rows: buildUiRows() },
  { name: "Audio-VO", title: "Audio & Voice", subtitle: "Temporary Versus-rat routing plus the complete original VO, exertion, foley, career SFX, quest, team, and social recording inventory.", rows: buildAudioRows() },
  { name: "VFX-Gameplay", title: "VFX & Gameplay Assets", subtitle: "Career-skill effects, props, gas readability, buffs, quests, networking, bot behavior, interaction, and gameplay integration contracts.", rows: buildVfxRows() },
  { name: "Export-Specs", title: "Export & Validation Specs", subtitle: "Blender 5.2, FBX, rig, animation, texture, compiler, live-test, performance, provenance, and handoff requirements.", rows: buildExportRows() },
  { name: "Source-Map", title: "Source Map", subtitle: "Auditable local references used to derive this workbook. Source IDs are repeated throughout the detailed checklists.", rows: buildSourceRows() },
];

function styleTitle(sheet, title, subtitle, endColumn = "M") {
  sheet.showGridLines = false;
  sheet.mergeCells(`A1:${endColumn}1`);
  sheet.mergeCells(`A2:${endColumn}2`);
  sheet.getRange("A1").values = [[title]];
  sheet.getRange("A2").values = [[subtitle]];
  sheet.getRange(`A1:${endColumn}1`).format = {
    fill: COLORS.ink,
    font: { name: "Aptos Display", size: 20, bold: true, color: COLORS.white },
    verticalAlignment: "center",
  };
  sheet.getRange(`A2:${endColumn}2`).format = {
    fill: COLORS.navy,
    font: { name: "Aptos", size: 10, color: "#E8EEF2" },
    verticalAlignment: "center",
    wrapText: true,
  };
  sheet.getRange(`A1:${endColumn}1`).format.rowHeight = 34;
  sheet.getRange(`A2:${endColumn}2`).format.rowHeight = 34;
}

function setDetailWidths(sheet, lastRow) {
  const widths = { A: 13, B: 22, C: 36, D: 16, E: 25, F: 14, G: 12, H: 19, I: 20, J: 31, K: 58, L: 58, M: 44 };
  for (const [col, width] of Object.entries(widths)) sheet.getRange(`${col}1:${col}${lastRow}`).format.columnWidth = width;
}

function addValidationsAndStatusFormatting(sheet, lastRow) {
  sheet.getRange(`F5:F${lastRow}`).dataValidation = { rule: { type: "list", values: ["Required", "Optional", "Conditional"] } };
  sheet.getRange(`G5:G${lastRow}`).dataValidation = { rule: { type: "list", values: ["P0", "P1", "P2", "P3"] } };
  sheet.getRange(`H5:H${lastRow}`).dataValidation = { rule: { type: "list", values: ["Not Started", "In Progress", "Ready for Review", "Prototype Ready", "Blocked", "Complete", "Not Applicable"] } };
  sheet.getRange(`I5:I${lastRow}`).dataValidation = { rule: { type: "list", values: ["Janfon", "Engineering", "Audio", "VFX", "Design", "QA", "Janfon + Engineering", "Unassigned"] } };
  const status = sheet.getRange(`H5:H${lastRow}`);
  status.conditionalFormats.add("containsText", { text: "Complete", format: { fill: COLORS.green, font: { color: "#155724", bold: true } } });
  status.conditionalFormats.add("containsText", { text: "In Progress", format: { fill: COLORS.amber, font: { color: "#7A5300", bold: true } } });
  status.conditionalFormats.add("containsText", { text: "Prototype Ready", format: { fill: COLORS.blue, font: { color: "#1F4E79", bold: true } } });
  status.conditionalFormats.add("containsText", { text: "Blocked", format: { fill: COLORS.red, font: { color: "#842029", bold: true } } });
  const priority = sheet.getRange(`G5:G${lastRow}`);
  priority.conditionalFormats.add("containsText", { text: "P0", format: { fill: COLORS.red, font: { color: "#842029", bold: true } } });
  priority.conditionalFormats.add("containsText", { text: "P1", format: { fill: COLORS.amber, font: { color: "#7A5300", bold: true } } });
}

function createDetailSheet(workbook, dataset, index) {
  const sheet = workbook.worksheets.add(dataset.name);
  styleTitle(sheet, dataset.title, dataset.subtitle);
  sheet.getRange("A4:M4").values = [COLUMNS];
  const lastRow = dataset.rows.length + 4;
  sheet.getRange(`A5:M${lastRow}`).values = dataset.rows;
  sheet.getRange("A4:M4").format = {
    fill: COLORS.teal,
    font: { name: "Aptos", size: 10, bold: true, color: COLORS.white },
    verticalAlignment: "center",
    wrapText: true,
    borders: { bottom: { style: "medium", color: COLORS.gold } },
  };
  sheet.getRange(`A5:M${lastRow}`).format = {
    font: { name: "Aptos", size: 9, color: COLORS.ink },
    verticalAlignment: "top",
    wrapText: true,
    borders: { insideHorizontal: { style: "thin", color: COLORS.line } },
  };
  sheet.getRange(`A5:A${lastRow}`).format.font = { name: "Aptos", size: 9, bold: true, color: COLORS.teal };
  sheet.getRange(`F5:I${lastRow}`).format.horizontalAlignment = "center";
  sheet.getRange("A4:M4").format.rowHeight = 32;
  sheet.getRange(`A5:M${lastRow}`).format.rowHeight = 46;
  setDetailWidths(sheet, lastRow);
  addValidationsAndStatusFormatting(sheet, lastRow);
  sheet.freezePanes.freezeRows(4);
  sheet.freezePanes.freezeColumns(2);
  const tableName = `${dataset.name.replace(/[^A-Za-z0-9]/g, "")}Table${index}`;
  const table = sheet.tables.add(`A4:M${lastRow}`, true, tableName);
  table.style = "TableStyleMedium2";
  table.showFilterButton = true;
  return { sheet, lastRow };
}

function aggregateFormula(column, criterion = null) {
  const formulas = datasets.map((dataset) => {
    const lastRow = dataset.rows.length + 4;
    return criterion === null
      ? `COUNTA('${dataset.name}'!${column}5:${column}${lastRow})`
      : `COUNTIF('${dataset.name}'!${column}5:${column}${lastRow},\"${criterion}\")`;
  });
  return `=SUM(${formulas.join(",")})`;
}

function populateDashboard(workbook, sheet) {
  styleTitle(sheet, "Pusfume Career Production Dashboard", "Source-referenced master checklist for Janfon and the engineering team. Update Status, Owner, Priority, and Requirement fields on the detailed sheets; this dashboard recalculates automatically.", "N");
  sheet.showGridLines = false;

  const cards = [
    ["A4:C4", "A5:C6", "TOTAL ITEMS", aggregateFormula("A")],
    ["D4:F4", "D5:F6", "REQUIRED", aggregateFormula("F", "Required")],
    ["G4:I4", "G5:I6", "COMPLETE", aggregateFormula("H", "Complete")],
    ["J4:L4", "J5:L6", "IN PROGRESS", aggregateFormula("H", "In Progress")],
  ];
  for (const [labelRange, valueRange, label, formula] of cards) {
    sheet.mergeCells(labelRange);
    sheet.mergeCells(valueRange);
    sheet.getRange(labelRange.split(":")[0]).values = [[label]];
    sheet.getRange(valueRange.split(":")[0]).formulas = [[formula]];
    sheet.getRange(labelRange).format = { fill: COLORS.navy, font: { name: "Aptos", size: 9, bold: true, color: "#DCE7ED" }, horizontalAlignment: "center", verticalAlignment: "center" };
    sheet.getRange(valueRange).format = { fill: COLORS.parchment, font: { name: "Aptos Display", size: 23, bold: true, color: COLORS.ink }, horizontalAlignment: "center", verticalAlignment: "center", borders: { bottom: { style: "medium", color: COLORS.gold } } };
  }
  sheet.getRange("M4:N4").merge();
  sheet.getRange("M5:N6").merge();
  sheet.getRange("M4").values = [["REQUIRED COMPLETE"]];
  sheet.getRange("M5").formulas = [[`=IFERROR(${aggregateFormula("H", "Complete").slice(1)}/${aggregateFormula("F", "Required").slice(1)},0)`]];
  sheet.getRange("M4:N4").format = { fill: COLORS.teal, font: { name: "Aptos", size: 9, bold: true, color: COLORS.white }, horizontalAlignment: "center", verticalAlignment: "center" };
  sheet.getRange("M5:N6").format = { fill: COLORS.tealLight, font: { name: "Aptos Display", size: 22, bold: true, color: COLORS.teal }, horizontalAlignment: "center", verticalAlignment: "center", numberFormat: "0%", borders: { bottom: { style: "medium", color: COLORS.teal } } };

  sheet.getRange("A8:C8").values = [["WORKSTREAM", "TOTAL", "P0 OPEN"]];
  const workstreamRows = datasets.map((dataset) => {
    const lastRow = dataset.rows.length + 4;
    return [dataset.title, `=COUNTA('${dataset.name}'!A5:A${lastRow})`, `=COUNTIFS('${dataset.name}'!G5:G${lastRow},\"P0\",'${dataset.name}'!H5:H${lastRow},\"<>Complete\")`];
  });
  sheet.getRange(`A9:C${8 + workstreamRows.length}`).values = workstreamRows.map((r) => [r[0], null, null]);
  sheet.getRange(`B9:C${8 + workstreamRows.length}`).formulas = workstreamRows.map((r) => [r[1], r[2]]);
  sheet.getRange("A8:C8").format = { fill: COLORS.teal, font: { bold: true, color: COLORS.white }, horizontalAlignment: "center", borders: { bottom: { style: "medium", color: COLORS.gold } } };
  sheet.getRange(`A9:C${8 + workstreamRows.length}`).format = { fill: COLORS.white, font: { name: "Aptos", size: 10, color: COLORS.ink }, borders: { insideHorizontal: { style: "thin", color: COLORS.line } }, verticalAlignment: "center" };
  sheet.getRange(`B9:C${8 + workstreamRows.length}`).format.horizontalAlignment = "center";

  sheet.getRange("A19:C19").values = [["STATUS", "COUNT", "% OF TOTAL"]];
  const statuses = ["Not Started", "In Progress", "Ready for Review", "Prototype Ready", "Blocked", "Complete", "Not Applicable"];
  sheet.getRange("A20:A26").values = statuses.map((s) => [s]);
  sheet.getRange("B20:B26").formulas = statuses.map((s) => [aggregateFormula("H", s)]);
  sheet.getRange("C20:C26").formulas = statuses.map((_, i) => [`=IFERROR(B${20 + i}/$B$27,0)`]);
  sheet.getRange("A27").values = [["Total"]];
  sheet.getRange("B27").formulas = [[aggregateFormula("A")]];
  sheet.getRange("C27").formulas = [["=IFERROR(SUM(C20:C26),0)"]];
  sheet.getRange("A19:C19").format = { fill: COLORS.navy, font: { bold: true, color: COLORS.white }, horizontalAlignment: "center" };
  sheet.getRange("A20:C27").format = { font: { name: "Aptos", size: 10, color: COLORS.ink }, borders: { insideHorizontal: { style: "thin", color: COLORS.line } } };
  sheet.getRange("C20:C27").format.numberFormat = "0%";
  sheet.getRange("A27:C27").format = { fill: COLORS.parchment, font: { bold: true, color: COLORS.ink }, borders: { top: { style: "medium", color: COLORS.gold } } };

  sheet.mergeCells("E20:N20");
  sheet.mergeCells("E21:N24");
  sheet.getRange("E20").values = [["HOW TO USE THIS WORKBOOK"]];
  sheet.getRange("E21").values = [["Janfon: filter each detailed sheet by Owner, Priority, Requirement, or Status. Engineering: keep source IDs and acceptance criteria current as runtime contracts evolve. Mark an item Complete only after its stated acceptance criteria are demonstrated in Blender/compiler tests and, where required, in a live host/client game test. Unknown or future-roster work should be Conditional rather than silently omitted."]];
  sheet.getRange("E20:N20").format = { fill: COLORS.navy, font: { bold: true, color: COLORS.white }, verticalAlignment: "center" };
  sheet.getRange("E21:N24").format = { fill: COLORS.parchment, font: { name: "Aptos", size: 11, color: COLORS.ink }, wrapText: true, verticalAlignment: "top", borders: { bottom: { style: "medium", color: COLORS.gold } } };

  const chart = sheet.charts.add("bar", sheet.getRange(`A8:B${8 + workstreamRows.length}`));
  chart.title = "Checklist items by workstream";
  chart.hasLegend = false;
  chart.xAxis = { axisType: "textAxis", textStyle: { fontSize: 9 } };
  chart.yAxis = { numberFormatCode: "0" };
  chart.setPosition("E8", "N18");

  for (const col of ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N"]) sheet.getRange(`${col}1:${col}27`).format.columnWidth = col === "A" ? 28 : 13;
  sheet.getRange("E1:N27").format.columnWidth = 13;
  sheet.getRange("A4:N6").format.rowHeight = 25;
  sheet.getRange("A8:N27").format.rowHeight = 24;
  sheet.freezePanes.freezeRows(2);
  return sheet;
}

await fs.mkdir(qaDir, { recursive: true });
const sourceMapDataset = datasets.find((dataset) => dataset.name === "Source-Map");
const localSourcePaths = sourceMapDataset.rows.map((row) => row[9]).filter((location) => !location.startsWith("http"));
for (const location of localSourcePaths) await fs.access(location);
console.log(`SOURCE_PATHS_VERIFIED ${localSourcePaths.length}`);

const workbook = Workbook.create();
workbook.comments.setSelf({ displayName: "User" });
const dashboard = workbook.worksheets.add("Dashboard");
const detailMeta = [];
datasets.forEach((dataset, index) => detailMeta.push(createDetailSheet(workbook, dataset, index + 1)));
populateDashboard(workbook, dashboard);

const dashboardCheck = await workbook.inspect({
  kind: "table",
  range: "Dashboard!A1:N27",
  include: "values,formulas",
  tableMaxRows: 27,
  tableMaxCols: 14,
  maxChars: 9000,
});
console.log("DASHBOARD_INSPECT");
console.log(dashboardCheck.ndjson);

const animationCheck = await workbook.inspect({
  kind: "table",
  range: "Animations!A1:M16",
  include: "values,formulas",
  tableMaxRows: 16,
  tableMaxCols: 13,
  maxChars: 6000,
});
console.log("ANIMATION_SAMPLE_INSPECT");
console.log(animationCheck.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
  maxChars: 6000,
});
console.log("FORMULA_ERROR_SCAN");
console.log(errors.ndjson);

for (const sheetName of ["Dashboard", ...datasets.map((dataset) => dataset.name)]) {
  const preview = await workbook.render({ sheetName, autoCrop: "all", scale: 0.75, format: "png" });
  const filename = `${sheetName.toLowerCase().replace(/[^a-z0-9]+/g, "-")}.png`;
  await fs.writeFile(path.join(qaDir, filename), new Uint8Array(await preview.arrayBuffer()));
  console.log(`RENDERED ${sheetName} -> ${filename}`);
}

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(outputPath);

const exportedBytes = await fs.readFile(outputPath);
const exportedArrayBuffer = exportedBytes.buffer.slice(exportedBytes.byteOffset, exportedBytes.byteOffset + exportedBytes.byteLength);
const roundTripWorkbook = await SpreadsheetFile.importXlsx(exportedArrayBuffer);
const roundTripSheets = await roundTripWorkbook.inspect({ kind: "sheet", include: "id,name", maxChars: 3000 });
const roundTripErrors = await roundTripWorkbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "round-trip formula error scan",
  maxChars: 3000,
});
console.log("ROUND_TRIP_SHEETS");
console.log(roundTripSheets.ndjson);
console.log("ROUND_TRIP_FORMULA_ERROR_SCAN");
console.log(roundTripErrors.ndjson);
await fs.rm(`${outputPath}.inspect.ndjson`, { force: true });

console.log("WORKBOOK_CREATED");
console.log(JSON.stringify({
  outputPath,
  sheets: ["Dashboard", ...datasets.map((dataset) => dataset.name)],
  rowCounts: Object.fromEntries(datasets.map((dataset) => [dataset.name, dataset.rows.length])),
  totalChecklistRows: datasets.reduce((sum, dataset) => sum + dataset.rows.length, 0),
  qaDir,
}, null, 2));
