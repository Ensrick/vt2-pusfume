param(
    [string]$InputBsi = ".build\compiler-fixture\pusfume_bsi_probe\units\pusfume_probe\pusfume_3p.bsi",
    [string]$TextureSource = ".build\pusfume_handoff\textures conv",
    [string]$WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\552500\3764954245",
    [switch]$HeroPreview,
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
$textureSourcePath = if ([IO.Path]::IsPathRooted($TextureSource)) {
    (Resolve-Path $TextureSource).Path
} else {
    (Resolve-Path (Join-Path $repoRoot $TextureSource)).Path
}
$inputBonesPath = [IO.Path]::ChangeExtension($inputPath, ".bones")
if (-not (Test-Path -LiteralPath $inputBonesPath -PathType Leaf)) {
    throw "The native BSI is missing its same-name animation skeleton: $inputBonesPath"
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
Copy-Item -LiteralPath $inputBonesPath -Destination (Join-Path $unitRoot "pusfume_3p.bones") -Force

$textureRoot = Join-Path $stageMod "textures\pusfume"
$materialRoot = Join-Path $stageMod "materials\pusfume"
$textureNames = @(
    "globadier_outfit_df", "globadier_outfit_nm", "globadier_outfit_s",
    "pup_ammo_box_limited_df", "pup_ammo_box_limited_nm", "pup_ammo_box_limited_s",
    "pusfume_body_new_df", "pusfume_eyenormal",
    "pusfume_whiskers_df", "pusfume_whiskers_nm", "pusfume_whiskers_s",
    "skaven_body_nm", "skaven_body_s", "skaven_eyemask",
    "stormvermin_outfit_df", "stormvermin_outfit_nm", "stormvermin_outfit_s",
    "wpn_skaven_set_df", "wpn_skaven_set_nm", "wpn_skaven_set_s"
)

function Write-NativeTexture {
    param([string]$Name)

    $source = Join-Path $textureSourcePath "$Name.png"
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required Pusfume texture is missing: $source"
    }

    Copy-Item -LiteralPath $source -Destination (Join-Path $textureRoot "$Name.png") -Force
    $srgb = if ($Name.EndsWith("_df") -or $Name -eq "pusfume_eyenormal") {
        "true"
    } else {
        "false"
    }

    @"
common = {
    input = {
        filename = "textures/pusfume/$Name"
    }
    output = {
        apply_processing = true
        category = ""
        cut_alpha_threshold = 0.5
        enable_cut_alpha_threshold = false
        format = "DXT5"
        mipmap_filter = "kaiser"
        mipmap_filter_wrap_mode = "mirror"
        mipmap_keep_original = false
        mipmap_num_largest_steps_to_discard = 0
        mipmap_num_smallest_steps_to_discard = 0
        srgb = $srgb
        streamable = true
    }
}
"@ | Set-Content -LiteralPath (Join-Path $textureRoot "$Name.texture") -Encoding utf8
}

function Write-NativeMaterial {
    param(
        [string]$Name,
        [string]$ColorMap,
        [string]$NormalMap,
        [double]$Roughness,
        [double]$Metallic = 0,
        [switch]$Emissive,
        [switch]$Opacity
    )

    $textureLines = @("    color_map = `"textures/pusfume/$ColorMap`"")
    if ($NormalMap) {
        $textureLines += "    normal_map = `"textures/pusfume/$NormalMap`""
    }
    if ($Emissive) {
        $textureLines += "    emissive_map = `"textures/pusfume/$ColorMap`""
    }

    $normalEnabled = if ($NormalMap) { 1 } else { 0 }
    $emissiveEnabled = if ($Emissive) { 1 } else { 0 }
    $emissiveIntensity = if ($Emissive) { 2.5 } else { 0 }
    $opacityEnabled = if ($Opacity) { 1 } else { 0 }
    $textureBlock = $textureLines -join "`n"

    @"
parent_material = "core/stingray_renderer/shader_import/standard"
material_contexts = {
    surface_material = ""
}
textures = {
$textureBlock
}
variables = {
    base_color = { type = "vector3" value = [ 1 1 1 ] }
    roughness = { type = "scalar" value = $Roughness }
    metallic = { type = "scalar" value = $Metallic }
    use_color_map = { type = "scalar" value = 1 }
    use_normal_map = { type = "scalar" value = $normalEnabled }
    use_roughness_map = { type = "scalar" value = 0 }
    use_metallic_map = { type = "scalar" value = 0 }
    use_ao_map = { type = "scalar" value = 0 }
    use_emissive_map = { type = "scalar" value = $emissiveEnabled }
    emissive = { type = "vector3" value = [ 1 1 1 ] }
    emissive_intensity = { type = "scalar" value = $emissiveIntensity }
    use_opacity_map = { type = "scalar" value = $opacityEnabled }
    opacity = { type = "scalar" value = 1 }
}
"@ | Set-Content -LiteralPath (Join-Path $materialRoot "$Name.material") -Encoding utf8
}

foreach ($textureName in $textureNames) {
    Write-NativeTexture $textureName
}

Write-NativeMaterial "pusfume_body" "pusfume_body_new_df" "skaven_body_nm" 0.72
Write-NativeMaterial "pusfume_eye" "pusfume_eyenormal" "" 0.35 -Emissive
Write-NativeMaterial "pusfume_metal" "wpn_skaven_set_df" "wpn_skaven_set_nm" 0.38 0.7
Write-NativeMaterial "pusfume_globadier" "globadier_outfit_df" "globadier_outfit_nm" 0.58
Write-NativeMaterial "pusfume_armor" "stormvermin_outfit_df" "stormvermin_outfit_nm" 0.48 0.35
Write-NativeMaterial "pusfume_ammo_box" "pup_ammo_box_limited_df" "pup_ammo_box_limited_nm" 0.62
Write-NativeMaterial "pusfume_whiskers" "pusfume_whiskers_df" "pusfume_whiskers_nm" 0.74 -Opacity

@'
materials = {
    p_main = "materials/pusfume/pusfume_body"
    p_eye = "materials/pusfume/pusfume_eye"
    p_metal = "materials/pusfume/pusfume_metal"
    p_glob = "materials/pusfume/pusfume_globadier"
    p_armor = "materials/pusfume/pusfume_armor"
    p_eye_g = "materials/pusfume/pusfume_eye"
    p_ammo_box_limited_a = "materials/pusfume/pusfume_ammo_box"
    p_ammo_box_limited_b = "materials/pusfume/pusfume_ammo_box"
    p_whiskers = "materials/pusfume/pusfume_whiskers"
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

$heroPreviewEnabled = if ($HeroPreview) { "true" } else { "false" }

@"
return {
    enabled = true,
    hero_preview_enabled = $heroPreviewEnabled,
    skin_name = "pusfume_skin",
    third_person_unit = "units/pusfume/pusfume_3p",
}
"@ | Set-Content -LiteralPath (Join-Path $stageMod `
    "scripts\mods\pusfume\_pusfume_native_config.lua") -Encoding utf8

@'

unit = [
    "units/pusfume/pusfume_3p"
]
'@ | Add-Content -LiteralPath (Join-Path $stageMod `
    "resource_packages\pusfume\pusfume.package") -Encoding utf8

@'

texture = [
    "textures/pusfume/*"
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
Write-Host "Native Pusfume materials passed: textures=$($textureNames.Count) materials=7"
Write-Host "Native Pusfume hero preview enabled: $($HeroPreview.IsPresent)"
