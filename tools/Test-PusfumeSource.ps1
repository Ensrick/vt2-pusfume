param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot "..\..\Vermintide-2-Source-Code")
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SourceRoot = (Resolve-Path $SourceRoot).Path
$failures = 0

function Test-Condition {
    param(
        [bool]$Condition,
        [string]$Name,
        [string]$Detail
    )

    $status = if ($Condition) { "PASS" } else { "FAIL" }
    Write-Host "[$status] $Name - $Detail"

    if (-not $Condition) {
        $script:failures++
    }
}

$mainPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\pusfume.lua"
$configPath = Join-Path $repoRoot "pusfume\itemV2.cfg"
$backendPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_backend.lua"
$registryPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_registry.lua"
$preflightPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_preflight.lua"
$assetsPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_assets.lua"
$nativePath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_native.lua"
$nativeConfigPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_native_config.lua"
$uiPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_ui.lua"
$dataPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\pusfume_data.lua"
$packagePath = Join-Path $repoRoot "pusfume\resource_packages\pusfume\pusfume.package"
$nativeUnitPackagePath = Join-Path $repoRoot "pusfume\units\pusfume\pusfume_3p.package"
$nativeBuildPath = Join-Path $repoRoot "tools\Build-NativePusfume.ps1"
$nativeMaterialTemplatePath = Join-Path $repoRoot "tools\material_templates\character_skinned.material"
$nativeCutoutTemplatePath = Join-Path $repoRoot "tools\material_templates\character_skinned_cutout.material"
$nativeExporterPath = Join-Path $repoRoot "tools\export_blender_bsi.py"
$animatedFbxToolPath = Join-Path $repoRoot "tools\prepare_animated_pusfume_fbx.py"
$idleFbxToolPath = Join-Path $repoRoot "tools\generate_idle_pusfume_fbx.py"
$changelogPath = Join-Path $repoRoot "CHANGELOG.md"
$contributingPath = Join-Path $repoRoot "CONTRIBUTING.md"
$workflowPath = Join-Path $repoRoot ".github\workflows\source-preflight.yml"
$previewPath = Join-Path $repoRoot "pusfume\textures\pusfume\pusfume_model_preview.png"
$previewTexturePath = Join-Path $repoRoot "pusfume\textures\pusfume\pusfume_model_preview.texture"
$previewMaterialPath = Join-Path $repoRoot "pusfume\materials\pusfume\pusfume_model_preview.material"
$mainText = Get-Content -LiteralPath $mainPath -Raw
$configText = Get-Content -LiteralPath $configPath -Raw
$backendText = Get-Content -LiteralPath $backendPath -Raw
$registryText = Get-Content -LiteralPath $registryPath -Raw
$preflightText = Get-Content -LiteralPath $preflightPath -Raw
$assetsText = Get-Content -LiteralPath $assetsPath -Raw
$nativeText = Get-Content -LiteralPath $nativePath -Raw
$nativeConfigText = Get-Content -LiteralPath $nativeConfigPath -Raw
$uiText = Get-Content -LiteralPath $uiPath -Raw
$dataText = Get-Content -LiteralPath $dataPath -Raw
$packageText = Get-Content -LiteralPath $packagePath -Raw
$nativeUnitPackageText = Get-Content -LiteralPath $nativeUnitPackagePath -Raw
$nativeBuildText = Get-Content -LiteralPath $nativeBuildPath -Raw
$nativeMaterialTemplateText = Get-Content -LiteralPath $nativeMaterialTemplatePath -Raw
$nativeCutoutTemplateText = Get-Content -LiteralPath $nativeCutoutTemplatePath -Raw
$nativeExporterText = Get-Content -LiteralPath $nativeExporterPath -Raw
$animatedFbxToolText = Get-Content -LiteralPath $animatedFbxToolPath -Raw
$idleFbxToolText = Get-Content -LiteralPath $idleFbxToolPath -Raw
$changelogText = Get-Content -LiteralPath $changelogPath -Raw
$contributingText = Get-Content -LiteralPath $contributingPath -Raw
$workflowText = Get-Content -LiteralPath $workflowPath -Raw
$mainVersion = [regex]::Match($mainText, 'MOD_VERSION\s*=\s*"([^"]+)"').Groups[1].Value
$configVersion = [regex]::Match($configText, 'Prototype v([^";]+)').Groups[1].Value

