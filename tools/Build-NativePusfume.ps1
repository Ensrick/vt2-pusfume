param(
    [string]$InputBsi = ".build\compiler-fixture\pusfume_bsi_probe\units\pusfume_probe\pusfume_3p.bsi",
    [string]$ModelFbx = ".build\pusfume_handoff\pusfume_3p.fbx",
    [string]$AnimationFbx = ".build\pusfume_handoff\pusfume_3p_walk.fbx",
    [string]$IdleAnimationFbx = "",
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    [string]$FirstPersonBlend = "",
    [string]$FirstPersonDonorUnit = "",
    [ValidateSet("bsi", "fbx")]
    [string]$FirstPersonFormat = "bsi",
    [string]$TextureSource = ".build\pusfume_handoff\textures conv",
    [string]$WorkshopPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\552500\3764954245",
    [string]$GameBundleDir = "C:\Program Files (x86)\Steam\steamapps\common\Warhammer Vermintide 2\bundle",
    [string]$UnpackerExe = "C:\Tools\vt2_bundle_unpacker\target\release\unpacker.exe",
    [switch]$LegacyFur,
    [switch]$IntegratedFur,
    [string]$LegacyFurRoot = ".build\reference_legacy_pusfume",
    [double]$BodyDiffuseGain = 1.2,
    [double]$FurDiffuseGain = 0.55,
    [switch]$HeroPreview,
    [switch]$ParentChildMaterial,
    [switch]$NoDonorTextureShadow,
    [switch]$SplicedGameChild,
    [switch]$UseBsiSkinFallback,
    [switch]$NoDeploy
)

$ErrorActionPreference = "Stop"
if ($BodyDiffuseGain -lt 0.5 -or $BodyDiffuseGain -gt 2.0) {
    throw "BodyDiffuseGain must be between 0.5 and 2.0"
}
if ($FurDiffuseGain -lt 0.25 -or $FurDiffuseGain -gt 1.5) {
    throw "FurDiffuseGain must be between 0.25 and 1.5"
}
# Both fur layouts use the same proven Laurel skinned-cutout material binding.
if ($LegacyFur -and $IntegratedFur) {
    throw "LegacyFur and IntegratedFur are mutually exclusive"
}
$furEnabled = $LegacyFur.IsPresent -or $IntegratedFur.IsPresent
if ($furEnabled) {
    $SplicedGameChild = $true
}
# Track D: ship the -ParentChildMaterial staging, then replace the compiled
# child's payload with the GAME's own mtr_outfit child (texture ids patched to
# the atlas). Uses the parent-child runtime path; the ordered texture shadow
# must stay off (one variable at a time).
if ($SplicedGameChild) {
    $ParentChildMaterial = $true
    $NoDonorTextureShadow = $true
}
if ($ParentChildMaterial -and -not $NoDonorTextureShadow) {
    throw "Parent-child and ordered texture-shadow experiments are mutually exclusive; add -NoDonorTextureShadow"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourceMod = Join-Path $repoRoot "pusfume"
$firstPersonEnabled = -not [string]::IsNullOrWhiteSpace($FirstPersonBlend)
if ($firstPersonEnabled -and -not $SplicedGameChild) {
    throw "FirstPersonBlend requires -SplicedGameChild for the proven skinned material binding"
}
$firstPersonBlendPath = $null
$firstPersonDonorUnitPath = $null
if ($firstPersonEnabled) {
    if ([string]::IsNullOrWhiteSpace($FirstPersonDonorUnit)) {
        throw "FirstPersonBlend requires -FirstPersonDonorUnit for the exact VT2 rest-skeleton rebind"
    }
    $firstPersonBlendPath = if ([IO.Path]::IsPathRooted($FirstPersonBlend)) {
        (Resolve-Path $FirstPersonBlend).Path
    } else {
        (Resolve-Path (Join-Path $repoRoot $FirstPersonBlend)).Path
    }
    if ([IO.Path]::GetExtension($firstPersonBlendPath) -ine ".blend") {
        throw "FirstPersonBlend must be a Blender source file: $firstPersonBlendPath"
    }
    $firstPersonDonorUnitPath = if ([IO.Path]::IsPathRooted($FirstPersonDonorUnit)) {
        (Resolve-Path $FirstPersonDonorUnit).Path
    } else {
        (Resolve-Path (Join-Path $repoRoot $FirstPersonDonorUnit)).Path
    }
    if ([IO.Path]::GetExtension($firstPersonDonorUnitPath) -ine ".unit") {
        throw "FirstPersonDonorUnit must be an extracted compiled VT2 unit: $firstPersonDonorUnitPath"
    }
}
$legacyFurPath = $null
$legacyBodyPath = $null
$legacyFurTextureRoot = $null
if ($furEnabled) {
    $legacyFurRootPath = if ([IO.Path]::IsPathRooted($LegacyFurRoot)) {
        (Resolve-Path $LegacyFurRoot).Path
    } else {
        (Resolve-Path (Join-Path $repoRoot $LegacyFurRoot)).Path
    }
    $legacyFurPath = Join-Path $legacyFurRootPath "units\pusfume\pusfume_inn_fur.fbx"
    $legacyBodyPath = Join-Path $legacyFurRootPath "units\pusfume\pusfume_inn.fbx"
    $legacyFurTextureRoot = Join-Path $legacyFurRootPath "textures\pusfume\inn"
    $legacyLicense = Join-Path $legacyFurRootPath "LICENSE"
    if ($LegacyFur -and -not (Test-Path -LiteralPath $legacyFurPath -PathType Leaf)) {
        throw "Dalokraff legacy fur FBX is missing: $legacyFurPath"
    }
    if ($LegacyFur -and -not (Test-Path -LiteralPath $legacyBodyPath -PathType Leaf)) {
        throw "Dalokraff legacy body FBX is missing: $legacyBodyPath"
    }
    if (-not (Test-Path -LiteralPath $legacyLicense -PathType Leaf) -or
            (Get-Content -LiteralPath $legacyLicense -Raw) -notmatch
                'MIT License[\s\S]*Copyright \(c\) 2022 dalokraff') {
        throw "Dalokraff legacy fur license/provenance contract is missing"
    }
}
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
$modelFbxText = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($modelFbxPath))
$modelContainsIntegratedFur = $modelFbxText.Contains("p_fur")
$modelFbxText = $null
if ($modelContainsIntegratedFur -and -not $furEnabled) {
    throw "The model contains p_fur; rebuild with -IntegratedFur so Stingray cannot assign a default material"
}
if ($IntegratedFur -and -not $modelContainsIntegratedFur) {
    throw "IntegratedFur was requested but the model has no p_fur material slot"
}
$animationFbxPath = if ([IO.Path]::IsPathRooted($AnimationFbx)) {
    (Resolve-Path $AnimationFbx).Path
} else {
    (Resolve-Path (Join-Path $repoRoot $AnimationFbx)).Path
}
if ((Get-Item -LiteralPath $animationFbxPath).Length -lt 1024) {
    throw "The native animation FBX is unexpectedly small: $animationFbxPath"
}
$blenderExePath = (Resolve-Path $BlenderExe).Path
$generatedRoot = Join-Path $repoRoot ".build\generated-native"
New-Item -ItemType Directory -Path $generatedRoot -Force | Out-Null

