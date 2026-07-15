param(
    [string]$InputBsi = ".build\compiler-fixture\pusfume_bsi_probe\units\pusfume_probe\pusfume_3p.bsi",
    [string]$WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\552500\3764954245",
    [switch]$NoDeploy
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourceMod = Join-Path $repoRoot "pusfume"
$inputPath = if ([IO.Path]::IsPathRooted($InputBsi)) {
    (Resolve-Path $InputBsi).Path
} else {
    (Resolve-Path (Join-Path $repoRoot $InputBsi)).Path
}
$stageRoot = Join-Path $repoRoot ".build\native-workshop"
$stageMod = Join-Path $stageRoot "pusfume"
$vmbPath = (Resolve-Path (Join-Path $repoRoot "..\vmb\vmb.js")).Path

$resolvedStageRoot = [IO.Path]::GetFullPath($stageRoot)
$allowedBuildRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot ".build")) + [IO.Path]::DirectorySeparatorChar
if (-not ($resolvedStageRoot + [IO.Path]::DirectorySeparatorChar).StartsWith(
        $allowedBuildRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to stage outside the repository build directory: $resolvedStageRoot"
}

if ((Get-Item -LiteralPath $inputPath).Length -lt 1024) {
    throw "The BSI payload is unexpectedly small: $inputPath"
}

if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $stageRoot | Out-Null
Copy-Item -LiteralPath $sourceMod -Destination $stageRoot -Recurse -Force

$staleBundlePath = Join-Path $stageMod "bundleV2"
if (Test-Path -LiteralPath $staleBundlePath) {
    Remove-Item -LiteralPath $staleBundlePath -Recurse -Force
}

$unitRoot = Join-Path $stageMod "units\pusfume"
New-Item -ItemType Directory -Path $unitRoot -Force | Out-Null
Copy-Item -LiteralPath $inputPath -Destination (Join-Path $unitRoot "pusfume_3p.bsi") -Force

@'
materials = {
    p_main = "materials/pusfume/pusfume_debug_3p"
    p_eye = "materials/pusfume/pusfume_debug_3p"
    p_metal = "materials/pusfume/pusfume_debug_3p"
    p_glob = "materials/pusfume/pusfume_debug_3p"
    p_armor = "materials/pusfume/pusfume_debug_3p"
    p_eye_g = "materials/pusfume/pusfume_debug_3p"
    p_ammo_box_limited_a = "materials/pusfume/pusfume_debug_3p"
    p_ammo_box_limited_b = "materials/pusfume/pusfume_debug_3p"
    p_whiskers = "materials/pusfume/pusfume_debug_3p"
}
renderables = {
    p_mainbody = {
        always_keep = false
        culling = "bounding_volume"
        generate_uv_unwrap = false
        occluder = false
        shadow_caster = true
        surface_queries = false
        viewport_visible = true
    }
}
'@ | Set-Content -LiteralPath (Join-Path $unitRoot "pusfume_3p.unit") -Encoding utf8

@'
return {
    enabled = true,
    hero_preview_enabled = false,
    skin_name = "pusfume_skin",
    third_person_unit = "units/pusfume/pusfume_3p",
}
'@ | Set-Content -LiteralPath (Join-Path $stageMod `
    "scripts\mods\pusfume\_pusfume_native_config.lua") -Encoding utf8

@'

unit = [
    "units/pusfume/pusfume_3p"
]
'@ | Add-Content -LiteralPath (Join-Path $stageMod `
    "resource_packages\pusfume\pusfume.package") -Encoding utf8

& node $vmbPath build pusfume -f $stageRoot --rc $repoRoot --clean --no-workshop
if ($LASTEXITCODE -ne 0) {
    throw "VT2 SDK native build failed with exit code $LASTEXITCODE"
}

$bundleRoot = Join-Path $stageMod "bundleV2"
$modFile = Join-Path $bundleRoot "pusfume.mod"
if (-not (Test-Path -LiteralPath $modFile -PathType Leaf)) {
    throw "SDK reported success but did not produce $modFile"
}

if (-not $NoDeploy) {
    $resolvedWorkshop = [IO.Path]::GetFullPath($WorkshopPath)
    if (-not $resolvedWorkshop.EndsWith("552500\3764954245", [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to deploy outside the Pusfume Workshop item: $resolvedWorkshop"
    }

    New-Item -ItemType Directory -Path $resolvedWorkshop -Force | Out-Null
    $verifiedFiles = 0

    Get-ChildItem -LiteralPath $bundleRoot -File | ForEach-Object {
        $deployedPath = Join-Path $resolvedWorkshop $_.Name

        Copy-Item -LiteralPath $_.FullName -Destination $deployedPath -Force

        $sourceHash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        $deployedHash = (Get-FileHash -LiteralPath $deployedPath -Algorithm SHA256).Hash
        if ($sourceHash -ne $deployedHash) {
            throw "Deployment hash mismatch: $deployedPath"
        }

        $verifiedFiles++
    }

    Write-Host "Deployed and hash-verified $verifiedFiles native Pusfume files to $resolvedWorkshop"
}

$bsiSize = (Get-Item -LiteralPath $inputPath).Length
$bundles = @(Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)
Write-Host "Native Pusfume build passed: BSI=$bsiSize bytes bundles=$($bundles.Count)"
