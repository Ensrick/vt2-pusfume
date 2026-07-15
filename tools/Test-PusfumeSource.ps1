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
$nativeBuildPath = Join-Path $repoRoot "tools\Build-NativePusfume.ps1"
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
$nativeBuildText = Get-Content -LiteralPath $nativeBuildPath -Raw
$mainVersion = [regex]::Match($mainText, 'MOD_VERSION\s*=\s*"([^"]+)"').Groups[1].Value
$configVersion = [regex]::Match($configText, 'Prototype v([^";]+)').Groups[1].Value

Test-Condition ($mainVersion -and $mainVersion -eq $configVersion) "version" "$mainVersion"
Test-Condition ($configText -match 'visibility\s*=\s*"friends"') "Workshop visibility" "friends only"
Test-Condition ($configText -match 'published_id\s*=\s*3764954245L') "Workshop identity" "3764954245"
Test-Condition (Test-Path (Join-Path $repoRoot "pusfume\resource_packages\pusfume\pusfume.package")) `
    "resource package" "package manifest exists"
Test-Condition ($mainText -match 'assets\.install\(\)') "asset bridge" "installed at runtime"
Test-Condition ($mainText -match 'native\.install\(registry, native_config\)') `
    "native cosmetic" "optional runtime integration is installed"
Test-Condition ($nativeConfigText -match 'enabled\s*=\s*false') `
    "native cosmetic" "public source defaults to the provenance-safe fallback"
Test-Condition ($nativeText -match 'PlayerUnitCosmeticExtension' -and `
    $nativeText -match '_init_mesh_attachment') `
    "native cosmetic" "player mesh attachment is career-scoped"
Test-Condition ($nativeBuildText -match '\[switch\]\$NoDeploy' -and `
    $nativeBuildText -match 'if \(-not \$NoDeploy\)') `
    "local deployment" "native builds deploy to the active Workshop item by default"
Test-Condition ($uiText -match 'native\.enabled\(\)') `
    "selector preview" "native builds retain VT2's stock 3D preview flow"
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

$bridgeSources = @([regex]::Matches($assetsText, 'source\s*=\s*"([^"]+)"') | ForEach-Object {
    $_.Groups[1].Value
})
$bridgeTargets = @([regex]::Matches($assetsText, 'target\s*=\s*"([^"]+)"') | ForEach-Object {
    $_.Groups[1].Value
})
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

Test-Condition ($bridgeSources.Count -eq 52 -and $bridgeTargets.Count -eq 52) `
    "asset bridge" "$($bridgeSources.Count) parent-to-child links"
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