$firstPersonAssetPath = $null
if ($firstPersonEnabled) {
    $firstPersonExtension = if ($FirstPersonFormat -eq "bsi") { "bsi" } else { "fbx" }
    $firstPersonAssetPath = Join-Path $generatedRoot "pusfume_1p_arms.$firstPersonExtension"
    $firstPersonTool = if ($FirstPersonFormat -eq "bsi") {
        Join-Path $repoRoot "tools\prepare_pusfume_1p_bsi.py"
    } else {
        Join-Path $repoRoot "tools\prepare_pusfume_1p_blend.py"
    }
    $sourceBlendHash = (Get-FileHash -LiteralPath $firstPersonBlendPath -Algorithm SHA256).Hash

    & $blenderExePath --background --factory-startup --disable-autoexec `
        --python $firstPersonTool -- `
        $firstPersonBlendPath $firstPersonDonorUnitPath $firstPersonAssetPath
    if ($LASTEXITCODE -ne 0) {
        throw "First-person Pusfume $($FirstPersonFormat.ToUpperInvariant()) preparation failed with exit code $LASTEXITCODE"
    }
    if ((Get-FileHash -LiteralPath $firstPersonBlendPath -Algorithm SHA256).Hash -ne $sourceBlendHash) {
        throw "First-person preparation modified its source blend: $firstPersonBlendPath"
    }
    if (-not (Test-Path -LiteralPath $firstPersonAssetPath -PathType Leaf) -or `
            (Get-Item -LiteralPath $firstPersonAssetPath).Length -lt 1024) {
        throw "First-person Pusfume $($FirstPersonFormat.ToUpperInvariant()) preparation produced no usable output"
    }
}

$idleFbxPath = Join-Path $generatedRoot "pusfume_3p_idle.fbx"
if ([string]::IsNullOrWhiteSpace($IdleAnimationFbx)) {
    $idleFbxTool = Join-Path $repoRoot "tools\generate_idle_pusfume_fbx.py"
    & $blenderExePath --background --factory-startup --disable-autoexec `
        --python $idleFbxTool -- `
        $modelFbxPath $idleFbxPath
    if ($LASTEXITCODE -ne 0) {
        throw "Idle Pusfume FBX generation failed with exit code $LASTEXITCODE"
    }
} else {
    $idleAnimationFbxPath = if ([IO.Path]::IsPathRooted($IdleAnimationFbx)) {
        (Resolve-Path $IdleAnimationFbx).Path
    } else {
        (Resolve-Path (Join-Path $repoRoot $IdleAnimationFbx)).Path
    }
    Copy-Item -LiteralPath $idleAnimationFbxPath -Destination $idleFbxPath -Force
}
if (-not (Test-Path -LiteralPath $idleFbxPath -PathType Leaf) -or `
        (Get-Item -LiteralPath $idleFbxPath).Length -lt 1024) {
    throw "Idle Pusfume FBX generation produced no usable output"
}

$animationContractTool = Join-Path $repoRoot "tools\validate_pusfume_animation_contract.py"
& $blenderExePath --background --factory-startup --disable-autoexec `
    --python $animationContractTool -- `
    $modelFbxPath $idleFbxPath $animationFbxPath
if ($LASTEXITCODE -ne 0) {
    throw "Pusfume animation contract validation failed with exit code $LASTEXITCODE"
}

$animatedModelFbxPath = $modelFbxPath
if ($useFbxDcc) {
    $animatedFbxTool = Join-Path $repoRoot "tools\prepare_animated_pusfume_fbx.py"
    $animatedModelFbxPath = Join-Path $generatedRoot "pusfume_3p_animated.fbx"

    if ($LegacyFur) {
        & $blenderExePath --background --factory-startup --disable-autoexec `
            --python $animatedFbxTool -- `
            $modelFbxPath $animationFbxPath $animatedModelFbxPath `
            $legacyFurPath $legacyBodyPath
    } else {
        & $blenderExePath --background --factory-startup --disable-autoexec `
            --python $animatedFbxTool -- `
            $modelFbxPath $animationFbxPath $animatedModelFbxPath
    }
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
# A .vmbrc in the staging root lets VMBLauncher.exe resolve the staged copy as
# a mod project, so Workshop uploads ride the monorepo's canonical pipeline
# (vmblauncher upload pusfume --config <settings with ProjectRoot=stage root>).
Copy-Item -LiteralPath (Join-Path $repoRoot ".vmbrc") -Destination (Join-Path $stageRoot ".vmbrc") -Force

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
if ($firstPersonEnabled) {
    Copy-Item -LiteralPath $firstPersonAssetPath `
        -Destination (Join-Path $unitRoot "pusfume_1p_arms.$FirstPersonFormat") -Force
    if ($FirstPersonFormat -eq "bsi") {
        $firstPersonBonesPath = [IO.Path]::ChangeExtension($firstPersonAssetPath, ".bones")
        Copy-Item -LiteralPath $firstPersonBonesPath `
            -Destination (Join-Path $unitRoot "pusfume_1p_arms.bones") -Force
    } else {
    @'
_data_root_version = 1
_id = "9eb2b5d6-ad5e-4a6c-9fb9-19e75c35ebd0"
_name = "units/pusfume/pusfume_1p_arms"
asset = "units/pusfume/pusfume_1p_arms"
extension = ".fbx"
'@ | Set-Content -LiteralPath (Join-Path $unitRoot "pusfume_1p_arms.dcc_asset") -Encoding utf8
    }
}
Copy-Item -LiteralPath $inputBonesPath -Destination (Join-Path $unitRoot "pusfume_3p.bones") -Force
Copy-Item -LiteralPath $animationFbxPath `
    -Destination (Join-Path $animationRoot "pusfume_3p_walk.fbx") -Force
Copy-Item -LiteralPath $idleFbxPath `
    -Destination (Join-Path $animationRoot "pusfume_3p_idle.fbx") -Force

$animationRecipe = @'
bones = "units/pusfume/pusfume_3p"
tolerance = {
    "" = [
        0.01
        0.01
        0
        false
    ]
}
'@
$animationRecipe | Set-Content -LiteralPath (Join-Path $animationRoot "pusfume_3p_walk.animation") -Encoding utf8
$animationRecipe | Set-Content -LiteralPath (Join-Path $animationRoot "pusfume_3p_idle.animation") -Encoding utf8

@'
events = {
    enable = {}
    idle = {}
    walk = {}
}
layers = [
    {
        default_state = "base/idle"
        states = [
            {
                animations = [
                    "units/pusfume/anims/pusfume_3p_idle"
                ]
                loop_animation = true
                name = "base/idle"
                randomization_type = "every_loop"
                root_driving = "ignore"
                speed = "1"
                state_type = "regular"
                transitions = [
                    {
                        blend_time = 0.25
                        event = "walk"
                        mode = "direct"
                        on_beat = ""
                        to = "base/walk"
                    }
                ]
                weights = [
                    "1.0"
                ]
            }
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
                transitions = [
                    {
                        blend_time = 0.25
                        event = "idle"
                        mode = "direct"
                        on_beat = ""
                        to = "base/idle"
                    }
                ]
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
New-Item -ItemType Directory -Path $textureRoot -Force | Out-Null
New-Item -ItemType Directory -Path $materialRoot -Force | Out-Null
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
    # Preserve fractional coverage alpha. The native skinned-alpha material
    # performs its own 0.5 test; preprocessing created the visible tape card.
    $cutAlphaEnabled = "false"

    @"
common = {
    input = {
        filename = "textures/pusfume/$Name"
    }
    output = {
        apply_processing = true
        category = ""
        cut_alpha_threshold = 0.5
        enable_cut_alpha_threshold = $cutAlphaEnabled
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

function Write-NativeTextureRecipe {
    param(
        [string]$Name,
        [bool]$Srgb
    )

    $srgbValue = if ($Srgb) { "true" } else { "false" }
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
        srgb = $srgbValue
        streamable = true
    }
}
"@ | Set-Content -LiteralPath (Join-Path $textureRoot "$Name.texture") -Encoding utf8
}

function Write-LegacyFurTexture {
    param(
        [string]$Name,
        [string]$SourceName,
        [bool]$Srgb,
        [double]$Gain = 1.0
    )

    $source = Join-Path $legacyFurTextureRoot $SourceName
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required dalokraff fur texture is missing: $source"
    }
    $extension = [IO.Path]::GetExtension($source)
    $destination = Join-Path $textureRoot "$Name$extension"
    if ([Math]::Abs($Gain - 1.0) -lt 0.0001) {
        Copy-Item -LiteralPath $source -Destination $destination -Force
    } elseif ($extension -ieq ".png") {
        Add-Type -AssemblyName System.Drawing
        $inputImage = [Drawing.Image]::FromFile($source)
        $outputImage = [Drawing.Bitmap]::new(
            $inputImage.Width, $inputImage.Height,
            [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($outputImage)
        $attributes = New-Object Drawing.Imaging.ImageAttributes
        $matrix = New-Object Drawing.Imaging.ColorMatrix
        $matrix.Matrix00 = $Gain
        $matrix.Matrix11 = $Gain
        $matrix.Matrix22 = $Gain
        $attributes.SetColorMatrix($matrix)
        try {
            $rectangle = [Drawing.Rectangle]::new(
                0, 0, $inputImage.Width, $inputImage.Height)
            $graphics.DrawImage(
                $inputImage, $rectangle, 0, 0, $inputImage.Width, $inputImage.Height,
                [Drawing.GraphicsUnit]::Pixel, $attributes)
            $outputImage.Save($destination, [Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $attributes.Dispose()
            $graphics.Dispose()
            $outputImage.Dispose()
            $inputImage.Dispose()
        }
    } else {
        throw "Texture gain requires a PNG source: $source"
    }
    Write-NativeTextureRecipe $Name $Srgb
}

function Write-PusfumeAtlas {
    param(
        [string]$Name,
        [string]$Suffix,
        [System.Drawing.Color]$ClearColor
    )

    Add-Type -AssemblyName System.Drawing
    $layoutPath = Join-Path $repoRoot "tools\pusfume_atlas_layout.json"
    $layout = Get-Content -LiteralPath $layoutPath -Raw | ConvertFrom-Json
    $atlasSize = [int]$layout.atlas_size
    $atlas = New-Object Drawing.Bitmap($atlasSize, $atlasSize, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($atlas)
    $graphics.Clear($ClearColor)
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $forceOpaque = @($layout.force_opaque_suffixes) -contains $Suffix
    $graphics.CompositingMode = if ($forceOpaque) {
        [Drawing.Drawing2D.CompositingMode]::SourceOver
    } else {
        [Drawing.Drawing2D.CompositingMode]::SourceCopy
    }
    $opaqueAttributes = $null
    if ($forceOpaque) {
        $opaqueAttributes = New-Object Drawing.Imaging.ImageAttributes
        $opaqueMatrix = New-Object Drawing.Imaging.ColorMatrix
        if ($Suffix -eq "df") {
            $opaqueMatrix.Matrix00 = $BodyDiffuseGain
            $opaqueMatrix.Matrix11 = $BodyDiffuseGain
            $opaqueMatrix.Matrix22 = $BodyDiffuseGain
        }
        $opaqueMatrix.Matrix33 = 0
        $opaqueMatrix.Matrix43 = 1
        $opaqueAttributes.SetColorMatrix($opaqueMatrix)
    }

    function Draw-AtlasTile {
        param(
            [string]$Texture,
            [int]$X,
            [int]$Y,
            [int]$Width,
            [int]$Height
        )

        $sourcePath = Join-Path $textureSourcePath "$Texture.png"
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Required Pusfume atlas texture is missing: $sourcePath"
        }

        $source = [Drawing.Image]::FromFile($sourcePath)
        try {
            $top = $atlasSize - $Y - $Height
            if ($forceOpaque) {
                $destination = New-Object Drawing.Rectangle($X, $top, $Width, $Height)
                $graphics.DrawImage(
                    $source, $destination, 0, 0, $source.Width, $source.Height,
                    [Drawing.GraphicsUnit]::Pixel, $opaqueAttributes)
            } else {
                $graphics.DrawImage($source, $X, $top, $Width, $Height)
            }
        } finally {
            $source.Dispose()
        }
    }

    try {
        foreach ($tileProperty in $layout.tiles.PSObject.Properties) {
            $tile = $tileProperty.Value
            $textureProperty = $tile.sources.PSObject.Properties[$Suffix]
            $texture = if ($null -eq $textureProperty.Value) {
                $null
            } else {
                [string]$textureProperty.Value
            }
            if ([string]::IsNullOrWhiteSpace($texture)) {
                continue
            }
            $originX = [int]$tile.origin[0]
            $originY = [int]$tile.origin[1]
            $width = [int]$tile.size[0]
            $height = [int]$tile.size[1]
            foreach ($row in 0..([int]$tile.grid[1] - 1)) {
                foreach ($column in 0..([int]$tile.grid[0] - 1)) {
                    Draw-AtlasTile $texture `
                        ($originX + $column * $width) ($originY + $row * $height) `
                        $width $height
                }
            }
        }

        $output = Join-Path $textureRoot "$Name.png"
        $atlas.Save($output, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        if ($null -ne $opaqueAttributes) {
            $opaqueAttributes.Dispose()
        }
        $graphics.Dispose()
        $atlas.Dispose()
    }
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
if ($furEnabled) {
    Write-LegacyFurTexture "pusfume_fur_df" "psf_fur_d_rein.png" $true $FurDiffuseGain
    Write-LegacyFurTexture "pusfume_fur_nm" "psf_fur_n.tga" $false
    Write-LegacyFurTexture "pusfume_fur_s" "psf_fur_s.tga" $false
    $textureNames += @("pusfume_fur_df", "pusfume_fur_nm", "pusfume_fur_s")
}

Write-PusfumeAtlas "pusfume_atlas_df" "df" ([Drawing.Color]::Black)
Write-PusfumeAtlas "pusfume_atlas_nm" "nm" ([Drawing.Color]::FromArgb(255, 128, 128, 255))
Write-PusfumeAtlas "pusfume_atlas_s" "s" ([Drawing.Color]::Black)
Write-NativeTextureRecipe "pusfume_atlas_df" $true
Write-NativeTextureRecipe "pusfume_atlas_nm" $false
Write-NativeTextureRecipe "pusfume_atlas_s" $false

# Shadow builds must keep the atlas out of the startup package. These fallback
# materials therefore use their original per-slot maps; the runtime donor swap
# happens before they are visible, and the atlas loads later from native_shadow.
if (-not $NoDonorTextureShadow) {
    Write-NativeMaterial "pusfume_body" "pusfume_body_new_df" "skaven_body_nm" "skaven_body_s" 0.72
    Write-NativeMaterial "pusfume_eye" "pusfume_eyenormal" "skaven_body_nm" "skaven_body_s" 0.35 -Emissive
    Write-NativeMaterial "pusfume_metal" "wpn_skaven_set_df" "wpn_skaven_set_nm" "wpn_skaven_set_s" 0.38 0.7
    Write-NativeMaterial "pusfume_globadier" "globadier_outfit_df" "globadier_outfit_nm" "globadier_outfit_s" 0.58
    Write-NativeMaterial "pusfume_armor" "stormvermin_outfit_df" "stormvermin_outfit_nm" "stormvermin_outfit_s" 0.48 0.35
    Write-NativeMaterial "pusfume_ammo_box" "pup_ammo_box_limited_df" "pup_ammo_box_limited_nm" "pup_ammo_box_limited_s" 0.62
} else {
    Write-NativeMaterial "pusfume_body" "pusfume_atlas_df" "pusfume_atlas_nm" "pusfume_atlas_s" 0.72
    Write-NativeMaterial "pusfume_eye" "pusfume_atlas_df" "pusfume_atlas_nm" "pusfume_atlas_s" 0.35 -Emissive
    Write-NativeMaterial "pusfume_metal" "pusfume_atlas_df" "pusfume_atlas_nm" "pusfume_atlas_s" 0.38 0.7
    Write-NativeMaterial "pusfume_globadier" "pusfume_atlas_df" "pusfume_atlas_nm" "pusfume_atlas_s" 0.58
    Write-NativeMaterial "pusfume_armor" "pusfume_atlas_df" "pusfume_atlas_nm" "pusfume_atlas_s" 0.48 0.35
    Write-NativeMaterial "pusfume_ammo_box" "pusfume_atlas_df" "pusfume_atlas_nm" "pusfume_atlas_s" 0.62
}
Write-NativeMaterial "pusfume_whiskers" "pusfume_whiskers_df" "pusfume_whiskers_nm" "pusfume_whiskers_s" 0.74 -Opacity
if ($furEnabled) {
    Write-NativeMaterial "pusfume_fur" "pusfume_fur_df" "pusfume_fur_nm" "pusfume_fur_s" 0.78 -Opacity
}

if (-not $NoDonorTextureShadow) {
    @'
texture = [
	"textures/pusfume/pusfume_atlas_df"
	"textures/pusfume/pusfume_atlas_nm"
	"textures/pusfume/pusfume_atlas_s"
]
'@ | Set-Content -LiteralPath (Join-Path $stageMod `
        "resource_packages\pusfume\native_shadow.package") -Encoding utf8
}

# Child material inheriting the playable Globadier's compiled character
# material. Runtime texture overrides never rebind on character materials, so
# the atlas maps are baked in at compile time and the game's skinning shader is
# inherited through the parent chain. The compiler demands a parent SOURCE at
# the exact donor path; the stub below exists only to satisfy compilation. The
# compiled child stores the parent as a hash reference (offline-verified
# against the game's own mtr_outfit child), so at runtime the reference
# resolves against whichever copy of the parent resource wins bundle
# precedence - the live test distinguishes the two outcomes: deforming body
# with atlas colors means the game parent won; rigid body with atlas colors
# means the bundled stub shadowed it.
if ($ParentChildMaterial) {
    $donorParentSourceDir = Join-Path $stageMod ("units\beings\player\dark_pact_skins\" +
        "skaven_wind_globadier\skin_1001\third_person")
    New-Item -ItemType Directory -Path $donorParentSourceDir -Force | Out-Null
    $stubTemplate = Get-Content -LiteralPath (Join-Path $repoRoot `
        "tools\material_templates\character_skinned.material") -Raw
    $stubTemplate = $stubTemplate.Replace("__COLOR_MAP__", "textures/pusfume/pusfume_atlas_df")
    $stubTemplate = $stubTemplate.Replace("__NORMAL_MAP__", "textures/pusfume/pusfume_atlas_nm")
    $stubTemplate = $stubTemplate.Replace("__DETAIL_MAP__", "textures/pusfume/pusfume_atlas_s")
    $stubTemplate = $stubTemplate.Replace("__EMISSIVE_MAP__", "textures/pusfume/pusfume_atlas_df")
    $stubTemplate | Set-Content -LiteralPath (Join-Path $donorParentSourceDir "mtr_outfit.material") -Encoding utf8

    # The child lives OUTSIDE materials/pusfume/* and in its own package so
    # its resource load can be ordered AFTER the donor package at runtime; if
    # the engine resolves the parent reference eagerly at material load, a
    # startup-package child would fault before Lua could load the parent.
    $childMaterialRoot = Join-Path $stageMod "child_materials\pusfume"
    New-Item -ItemType Directory -Path $childMaterialRoot -Force | Out-Null

    @'
parent_material = "units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/mtr_outfit"
material_contexts = {
	surface_material = ""
}
textures = {
	texture_map_02af90f8 = "textures/pusfume/pusfume_atlas_df"
	texture_map_27b67fd2 = "textures/pusfume/pusfume_atlas_nm"
	texture_map_8bf37d8e = "textures/pusfume/pusfume_atlas_s"
}
'@ | Set-Content -LiteralPath (Join-Path $childMaterialRoot "pusfume_outfit_child.material") -Encoding utf8

    # This source is only a compiler placeholder. -SplicedGameChild replaces
    # its payload with the installed game's Laurel feather child, patched to
    # Janfon's whisker textures, so the shipped binding retains skinning and
    # the native alpha-card shader permutation.
    $whiskerChildTemplate = Get-Content -LiteralPath (Join-Path $repoRoot `
        "tools\material_templates\character_skinned_cutout.material") -Raw
    $whiskerChildTemplate = $whiskerChildTemplate.Replace(
        "__COLOR_MAP__", "textures/pusfume/pusfume_whiskers_df")
    $whiskerChildTemplate = $whiskerChildTemplate.Replace(
        "__NORMAL_MAP__", "textures/pusfume/pusfume_whiskers_nm")
    $whiskerChildTemplate = $whiskerChildTemplate.Replace(
        "__DETAIL_MAP__", "textures/pusfume/pusfume_whiskers_s")
    $whiskerChildTemplate = $whiskerChildTemplate.Replace(
        "__EMISSIVE_MAP__", "textures/pusfume/pusfume_whiskers_df")
    $whiskerChildTemplate | Set-Content -LiteralPath (Join-Path $childMaterialRoot `
        "pusfume_whiskers_child.material") -Encoding utf8

    if ($firstPersonEnabled) {
        $firstPersonChildTemplate = Get-Content -LiteralPath (Join-Path $repoRoot `
            "tools\material_templates\character_skinned.material") -Raw
        $firstPersonChildTemplate = $firstPersonChildTemplate.Replace(
            "__COLOR_MAP__", "textures/pusfume/pusfume_body_new_df")
        $firstPersonChildTemplate = $firstPersonChildTemplate.Replace(
            "__NORMAL_MAP__", "textures/pusfume/skaven_body_nm")
        $firstPersonChildTemplate = $firstPersonChildTemplate.Replace(
            "__DETAIL_MAP__", "textures/pusfume/skaven_body_s")
        $firstPersonChildTemplate = $firstPersonChildTemplate.Replace(
            "__EMISSIVE_MAP__", "textures/pusfume/pusfume_body_new_df")
        $firstPersonChildTemplate | Set-Content -LiteralPath (Join-Path $childMaterialRoot `
            "pusfume_1p_body_child.material") -Encoding utf8

        @'
material = [
    "child_materials/pusfume/pusfume_1p_body_child"
]
'@ | Set-Content -LiteralPath (Join-Path $stageMod `
            "resource_packages\pusfume\native_1p_child.package") -Encoding utf8
    }

    if ($furEnabled) {
        $furChildTemplate = Get-Content -LiteralPath (Join-Path $repoRoot `
            "tools\material_templates\character_skinned_cutout.material") -Raw
        $furChildTemplate = $furChildTemplate.Replace(
            "__COLOR_MAP__", "textures/pusfume/pusfume_fur_df")
        $furChildTemplate = $furChildTemplate.Replace(
            "__NORMAL_MAP__", "textures/pusfume/pusfume_fur_nm")
        $furChildTemplate = $furChildTemplate.Replace(
            "__DETAIL_MAP__", "textures/pusfume/pusfume_fur_s")
        $furChildTemplate = $furChildTemplate.Replace(
            "__EMISSIVE_MAP__", "textures/pusfume/pusfume_fur_df")
        $furChildTemplate | Set-Content -LiteralPath (Join-Path $childMaterialRoot `
            "pusfume_fur_child.material") -Encoding utf8
    }

    $nativeChildMaterialEntries = @(
        '    "child_materials/pusfume/pusfume_outfit_child"',
        '    "child_materials/pusfume/pusfume_whiskers_child"'
    )
    if ($furEnabled) {
        $nativeChildMaterialEntries += '    "child_materials/pusfume/pusfume_fur_child"'
    }

    @"
material = [
$($nativeChildMaterialEntries -join "`n")
]
"@ | Set-Content -LiteralPath (Join-Path $stageMod "resource_packages\pusfume\native_child.package") -Encoding utf8
}

$furMaterialEntry = if ($furEnabled) {
    '    p_fur = "materials/pusfume/pusfume_fur"'
} else {
    ""
}
$furRenderableEntry = if ($LegacyFur) {
@'
    p_fur = {
        always_keep = false
        culling = "bounding_volume"
        generate_uv_unwrap = false
        occluder = false
        shadow_caster = true
        surface_queries = false
        viewport_visible = true
    }
'@
} else {
    ""
}

@"
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
$furMaterialEntry
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
$furRenderableEntry
}
"@ | Set-Content -LiteralPath (Join-Path $unitRoot "pusfume_3p.unit") -Encoding utf8

