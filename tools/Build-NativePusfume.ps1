param(
    [string]$InputBsi = ".build\compiler-fixture\pusfume_bsi_probe\units\pusfume_probe\pusfume_3p.bsi",
    [string]$ModelFbx = ".build\pusfume_handoff\pusfume_3p.fbx",
    [string]$AnimationFbx = ".build\pusfume_handoff\pusfume_3p_walk.fbx",
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    [string]$TextureSource = ".build\pusfume_handoff\textures conv",
    [string]$WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\552500\3764954245",
    [switch]$HeroPreview,
    [switch]$UseBsiSkinFallback,
    [switch]$NoDeploy
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourceMod = Join-Path $repoRoot "pusfume"
$useFbxDcc = -not $UseBsiSkinFallback.IsPresent
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
$modelFbxPath = if ([IO.Path]::IsPathRooted($ModelFbx)) {
    (Resolve-Path $ModelFbx).Path
} else {
    (Resolve-Path (Join-Path $repoRoot $ModelFbx)).Path
}
if ($useFbxDcc -and (Get-Item -LiteralPath $modelFbxPath).Length -lt 1024) {
    throw "The native model FBX is unexpectedly small: $modelFbxPath"
}
$animationFbxPath = if ([IO.Path]::IsPathRooted($AnimationFbx)) {
    (Resolve-Path $AnimationFbx).Path
} else {
    (Resolve-Path (Join-Path $repoRoot $AnimationFbx)).Path
}
if ((Get-Item -LiteralPath $animationFbxPath).Length -lt 1024) {
    throw "The native animation FBX is unexpectedly small: $animationFbxPath"
}
$animatedModelFbxPath = $modelFbxPath
if ($useFbxDcc) {
    $blenderExePath = (Resolve-Path $BlenderExe).Path
    $animatedFbxTool = Join-Path $repoRoot "tools\prepare_animated_pusfume_fbx.py"
    $generatedRoot = Join-Path $repoRoot ".build\generated-native"
    $animatedModelFbxPath = Join-Path $generatedRoot "pusfume_3p_animated.fbx"
    New-Item -ItemType Directory -Path $generatedRoot -Force | Out-Null

    & $blenderExePath --background --factory-startup --disable-autoexec `
        --python $animatedFbxTool -- `
        $modelFbxPath $animationFbxPath $animatedModelFbxPath
    if ($LASTEXITCODE -ne 0) {
        throw "Animated Pusfume FBX preparation failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $animatedModelFbxPath -PathType Leaf) -or `
            (Get-Item -LiteralPath $animatedModelFbxPath).Length -lt 1024) {
        throw "Animated Pusfume FBX preparation produced no usable output"
    }
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
$animationRoot = Join-Path $unitRoot "anims"
New-Item -ItemType Directory -Path $unitRoot -Force | Out-Null
New-Item -ItemType Directory -Path $animationRoot -Force | Out-Null
if ($useFbxDcc) {
    Copy-Item -LiteralPath $animatedModelFbxPath `
        -Destination (Join-Path $unitRoot "pusfume_3p.fbx") -Force
    @'
_data_root_version = 1
_id = "0fb82f3d-675b-45bf-923e-b9ba33550f64"
_name = "units/pusfume/pusfume_3p"
asset = "units/pusfume/pusfume_3p"
extension = ".fbx"
'@ | Set-Content -LiteralPath (Join-Path $unitRoot "pusfume_3p.dcc_asset") -Encoding utf8
} else {
    Copy-Item -LiteralPath $inputPath -Destination (Join-Path $unitRoot "pusfume_3p.bsi") -Force
}
Copy-Item -LiteralPath $inputBonesPath -Destination (Join-Path $unitRoot "pusfume_3p.bones") -Force
Copy-Item -LiteralPath $animationFbxPath `
    -Destination (Join-Path $animationRoot "pusfume_3p_walk.fbx") -Force

@'
bones = "units/pusfume/pusfume_3p"
tolerance = {
    "" = [
        0.01
        0.01
        0
        false
    ]
}
'@ | Set-Content -LiteralPath (Join-Path $animationRoot "pusfume_3p_walk.animation") -Encoding utf8

@'
events = {
    enable = {}
}
layers = [
    {
        default_state = "base/walk"
        states = [
            {
                animations = [
                    "units/pusfume/anims/pusfume_3p_walk"
                ]
                loop_animation = true
                name = "base/walk"
                randomization_type = "every_loop"
                root_driving = "ignore"
                speed = "1"
                state_type = "regular"
                transitions = []
                weights = [
                    "1.0"
                ]
            }
        ]
    }
]
ragdolls = {}
variables = {}
bones = "units/pusfume/pusfume_3p"
'@ | Set-Content -LiteralPath (Join-Path $unitRoot "pusfume_3p.state_machine") -Encoding utf8

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
        [string]$DetailMap,
        [double]$Roughness,
        [double]$Metallic = 0,
        [switch]$Emissive,
        [switch]$Opacity
    )

    $normalEnabled = if ($NormalMap) { 1 } else { 0 }
    $emissiveIntensity = if ($Emissive) { 2.5 } else { 0 }
    $normalTexture = if ($NormalMap) { $NormalMap } else { $ColorMap }
    $detailTexture = if ($DetailMap) { $DetailMap } else { $ColorMap }
    $templateName = if ($Opacity) {
        "character_skinned_cutout.material"
    } else {
        "character_skinned.material"
    }
    $templatePath = Join-Path $repoRoot "tools\material_templates\$templateName"
    $materialText = Get-Content -LiteralPath $templatePath -Raw
    if ($materialText -match 'parent_material\s*=\s*"core/stingray_renderer/shader_import/standard"') {
        throw "The Pusfume character material template regressed to the static standard parent"
    }
    foreach ($token in @("__COLOR_MAP__", "__NORMAL_MAP__", "__DETAIL_MAP__")) {
        if (-not $materialText.Contains($token)) {
            throw "The Pusfume character material template is missing $token"
        }
    }

    $materialText = $materialText.Replace("__COLOR_MAP__", "textures/pusfume/$ColorMap")
    $materialText = $materialText.Replace("__NORMAL_MAP__", "textures/pusfume/$normalTexture")
    $materialText = $materialText.Replace("__DETAIL_MAP__", "textures/pusfume/$detailTexture")
    $materialText = $materialText.Replace(
        'use_normal_map = { type = "scalar" value = 1 }',
        "use_normal_map = { type = `"scalar`" value = $normalEnabled }"
    )
    $materialText = $materialText.Replace(
        'use_roughness_map = { type = "scalar" value = 1 }',
        'use_roughness_map = { type = "scalar" value = 0 }'
    )
    $materialText = $materialText.Replace(
        'use_metallic_map = { type = "scalar" value = 1 }',
        'use_metallic_map = { type = "scalar" value = 0 }'
    )
    $materialText = $materialText.Replace(
        'use_ao_map = { type = "scalar" value = 1 }',
        'use_ao_map = { type = "scalar" value = 0 }'
    )
    $materialText = $materialText.Replace(
        'emissive_intensity = { type = "scalar" value = 0 }',
        "emissive_intensity = { type = `"scalar`" value = $emissiveIntensity }`n" +
        "`troughness = { type = `"scalar`" value = $Roughness }`n" +
        "`tmetallic = { type = `"scalar`" value = $Metallic }"
    )

    Set-Content -LiteralPath (Join-Path $materialRoot "$Name.material") `
        -Value $materialText -Encoding utf8
}

foreach ($textureName in $textureNames) {
    Write-NativeTexture $textureName
}

Write-NativeMaterial "pusfume_body" "pusfume_body_new_df" "skaven_body_nm" "skaven_body_s" 0.72
Write-NativeMaterial "pusfume_eye" "pusfume_eyenormal" "" "pusfume_eyenormal" 0.35 -Emissive
Write-NativeMaterial "pusfume_metal" "wpn_skaven_set_df" "wpn_skaven_set_nm" "wpn_skaven_set_s" 0.38 0.7
Write-NativeMaterial "pusfume_globadier" "globadier_outfit_df" "globadier_outfit_nm" "globadier_outfit_s" 0.58
Write-NativeMaterial "pusfume_armor" "stormvermin_outfit_df" "stormvermin_outfit_nm" "stormvermin_outfit_s" 0.48 0.35
Write-NativeMaterial "pusfume_ammo_box" "pup_ammo_box_limited_df" "pup_ammo_box_limited_nm" "pup_ammo_box_limited_s" 0.62
Write-NativeMaterial "pusfume_whiskers" "pusfume_whiskers_df" "pusfume_whiskers_nm" "pusfume_whiskers_s" 0.74 -Opacity

@'
animation_state_machine = "units/pusfume/pusfume_3p"
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
    donor_material_enabled = true,
    donor_material = "units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/mtr_outfit",
    donor_package = "units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/chr_third_person_mesh",
    enabled = true,
    hero_preview_enabled = $heroPreviewEnabled,
    manual_clip_length = 0.8,
    manual_clip_name = "units/pusfume/anims/pusfume_3p_walk",
    manual_clip_probe = true,
    manual_skin_probe = false,
    root_animation_isolation = true,
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

state_machine = [
    "units/pusfume/pusfume_3p"
]

bones = [
    "units/pusfume/pusfume_3p"
]

animation = [
    "units/pusfume/anims/pusfume_3p_walk"
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
    $bundleFiles = @(Get-ChildItem -LiteralPath $bundleRoot -File)
    $expectedNames = @{}

    foreach ($bundleFile in $bundleFiles) {
        $expectedNames[$bundleFile.Name] = $true
    }

    $staleBundles = @(Get-ChildItem -LiteralPath $resolvedWorkshop -Filter *.mod_bundle -File |
        Where-Object { -not $expectedNames.ContainsKey($_.Name) })

    foreach ($staleBundle in $staleBundles) {
        if ([IO.Path]::GetDirectoryName($staleBundle.FullName) -ne $resolvedWorkshop) {
            throw "Refusing to remove a stale bundle outside the Workshop item: $($staleBundle.FullName)"
        }

        Remove-Item -LiteralPath $staleBundle.FullName -Force
    }

    $verifiedFiles = 0

    $bundleFiles | ForEach-Object {
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
    Write-Host "Removed $($staleBundles.Count) obsolete native Pusfume bundles"
}

$nativeSource = if ($useFbxDcc) { $animatedModelFbxPath } else { $inputPath }
$nativeSourceKind = if ($useFbxDcc) { "FBX/DCC" } else { "BSI fallback" }
$nativeSourceSize = (Get-Item -LiteralPath $nativeSource).Length
$bundles = @(Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)
Write-Host "Native Pusfume build passed: source=$nativeSourceKind bytes=$nativeSourceSize bundles=$($bundles.Count)"
Write-Host "Native Pusfume materials passed: textures=$($textureNames.Count) materials=7"
Write-Host "Native Pusfume animation package passed: controller=pusfume_3p clip=pusfume_3p_walk"
Write-Host "Native Pusfume hero preview enabled: $($HeroPreview.IsPresent)"