Test-Condition ($mainVersion -and $mainVersion -eq $configVersion) "version" "$mainVersion"
Test-Condition ($configText -match 'visibility\s*=\s*"friends"') "Workshop visibility" "friends only"
Test-Condition ($configText -match 'published_id\s*=\s*3764954245L') "Workshop identity" "3764954245"
Test-Condition ($changelogText -match '## \[Unreleased\]' -and `
    $changelogText -match '### Known Limitations' -and `
    $contributingText -match 'Update `CHANGELOG\.md`') `
    "release discipline" "changelog and contribution policy are present"
Test-Condition ($workflowText -match 'actions/setup-python@v6' -and `
    $workflowText -match 'python -m unittest discover -s tests -v') `
    "unit-test CI" "Python regression suite runs on every pull request"
Test-Condition (Test-Path (Join-Path $repoRoot "pusfume\resource_packages\pusfume\pusfume.package")) `
    "resource package" "package manifest exists"
Test-Condition ($nativeUnitPackageText -match 'unit\s*=\s*\[' -and `
    $nativeUnitPackageText -match '"units/pusfume/pusfume_3p"') `
    "native preview package" "same-path package resolves the custom unit"
Test-Condition ($mainText -match 'assets\.install\(\)') "asset bridge" "installed at runtime"
Test-Condition ($mainText -match 'native\.install\(registry, native_config\)') `
    "native cosmetic" "optional runtime integration is installed"
Test-Condition ($nativeConfigText -match 'enabled\s*=\s*false') `
    "native cosmetic" "public source defaults to the provenance-safe fallback"
Test-Condition ($nativeText -match 'PlayerUnitCosmeticExtension' -and `
    $nativeText -match '_init_mesh_attachment') `
    "native cosmetic" "player mesh attachment is career-scoped"
Test-Condition ($nativeText -match 'Unit\.has_animation_state_machine\(mesh\)' -and `
    $nativeText -match 'Unit\.has_animation_event\(mesh, "enable"\)') `
    "native animation diagnostics" "runtime log verifies controller and enable event availability"
Test-Condition ($nativeText -match 'Unit\.set_animation_bone_mode\(mesh, "transform"\)' -and `
    $nativeText -match 'Unit\.set_bones_lod\(mesh, 0\)' -and `
    $nativeText -match 'Unit\.animation_get_state\(probe\.mesh\)') `
    "native animation evaluation" "runtime enforces deforming bone output and safely logs controller state"
Test-Condition ($nativeText -notmatch 'Unit\.animation_layer_info\(') `
    "native animation diagnostics" "experimental layer indexing cannot assert in the game runtime"
Test-Condition ($nativeConfigText -match 'manual_clip_probe\s*=\s*false' -and `
    $nativeBuildText -match 'manual_clip_probe\s*=\s*false' -and `
    $nativeText -match 'Unit\.disable_animation_state_machine\(mesh\)' -and `
    $nativeText -match 'Unit\.crossfade_animation\(mesh, config\.manual_clip_name, 1, 0, true, "normal"\)' -and `
    $nativeText -match 'Unit\.crossfade_animation_set_time\(') `
    "native animation blender" "manual clip sweep remains available without overriding the deployed controller"
Test-Condition ($nativeConfigText -match 'locomotion_events_enabled\s*=\s*false' -and `
    $nativeBuildText -match 'locomotion_events_enabled\s*=\s*true' -and `
    $nativeText -match 'function drive_locomotion_events' -and `
    $nativeText -match 'Unit\.animation_event\(probe\.mesh, "walk"\)' -and `
    $nativeText -match 'Unit\.animation_event\(probe\.mesh, "idle"\)' -and `
    $nativeText -match 'function M\.animation_status' -and `
    $preflightText -match 'add\(checks, "locomotion animation events"' -and `
    $nativeBuildText -match 'default_state = "base/idle"' -and `
    $nativeBuildText -match '"units/pusfume/anims/pusfume_3p_idle"' -and `
    $nativeBuildText -match 'generate_idle_pusfume_fbx\.py' -and `
    (Test-Path (Join-Path $repoRoot "tools\generate_idle_pusfume_fbx.py"))) `
    "state-driven locomotion" "staged controller plays idle by default and Lua drives idle/walk from player speed"
Test-Condition ($nativeText -match 'articulation source_delta=' -and `
    $nativeText -match 'initial_target_articulation') `
    "native animation diagnostics" "runtime probe distinguishes skeletal articulation from unit translation"
Test-Condition ($nativeConfigText -match 'root_animation_isolation\s*=\s*false' -and `
    $nativeBuildText -match 'root_animation_isolation\s*=\s*true') `
    "native animation isolation" "local native builds use a reversible root-only attachment test"
Test-Condition ($nativeConfigText -match 'manual_skin_probe\s*=\s*false' -and `
    $nativeBuildText -match 'manual_skin_probe\s*=\s*false' -and `
    $nativeText -match 'Unit\.set_local_rotation\(probe\.mesh, probe\.manual_node, rotation\)' -and `
    $nativeText -match 'Unit\.disable_animation_state_machine\(mesh\)') `
    "native skin diagnostics" "manual joint rotation remains available without disabling deployed controller playback"
Test-Condition ($nativeBuildText -match '\[switch\]\$NoDeploy' -and `
    $nativeBuildText -match 'if \(-not \$NoDeploy\)') `
    "local deployment" "native builds deploy to the active Workshop item by default"
Test-Condition ($nativeBuildText -match '\$staleBundles' -and `
    $nativeBuildText -match 'Remove-Item -LiteralPath \$staleBundle\.FullName') `
    "local deployment" "obsolete Workshop bundles are removed inside the verified item directory"
Test-Condition ($nativeBuildText -match '\[switch\]\$UseBsiSkinFallback' -and `
    $nativeBuildText -match '\$useFbxDcc\s*=\s*-not \$UseBsiSkinFallback\.IsPresent' -and `
    $nativeBuildText -match 'pusfume_3p\.dcc_asset' -and `
    $nativeBuildText -match 'extension\s*=\s*"\.fbx"') `
    "native FBX pipeline" "supported Stingray DCC import is default and BSI remains an explicit fallback"
Test-Condition ($nativeBuildText -match 'prepare_animated_pusfume_fbx\.py' -and `
    $nativeBuildText -match '\$modelFbxPath \$animationFbxPath \$animatedModelFbxPath' -and `
    $nativeBuildText -match 'Copy-Item -LiteralPath \$animatedModelFbxPath' -and `
    $animatedFbxToolText -match 'model_armature\.animation_data\.action_slot = action\.slots\[0\]' -and `
    $animatedFbxToolText -match 'max_pose_delta < 0\.001' -and `
    $animatedFbxToolText -match 'max_vertex_delta < 0\.001') `
    "native animated FBX" "DCC import receives one verified deforming character FBX"
Test-Condition ($nativeExporterText -match 'build_skin_activation_animations' -and `
    $nativeExporterText -match 'for bone in armature\.data\.bones' -and `
    $nativeExporterText -match 'document\["animations"\]\s*=\s*activation_animations' -and `
    $nativeExporterText -match 'write_animation_bones') `
    "native animation" "skinned BSI preserves a rest-pose channel for the complete scene graph"
Test-Condition ($nativeBuildText -match 'ChangeExtension\(\$inputPath, "\.bones"\)' -and `
    $nativeBuildText -match 'pusfume_3p\.bones') `
    "native animation" "same-name animation skeleton is required by the native build"
Test-Condition ($nativeBuildText -match '\[string\]\$AnimationFbx' -and `
    $nativeBuildText -match 'pusfume_3p_walk\.animation' -and `
    $nativeBuildText -match 'pusfume_3p_idle\.animation' -and `
    $nativeBuildText -match 'animation_state_machine\s*=\s*"units/pusfume/pusfume_3p"' -and `
    $nativeBuildText -match 'name = "base/walk"') `
    "native animation" "Janfon's baked walk FBX is packaged as a controller state beside the generated idle"
Test-Condition ($nativeBuildText -match 'state_machine\s*=\s*\[' -and `
    $nativeBuildText -match 'animation\s*=\s*\[' -and `
    $nativeBuildText -match 'bones\s*=\s*\[') `
    "native animation package" "controller, clip, and skeleton are explicit package resources"
Test-Condition ($nativeBuildText -match 'Write-NativeTexture' -and `
    $nativeBuildText -match 'p_main\s*=\s*"materials/pusfume/pusfume_body"' -and `
    $nativeBuildText -notmatch 'p_main\s*=\s*"materials/pusfume/pusfume_debug_3p"') `
    "native materials" "staged build uses handoff textures instead of the green diagnostic material"
Test-Condition ($nativeMaterialTemplateText -match 'shader\s*=\s*\{' -and `
    $nativeCutoutTemplateText -match 'shader\s*=\s*\{' -and `
    $nativeCutoutTemplateText -match 'core/stingray_renderer/output_nodes/standard_base' -and `
    $nativeConfigText -match 'donor_material_enabled\s*=\s*false' -and `
    $nativeBuildText -match 'donor_material_enabled\s*=\s*true' -and `
    $nativeText -match 'Unit\.set_material\(unit, slot_name, config\.donor_material\)' -and `
    $nativeText -match 'Material\.set_texture\(material, channel, texture_path\)' -and `
    $nativeText -match 'Application\.can_get\(resource_type, path\)' -and `
    $nativeText -match 'Managers\.package:unload\(config\.donor_package, DONOR_PACKAGE_REFERENCE\)' -and `
    $nativeBuildText -match 'character_skinned_cutout\.material') `
    "native material skinning" "local builds use a guarded, releasable Globadier donor while public source stays off"
Test-Condition ($nativeText -match 'Material\.set_texture\(material, channel, texture_path\)' -and `
    $nativeText -match 'Mesh\.num_materials\(mesh\)' -and `
    $nativeText -match 'Mesh\.material\(mesh, material_index\)' -and `
    $nativeText -notmatch 'Unit\.set_texture_for_materials\(' -and `
    $nativeText -match 'pusfume_atlas_df' -and `
    $nativeBuildText -match 'Write-PusfumeAtlas "pusfume_atlas_df"' -and `
    $nativeBuildText -match 'Write-NativeMaterial "pusfume_body" "pusfume_atlas_df" "pusfume_atlas_nm" "pusfume_atlas_s"' -and `
    $animatedFbxToolText -match 'remap_material_uvs_to_atlas' -and `
    $animatedFbxToolText -match 'shift_u = int\(anchor\.x // 1\)') `
    "per-mesh donor atlas" "atlas channels are set on every material by index so swapped donor instances are reached"
Test-Condition ($nativeText -match 'function M\.native_skin_name' -and `
    $nativeText -notmatch 'third_person_attachment = nil' -and `
    $uiText -match 'MenuWorldPreviewer, "request_spawn_hero_unit"' -and `
    $uiText -match 'MenuWorldPreviewer, "_update_units_visibility"' -and `
    $uiText -match 'MenuWorldPreviewer, "_spawn_hero_unit"' -and `
    $uiText -match 'optional_skin = native_skin' -and `
    $uiText -match 'Unit\.enable_animation_state_machine\(mesh_unit\)') `
    "menu preview purity" "menu previewers force the native skin, hide donor weapons, and start the mesh controller"
Test-Condition ($nativeConfigText -match 'parent_child_material\s*=\s*false' -and `
    $nativeBuildText -match 'parent_child_material\s*=\s*"materials/pusfume/pusfume_outfit_child"' -and `
    $nativeBuildText -match 'pusfume_outfit_child\.material' -and `
    $nativeBuildText -match 'parent_material = "units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/mtr_outfit"' -and `
    $nativeText -match 'config\.parent_child_material' -and `
    $nativeText -match 'Unit\.set_material\(unit, slot_name, config\.parent_child_material\)') `
    "parent-child material" "staged builds inherit the donor character shader with atlas maps baked at compile time"
Test-Condition ($nativeConfigText -match 'hide_donor_weapons\s*=\s*false' -and `
    $nativeBuildText -match 'hide_donor_weapons\s*=\s*true' -and `
    $nativeText -match 'function hide_donor_weapons' -and `
    $nativeText -match 'Unit\.set_unit_visibility\(weapon_unit, false\)' -and `
    $nativeText -match 'right_hand_wielded_unit_3p') `
    "donor weapon hiding" "staged builds hide Bardin's third-person weapon units every update"
Test-Condition ($idleFbxToolText -match 'j_tail1' -and `
    $idleFbxToolText -match 'BONE_MOTIONS' -and `
    $idleFbxToolText -match 'max_pose_delta < 0\.02') `
    "idle visibility" "generated idle animates spine, head, and tail with a rejected-if-imperceptible floor"
Test-Condition ($nativeText -match 'function M\.donor_status' -and `
    $nativeText -match 'installed_config = config' -and `
    $preflightText -match 'native\.donor_status\(\)' -and `
    $preflightText -match 'add\(checks, "donor material content"') `
    "donor content preflight" "preflight fails before a live test when donor game content cannot resolve"
Test-Condition ($uiText -match 'native\.preview_enabled\(\)' -and `
    $nativeBuildText -match '\[switch\]\$HeroPreview' -and `
    $nativeBuildText -match 'hero_preview_enabled\s*=\s*\$heroPreviewEnabled') `
    "selector preview" "native 3D preview is enabled only by an explicit test-build switch"
Test-Condition ($nativeText -match 'retrieve_skin_packages_for_preview' -and `
    $nativeText -match 'package_name ~= config\.third_person_unit') `
    "selector preview" "startup-resident custom unit bypasses redundant package loading"
Test-Condition ($uiText -match 'CharacterSelectionStateCharacter') `
    "five-row career grid" "character selection state is hooked"
Test-Condition ($uiText -match 'UIWidgets\.create_hero_widget') `
    "five-row career grid" "full-size overflow career widget is created"
Test-Condition ($uiText -match 'LEGACY_OVERFLOW_Y\s*=\s*144') `
    "five-row career grid" "Pusfume card occupies the row above Saltzpyre"
Test-Condition ($uiText -match 'mod:hook\(CharacterSelectionStateCharacter, "_spawn_hero_unit"') `
    "selector preview" "Pusfume donor menu spawn is intercepted"
Test-Condition ($uiText -match 'world_previewer:clear_units\(\)' -and `
    $uiText -match 'world_previewer:hide_character\(\)') `
    "selector preview" "existing donor unit is cleared and hidden"
Test-Condition ($uiText -match '_requested_hero_spawn_data\s*=\s*nil' -and `
    $uiText -match 'world_previewer:_unload_all_packages\(\)') `
    "selector preview" "queued donor spawn and package loading are cancelled"
Test-Condition (Test-Path -LiteralPath $previewPath) "selector preview asset" "PNG exists"
Test-Condition (Test-Path -LiteralPath $previewTexturePath) "selector preview asset" "texture recipe exists"
Test-Condition (Test-Path -LiteralPath $previewMaterialPath) "selector preview asset" "GUI material exists"
Test-Condition ($dataText -match '"pusfume_model_preview"' -and `
    $dataText -match '"ingame_ui_settings"') `
    "selector preview registration" "texture and active UI renderer are registered"
Test-Condition ($packageText -match 'material\s*=\s*\[' -and `
    $packageText -match '"materials/pusfume/\*"') `
    "selector preview package" "custom material is included"
Test-Condition ($mainText -match 'registry\.refresh_item_permissions\(\)') `
    "item permissions" "late-loaded items are refreshed"
Test-Condition ($registryText -match 'function M\.refresh_career_color\(\)' -and `
    $registryText -match 'color_definitions\[M\.CAREER_NAME\]\s*=\s*deep_clone\(donor_color\)') `
    "career color" "Pusfume owns a distinct donor-derived color table"
Test-Condition ($mainText -match 'registry\.refresh_career_color\(\)') `
    "career color" "registration is refreshed across game-state changes"
Test-Condition ($preflightText -match 'add\(checks, "career color"') `
    "career color" "runtime preflight validates the player-list contract"
Test-Condition ($backendText -match 'mod:hook\(BackendUtils, "get_loadout_item"') `
    "spawn guard" "BackendUtils item resolution is donor-aliased"
Test-Condition ($backendText -match 'function expose_donor_loadout' -and `
    $backendText -match 'donor_loadout = \{\}') `
    "loadout UI guard" "direct loadout table always exposes an iterable Pusfume entry"
Test-Condition ($backendText -match 'function M\.refresh_runtime_aliases' -and `
    $backendText -match 'store\[registry\.CAREER_NAME\] = store\[registry\.DONOR_CAREER_NAME\]') `
    "loadout UI guard" "backend stores retain the alias across later instance hooks"
Test-Condition ($preflightText -match 'direct_loadouts.*item_interface:get_loadout\(\)' -and `
    $preflightText -match 'type\(direct_loadout\) == "table"') `
    "loadout UI guard" "preflight exercises the exact vanilla tooltip table API"
Test-Condition ($uiText -match 'request_spawn_hero_unit\(hero_name,' -and `
    $uiText -match 'window\._selected_career_index, true, spawn_callback') `
    "native selector preview" "Pusfume forces its base skin instead of the equipped Ranger skin"
Test-Condition ($backendText -match 'unresolved.*slot_melee.*slot_ranged' -or `
    ($backendText -match 'slot_melee' -and $backendText -match 'slot_ranged')) `
    "spawn guard" "both default weapon slots are validated"

$bridgeSection = [regex]::Match(
    $assetsText,
    '(?s)M\.third_person_attachment\s*=\s*\{(.*?)\n\}').Groups[1].Value
$bridgeSources = @([regex]::Matches($bridgeSection, 'source\s*=\s*"([^"]+)"') | ForEach-Object {
    $_.Groups[1].Value
})
$bridgeTargets = @([regex]::Matches($bridgeSection, 'target\s*=\s*"([^"]+)"') | ForEach-Object {
    $_.Groups[1].Value
})
$bridgeUsesSceneRoot = $bridgeSection -match `
    'source\s*=\s*"root_point"\s*,\s*target\s*=\s*0'
$duplicateBridgeTargets = @($bridgeTargets | Group-Object | Where-Object Count -gt 1)
$officialLinkPath = Join-Path $SourceRoot "scripts\settings\attachment_node_linking.lua"
$officialLinkText = Get-Content -LiteralPath $officialLinkPath -Raw
$bardinMarker = 'third_person_attachment = {'
$bardinStart = $officialLinkText.IndexOf($bardinMarker)
$bardinTail = $officialLinkText.Substring($bardinStart)
$bardinEnd = $bardinTail.IndexOf('kerillian = {')
$bardinSection = $bardinTail.Substring(0, $bardinEnd)
$bardinNodes = @([regex]::Matches($bardinSection, 'source\s*=\s*"([^"]+)"') | ForEach-Object {
    $_.Groups[1].Value
})
$missingParentNodes = @($bridgeSources | Where-Object { $_ -notin $bardinNodes })

Test-Condition ($bridgeSources.Count -eq 52 -and $bridgeTargets.Count -eq 51 -and `
    $bridgeUsesSceneRoot) `
    "asset bridge" "$($bridgeSources.Count) parent-to-child links"
Test-Condition ($assetsText -match 'pusfume_root_animation_attachment' -and `
    $assetsText -match 'M\.root_animation_attachment' -and `
    $assetsText -match '(?s)M\.root_animation_attachment\s*=\s*\{.*?target\s*=\s*0') `
    "asset bridge" "root-only animation isolation links the complete DCC scene"
Test-Condition ($duplicateBridgeTargets.Count -eq 0) "asset bridge" "child targets are unique"
Test-Condition ($missingParentNodes.Count -eq 0) "asset bridge" "all parent nodes exist on Bardin"

$playerListPath = Join-Path $SourceRoot "scripts\ui\views\ingame_player_list_ui_v2.lua"
$playerListText = Get-Content -LiteralPath $playerListPath -Raw
$colorsPath = Join-Path $SourceRoot "scripts\utils\colors.lua"
$colorsText = Get-Content -LiteralPath $colorsPath -Raw

Test-Condition ($playerListText -match 'Colors\.color_definitions\[career_name\]') `
    "career color API" "vanilla player list directly indexes the career color"
Test-Condition ($colorsText -match '(?s)dr_ranger\s*=\s*\{\s*255\s*,\s*187\s*,\s*235\s*,\s*30') `
    "career color API" "Ranger Veteran donor color exists"

$hookSets = @{
    BackendInterfaceItemPlayfab = @(
        "get_loadout", "get_bot_loadout", "set_loadout_index", "add_loadout", "delete_loadout",
        "set_default_override", "get_default_override", "get_career_loadouts",
        "get_selected_career_loadout", "get_default_loadouts", "get_loadout_by_career_name",
        "get_loadout_item_id", "get_cosmetic_loadout", "set_loadout_item"
    )
    BackendInterfaceTalentsPlayfab = @(
        "set_default_override", "get_talent_ids", "get_talent_tree", "set_talents", "get_talents",
        "get_bot_talents", "get_default_talents", "get_career_talents", "get_career_talent_ids"
    )
}

$sourceFiles = @{
    BackendInterfaceItemPlayfab = Join-Path $SourceRoot "scripts\managers\backend_playfab\backend_interface_item_playfab.lua"
    BackendInterfaceTalentsPlayfab = Join-Path $SourceRoot "scripts\managers\backend_playfab\backend_interface_talents_playfab.lua"
}

foreach ($className in $hookSets.Keys) {
    $sourceText = Get-Content -LiteralPath $sourceFiles[$className] -Raw

    foreach ($methodName in $hookSets[$className]) {
        $definition = "$className.$methodName = function"
        Test-Condition ($sourceText.Contains($definition)) "backend API" $definition
    }
}

$declaredHookCount = [int][regex]::Match($backendText, 'expected_hook_count\s*=\s*(\d+)').Groups[1].Value
$actualHookCount = ($hookSets.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
Test-Condition ($declaredHookCount -eq $actualHookCount) "hook accounting" "$declaredHookCount methods"

$declaredGuardCount = [int][regex]::Match($backendText, 'expected_runtime_guard_count\s*=\s*(\d+)').Groups[1].Value
$actualGuardCount = [regex]::Matches($backendText, 'mod:hook\(BackendUtils,').Count
Test-Condition ($declaredGuardCount -eq $actualGuardCount) `
    "runtime guard accounting" "$declaredGuardCount BackendUtils methods"

$trackedBundleFiles = @(git -C $repoRoot ls-files "pusfume/bundleV2/**")
Test-Condition ($trackedBundleFiles.Count -eq 0) "generated output" "bundleV2 is not tracked"

if ($failures -gt 0) {
    Write-Error "Pusfume source preflight failed with $failures error(s)."
}

Write-Host "Pusfume source preflight passed."