if ($firstPersonEnabled) {
    @'
materials = {
    p_main = "materials/pusfume/pusfume_body"
}
renderables = {
    pusfume_1p_arms = {
        always_keep = false
        culling = "disabled"
        generate_uv_unwrap = false
        occluder = false
        shadow_caster = false
        surface_queries = false
        viewport_visible = true
    }
}
'@ | Set-Content -LiteralPath (Join-Path $unitRoot "pusfume_1p_arms.unit") -Encoding utf8
}

$heroPreviewEnabled = if ($HeroPreview) { "true" } else { "false" }
# The stub parent currently shadows the game's mtr_outfit inside the bundle
# (2026-07-16 live test: black rigid body - child inherited the stub's
# standard shader whose slots do not match the overrides). Keep the compiled
# child material opt-in until the stub can be stripped from the built bundle.
$parentChildMaterialValue = if ($ParentChildMaterial) {
    '"child_materials/pusfume/pusfume_outfit_child"'
} else {
    "false"
}
$parentChildPackageValue = if ($ParentChildMaterial) {
    '"resource_packages/pusfume/native_child"'
} else {
    "false"
}
$whiskerChildMaterialValue = if ($SplicedGameChild) {
    '"child_materials/pusfume/pusfume_whiskers_child"'
} else {
    "false"
}
$furChildMaterialValue = if ($SplicedGameChild -and $furEnabled) {
    '"child_materials/pusfume/pusfume_fur_child"'
} else {
    "false"
}
$firstPersonUnitValue = if ($firstPersonEnabled) {
    '"units/pusfume/pusfume_1p_arms"'
} else {
    "false"
}
$firstPersonMaterialPackageValue = if ($firstPersonEnabled) {
    '"resource_packages/pusfume/native_1p_child"'
} else {
    "false"
}
$firstPersonMaterialsValue = if ($firstPersonEnabled) {
@'
{
        p_main = "child_materials/pusfume/pusfume_1p_body_child",
    }
'@
} else {
    "false"
}

