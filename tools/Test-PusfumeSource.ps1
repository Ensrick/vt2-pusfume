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
$mainText = Get-Content -LiteralPath $mainPath -Raw
$configText = Get-Content -LiteralPath $configPath -Raw
$backendText = Get-Content -LiteralPath $backendPath -Raw
$mainVersion = [regex]::Match($mainText, 'MOD_VERSION\s*=\s*"([^"]+)"').Groups[1].Value
$configVersion = [regex]::Match($configText, 'Prototype v([^";]+)').Groups[1].Value

Test-Condition ($mainVersion -and $mainVersion -eq $configVersion) "version" "$mainVersion"
Test-Condition ($configText -match 'visibility\s*=\s*"friends"') "Workshop visibility" "friends only"
Test-Condition ($configText -match 'published_id\s*=\s*3764954245L') "Workshop identity" "3764954245"
Test-Condition (Test-Path (Join-Path $repoRoot "pusfume\resource_packages\pusfume\pusfume.package")) `
    "resource package" "package manifest exists"

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

$trackedBundleFiles = @(git -C $repoRoot ls-files "pusfume/bundleV2/**")
Test-Condition ($trackedBundleFiles.Count -eq 0) "generated output" "bundleV2 is not tracked"

if ($failures -gt 0) {
    Write-Error "Pusfume source preflight failed with $failures error(s)."
}

Write-Host "Pusfume source preflight passed."