# Donor texture shadowing: after the SDK build, the atlas textures' bundled
# identities are renamed to the ids the game's mtr_outfit child binds (parsed
# from the game's compiled 90BDF3BAC6F81BA8.material: slot keys are
# IdString32("texture_map_<suffix>")). Our package registers those ids first,
# so the donor material samples Janfon's maps. When the shadow is active the
# Lua runtime texture restore must not run: the atlas resources no longer
# exist under their original paths.
$donorTextureShadowValue = if ($NoDonorTextureShadow) { "false" } else { "true" }
$donorTextureShadowPackageValue = if ($NoDonorTextureShadow) {
    "false"
} else {
    '"resource_packages/pusfume/native_shadow"'
}
$firstPersonDirectLinkValue = if ($firstPersonEnabled) { "true" } else { "false" }

@"
return {
    donor_material_enabled = true,
    donor_material = "units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/mtr_outfit",
    donor_package = "units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/chr_third_person_mesh",
    donor_texture_shadow = $donorTextureShadowValue,
    donor_texture_shadow_package = $donorTextureShadowPackageValue,
    enabled = true,
    first_person_material_package = $firstPersonMaterialPackageValue,
    first_person_materials = $firstPersonMaterialsValue,
    first_person_direct_link = $firstPersonDirectLinkValue,
    first_person_unit = $firstPersonUnitValue,
    hero_preview_enabled = $heroPreviewEnabled,
    hide_donor_weapons = true,
    locomotion_events_enabled = true,
    parent_child_material = $parentChildMaterialValue,
    parent_child_package = $parentChildPackageValue,
    fur_child_material = $furChildMaterialValue,
    whisker_child_material = $whiskerChildMaterialValue,
    whisker_donor_package = "units/beings/player/empire_soldier_knight/headpiece/es_k_hat_07",
    manual_clip_length = 0.8,
    manual_clip_name = "units/pusfume/anims/pusfume_3p_walk",
    manual_clip_probe = false,
    manual_skin_probe = false,
    root_animation_isolation = true,
    skin_name = "pusfume_skin",
    third_person_unit = "units/pusfume/pusfume_3p",
}
"@ | Set-Content -LiteralPath (Join-Path $stageMod `
    "scripts\mods\pusfume\_pusfume_native_config.lua") -Encoding utf8

$firstPersonUnitPackageEntry = if ($firstPersonEnabled) {
    '    "units/pusfume/pusfume_1p_arms"'
} else {
    ""
}

@"

unit = [
    "units/pusfume/pusfume_3p"
$firstPersonUnitPackageEntry
]
"@ | Add-Content -LiteralPath (Join-Path $stageMod `
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
    "units/pusfume/anims/pusfume_3p_idle"
]
'@ | Add-Content -LiteralPath (Join-Path $stageMod `
    "resource_packages\pusfume\pusfume.package") -Encoding utf8

$rootTextureEntries = $textureNames | ForEach-Object { "    `"textures/pusfume/$_`"" }
if ($NoDonorTextureShadow) {
    $rootTextureEntries += @(
        '    "textures/pusfume/pusfume_atlas_df"',
        '    "textures/pusfume/pusfume_atlas_nm"',
        '    "textures/pusfume/pusfume_atlas_s"'
    )
}

@"

texture = [
$($rootTextureEntries -join "`n")
]
"@ | Add-Content -LiteralPath (Join-Path $stageMod `
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

$processedBundlesPath = Join-Path $stageRoot ".temp\pusfumeV2\compile\processed_bundles.csv"
if (-not (Test-Path -LiteralPath $processedBundlesPath -PathType Leaf)) {
    throw "SDK reported success without a processed resource manifest"
}
$processedBundlesText = Get-Content -LiteralPath $processedBundlesPath -Raw
$requiredCompiledResources = @(
    "gui/1080p/single_textures/pusfume_portraits/portrait_pusfume,texture,",
    "gui/1080p/single_textures/pusfume_portraits/medium_portrait_pusfume,texture,",
    "gui/1080p/single_textures/pusfume_portraits/small_portrait_pusfume,texture,",
    "materials/ui/portrait_pusfume,material,",
    "materials/ui/medium_portrait_pusfume,material,",
    "materials/ui/small_portrait_pusfume,material,"
)
if ($firstPersonEnabled) {
    $requiredCompiledResources += "units/pusfume/pusfume_1p_arms,unit,"
}
foreach ($resource in $requiredCompiledResources) {
    if (-not $processedBundlesText.Contains(",$resource")) {
        throw "Compiled resource manifest omitted $resource"
    }
}
Write-Host "Compiled portrait and first-person resource manifest passed"

if ($firstPersonEnabled) {
    $debugIndexPath = Join-Path $stageRoot ".temp\pusfumeV2\compile\debug_file_index.sjson"
    $debugIndexText = Get-Content -LiteralPath $debugIndexPath -Raw
    $firstPersonCompiledMatch = [regex]::Match(
        $debugIndexText,
        '"(data/[^"\r\n]+)"\s*=\s*"units/pusfume/pusfume_1p_arms\.unit"')
    if (-not $firstPersonCompiledMatch.Success) {
        throw "Compiled debug index omitted the first-person arms unit"
    }

    $compiledFirstPersonUnit = Join-Path $stageRoot (
        ".temp\pusfumeV2\compile\" +
        $firstPersonCompiledMatch.Groups[1].Value.Replace('/', '\'))
    $compiledRestTool = Join-Path $repoRoot "tools\validate_compiled_1p_rest.py"
    & py $compiledRestTool $compiledFirstPersonUnit $firstPersonDonorUnitPath
    if ($LASTEXITCODE -ne 0) {
        throw "Compiled first-person rest-skeleton validation failed"
    }
}

if ($ParentChildMaterial) {
    # The compiled stub parent rides into a bundle at the game's resource path
    # and shadows the real mtr_outfit (2026-07-16: black rigid body). Rename
    # its identity to an unused hash so the child material's parent reference
    # resolves against the game's copy. Exactly three pairs exist: the bundle
    # index, the file data header, and the compiled package listing.
    $stripTool = Join-Path $repoRoot "tools\strip_bundle_resource.py"
    $donorParentPath = "units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/mtr_outfit"
    $totalStripped = 0

    foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
        $dryOutput = & py $stripTool $bundleFile.FullName --type material `
            --old $donorParentPath --new "units/pusfume/retired_stub_parent" --dry-run 2>&1
        $found = 0
        if ($dryOutput -join "`n" -match '(\d+) occurrence') {
            $found = [int]$Matches[1]
        }

        if ($found -gt 0) {
            & py $stripTool $bundleFile.FullName --type material `
                --old $donorParentPath --new "units/pusfume/retired_stub_parent" --expect $found
            if ($LASTEXITCODE -ne 0) {
                throw "Stub strip failed on $($bundleFile.Name)"
            }
            $totalStripped += $found
        }
    }

    # The pair count depends on packaging layout (index + file header, plus a
    # package listing when the owning package enumerates dependencies). The
    # invariant that matters: at least the index/header pairs were found, and
    # afterwards NO bundle carries the donor-path identity.
    if ($totalStripped -lt 2) {
        throw "Expected at least 2 stub identity pairs across bundles, stripped $totalStripped"
    }

    foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
        & py $stripTool $bundleFile.FullName --type material `
            --old $donorParentPath --new "units/pusfume/retired_stub_parent" --expect 0 --dry-run
        if ($LASTEXITCODE -ne 0) {
            throw "Stub identity still present in $($bundleFile.Name) after strip"
        }
    }

    Write-Host "Stub parent identity stripped: $totalStripped pair(s) renamed to units/pusfume/retired_stub_parent"
}

if ($SplicedGameChild) {
    # Track D: replace our SDK-compiled child's payload with the game's own
    # compiled mtr_outfit child, texture ids patched to the atlas. Our child
    # renders rigid because its shader binding was baked against the stub at
    # compile time (live 2026-07-16 11:24); the game payload carries the real
    # skinning binding, its parent hash (3D25339231384C80, the shader library
    # entry), and after patching, Pusfume's texture ids. The payload derives
    # from installed game data and never leaves .build.
    $donorGameBundle = Join-Path $GameBundleDir "7a8e617a32277fc4"
    if (-not (Test-Path -LiteralPath $donorGameBundle -PathType Leaf)) {
        throw "Installed donor game bundle not found: $donorGameBundle"
    }
    if (-not (Test-Path -LiteralPath $UnpackerExe -PathType Leaf)) {
        throw "vt2_bundle_unpacker not found: $UnpackerExe"
    }

    $spliceExtractDir = Join-Path $generatedRoot "donor-bundle-extract"
    New-Item -ItemType Directory -Path $spliceExtractDir -Force | Out-Null
    & $UnpackerExe extract $donorGameBundle $spliceExtractDir --flatten 2>$null | Out-Null
    $gameChildPath = Join-Path $spliceExtractDir "90BDF3BAC6F81BA8.material"
    if (-not (Test-Path -LiteralPath $gameChildPath -PathType Leaf)) {
        throw "Donor bundle extraction did not produce 90BDF3BAC6F81BA8.material"
    }

    # Slot semantics decoded from the donor's own texture CONTENT (channel
    # statistics, 2026-07-16): texture_map_02af90f8 = diffuse (red/orange,
    # alpha ~250); texture_map_27b67fd2 = EMISSIVE - the donor ships a pure
    # black map (means 0/1/1/0), and putting a normal map here is what made
    # the whole model glow; texture_map_8bf37d8e = NORMAL + gloss-in-alpha
    # (donor: XY in RG around 128, B=0, alpha ~196). So: patch diffuse and
    # normal to the atlas, and leave the donor's own black emissive untouched
    # (it is resident via the donor package, which always loads first).
    $splicePayload = Join-Path $generatedRoot "spliced_child_payload.bin"
    & py (Join-Path $repoRoot "tools\make_spliced_child.py") `
        --extracted $gameChildPath `
        --resource hash:90BDF3BAC6F81BA8 --expect-size 768 `
        --expect-parent 3D25339231384C80 `
        --map DD74D8319F514D96=C263ECB79A8DCEC0 `
        --map E334A8CB6BCB5E6D=A4215592F6297E57 `
        --set-variable emissive_color=0,0,0 `
        --expect-texture texture_map_02af90f8=C263ECB79A8DCEC0 `
        --expect-texture texture_map_27b67fd2=45FFAEEF53695A86 `
        --expect-texture texture_map_8bf37d8e=A4215592F6297E57 `
        --out $splicePayload
    if ($LASTEXITCODE -ne 0) {
        throw "Spliced child payload generation failed"
    }

    $spliceTool = Join-Path $repoRoot "tools\splice_bundle_resource.py"
    $childId = "hash:F72D636600F7F598"
    $splicedInto = @()

    foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
        & py $spliceTool $bundleFile.FullName --type material `
            --name $childId --payload $splicePayload --dry-run 2>$null
        if ($LASTEXITCODE -eq 0) {
            & py $spliceTool $bundleFile.FullName --type material `
                --name $childId --payload $splicePayload
            if ($LASTEXITCODE -ne 0) {
                throw "Splice failed on $($bundleFile.Name)"
            }
            $splicedInto += $bundleFile.Name
        }
    }

    if ($splicedInto.Count -ne 1) {
        throw "Expected the compiled child in exactly 1 bundle, spliced $($splicedInto.Count)"
    }

    Write-Host "Spliced game child payload (768 bytes, atlas texture ids) into $($splicedInto[0])"

    if ($firstPersonEnabled) {
        # The 1P mesh keeps Janfon's original UVs, so splice the same proven
        # character-skin binding with direct body maps rather than the 3P atlas.
        $firstPersonPayload = Join-Path $generatedRoot "spliced_1p_child_payload.bin"
        & py (Join-Path $repoRoot "tools\make_spliced_child.py") `
            --extracted $gameChildPath `
            --resource hash:90BDF3BAC6F81BA8 --expect-size 768 `
            --expect-parent 3D25339231384C80 `
            --map DD74D8319F514D96=E0C4E09D80AE735B `
            --map E334A8CB6BCB5E6D=3B3F6545AF6782F5 `
            --set-variable emissive_color=0,0,0 `
            --expect-texture texture_map_02af90f8=E0C4E09D80AE735B `
            --expect-texture texture_map_27b67fd2=45FFAEEF53695A86 `
            --expect-texture texture_map_8bf37d8e=3B3F6545AF6782F5 `
            --out $firstPersonPayload
        if ($LASTEXITCODE -ne 0) {
            throw "Spliced first-person child payload generation failed"
        }

        $firstPersonSplicedInto = @()
        foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
            & py $spliceTool $bundleFile.FullName --type material `
                --name "child_materials/pusfume/pusfume_1p_body_child" `
                --payload $firstPersonPayload --dry-run 2>$null
            if ($LASTEXITCODE -eq 0) {
                & py $spliceTool $bundleFile.FullName --type material `
                    --name "child_materials/pusfume/pusfume_1p_body_child" `
                    --payload $firstPersonPayload
                if ($LASTEXITCODE -ne 0) {
                    throw "First-person material splice failed on $($bundleFile.Name)"
                }
                $firstPersonSplicedInto += $bundleFile.Name
            }
        }

        if ($firstPersonSplicedInto.Count -ne 1) {
            throw "Expected the first-person child in exactly 1 bundle, spliced $($firstPersonSplicedInto.Count)"
        }

        Write-Host "Spliced native 1P body payload (768 bytes, direct UV maps) into $($firstPersonSplicedInto[0])"
    }

    # Laurel's compiled feather material is the proven skinned alpha-card
    # contract. Preserve its shader parent, alpha scalar, and channel layout;
    # patch only the three texture resources to Janfon's whisker maps.
    $laurelGameBundle = Join-Path $GameBundleDir "95865e5dbaf202e3"
    if (-not (Test-Path -LiteralPath $laurelGameBundle -PathType Leaf)) {
        throw "Installed Laurel game bundle not found: $laurelGameBundle"
    }

    $laurelExtractDir = Join-Path $generatedRoot "laurel-bundle-extract"
    New-Item -ItemType Directory -Path $laurelExtractDir -Force | Out-Null
    & $UnpackerExe extract $laurelGameBundle $laurelExtractDir --flatten `
        --include "*C70B1AAD3B363E24*" 2>$null | Out-Null
    $laurelMaterialPath = Join-Path $laurelExtractDir "C70B1AAD3B363E24.material"
    if (-not (Test-Path -LiteralPath $laurelMaterialPath -PathType Leaf)) {
        throw "Laurel bundle extraction did not produce C70B1AAD3B363E24.material"
    }

    $whiskerPayload = Join-Path $generatedRoot "spliced_whisker_payload.bin"
    & py (Join-Path $repoRoot "tools\make_spliced_child.py") `
        --extracted $laurelMaterialPath `
        --resource hash:C70B1AAD3B363E24 --expect-size 128 `
        --expect-parent F85B289742D5D69A `
        --map C9CF19C214612D75=7F060B4938ADCF12 `
        --map CDA03B9B0226037A=950FC5950CCEBCD0 `
        --map D3FD8377A3DE498A=BEB4D8D9891A6D4A `
        --expect-texture texture_map_c0ba2942=7F060B4938ADCF12 `
        --expect-texture texture_map_59cd86b9=950FC5950CCEBCD0 `
        --expect-texture texture_map_b788717c=BEB4D8D9891A6D4A `
        --out $whiskerPayload
    if ($LASTEXITCODE -ne 0) {
        throw "Spliced Laurel whisker payload generation failed"
    }

    $whiskerSplicedInto = @()
    foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
        & py $spliceTool $bundleFile.FullName --type material `
            --name "child_materials/pusfume/pusfume_whiskers_child" `
            --payload $whiskerPayload --dry-run 2>$null
        if ($LASTEXITCODE -eq 0) {
            & py $spliceTool $bundleFile.FullName --type material `
                --name "child_materials/pusfume/pusfume_whiskers_child" `
                --payload $whiskerPayload
            if ($LASTEXITCODE -ne 0) {
                throw "Whisker material splice failed on $($bundleFile.Name)"
            }
            $whiskerSplicedInto += $bundleFile.Name
        }
    }

    if ($whiskerSplicedInto.Count -ne 1) {
        throw "Expected the whisker child in exactly 1 bundle, spliced $($whiskerSplicedInto.Count)"
    }

    Write-Host "Spliced Laurel feather payload (128 bytes, Pusfume whisker maps) into $($whiskerSplicedInto[0])"
    if ($furEnabled) {
        # Reuse the same proven skinned alpha-card binding for fur, but patch
        # all three channels to the licensed dalokraff texture set.
        $furPayload = Join-Path $generatedRoot "spliced_fur_payload.bin"
        & py (Join-Path $repoRoot "tools\make_spliced_child.py") `
            --extracted $laurelMaterialPath `
            --resource hash:C70B1AAD3B363E24 --expect-size 128 `
            --expect-parent F85B289742D5D69A `
            --map C9CF19C214612D75=20A7120B25F414F7 `
            --map CDA03B9B0226037A=57505EBDF932A68B `
            --map D3FD8377A3DE498A=D7B1C45DEFA31C39 `
            --expect-texture texture_map_c0ba2942=20A7120B25F414F7 `
            --expect-texture texture_map_59cd86b9=57505EBDF932A68B `
            --expect-texture texture_map_b788717c=D7B1C45DEFA31C39 `
            --out $furPayload
        if ($LASTEXITCODE -ne 0) {
            throw "Spliced Laurel fur payload generation failed"
        }

        $furSplicedInto = @()
        foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
            & py $spliceTool $bundleFile.FullName --type material `
                --name "child_materials/pusfume/pusfume_fur_child" `
                --payload $furPayload --dry-run 2>$null
            if ($LASTEXITCODE -eq 0) {
                & py $spliceTool $bundleFile.FullName --type material `
                    --name "child_materials/pusfume/pusfume_fur_child" `
                    --payload $furPayload
                if ($LASTEXITCODE -ne 0) {
                    throw "Fur material splice failed on $($bundleFile.Name)"
                }
                $furSplicedInto += $bundleFile.Name
            }
        }

        if ($furSplicedInto.Count -ne 1) {
            throw "Expected the fur child in exactly 1 bundle, spliced $($furSplicedInto.Count)"
        }

        Write-Host "Spliced Laurel feather payload (128 bytes, dalokraff fur maps) into $($furSplicedInto[0])"
    }
    # The locator dry-runs exit 1 on bundles without the child; do not let the
    # last probe's code leak out as the script's exit status.
    $global:LASTEXITCODE = 0
}

if (-not $NoDonorTextureShadow) {
    # Rename the compiled atlas textures' bundled identities to the exact ids
    # the game's mtr_outfit child references, so the donor swap binds Janfon's
    # maps instead of the Globadier's. The ids were parsed from the game's own
    # compiled child (bundle 7a8e617a32277fc4, resource 90BDF3BAC6F81BA8):
    #   texture_map_02af90f8 (diffuse) -> DD74D8319F514D96
    #   texture_map_27b67fd2 (emissive) -> 45FFAEEF53695A86
    #   texture_map_8bf37d8e (normal)   -> E334A8CB6BCB5E6D
    # Bare mode rewrites every 8-byte name-hash occurrence: bundle index, file
    # header, package listing, AND texture references inside our own compiled
    # materials, so every internal reference stays consistent under the new id.
    $stripTool = Join-Path $repoRoot "tools\strip_bundle_resource.py"
    $donorTextureIds = [ordered]@{
        "textures/pusfume/pusfume_atlas_df" = "DD74D8319F514D96"
        "textures/pusfume/pusfume_atlas_nm" = "45FFAEEF53695A86"
        "textures/pusfume/pusfume_atlas_s"  = "E334A8CB6BCB5E6D"
    }

    foreach ($atlasPath in $donorTextureIds.Keys) {
        $donorId = $donorTextureIds[$atlasPath]
        $totalRenamed = 0

        foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
            $dryOutput = & py $stripTool $bundleFile.FullName --type texture --bare `
                --old $atlasPath --new-hash $donorId --dry-run 2>&1
            $found = 0
            if ($dryOutput -join "`n" -match '(\d+) occurrence') {
                $found = [int]$Matches[1]
            }

            if ($found -gt 0) {
                & py $stripTool $bundleFile.FullName --type texture --bare `
                    --old $atlasPath --new-hash $donorId --expect $found
                if ($LASTEXITCODE -ne 0) {
                    throw "Donor texture shadow rename failed on $($bundleFile.Name) for $atlasPath"
                }
                $totalRenamed += $found
            }
        }

        # The isolated native_shadow layout intentionally has only the bundle
        # index and file header. Any material/startup-package references would
        # preload the atlas and invalidate the load-order experiment.
        if ($totalRenamed -ne 2) {
            throw "Expected exactly 2 isolated identity occurrences for $atlasPath, renamed $totalRenamed"
        }

        foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
            & py $stripTool $bundleFile.FullName --type texture --bare `
                --old $atlasPath --new-hash $donorId --expect 0 --dry-run
            if ($LASTEXITCODE -ne 0) {
                throw "Atlas identity still present in $($bundleFile.Name) after shadow rename"
            }
        }

        Write-Host "Donor texture shadow: $atlasPath -> $donorId ($totalRenamed occurrence(s))"
    }
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
$materialCount = if ($furEnabled) { 8 } else { 7 }
Write-Host "Native Pusfume build passed: source=$nativeSourceKind bytes=$nativeSourceSize bundles=$($bundles.Count)"
Write-Host "Native Pusfume materials passed: textures=$($textureNames.Count) materials=$materialCount"
Write-Host "Native Pusfume animation package passed: controller=pusfume_3p clips=pusfume_3p_idle,pusfume_3p_walk"
Write-Host "Native Pusfume hero preview enabled: $($HeroPreview.IsPresent)"
Write-Host "Native Pusfume first-person arms enabled: $firstPersonEnabled format=$FirstPersonFormat"
