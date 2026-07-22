param(
    [string]$InputBsi = ".build\compiler-fixture\pusfume_bsi_probe\units\pusfume_probe\pusfume_3p.bsi",
    [string]$ModelFbx = ".build\pusfume_handoff\pusfume_3p.fbx",
    [string]$AnimationFbx = ".build\pusfume_handoff\pusfume_3p_walk.fbx",
    [string]$IdleAnimationFbx = "",
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    [string]$FirstPersonBlend = "",
    [string]$FirstPersonDonorUnit = "",
    [string]$VersusFirstPersonBlend = "",
    [string]$VersusFirstPersonDonorUnit = "",
    [ValidateSet("bsi", "fbx")]
    [string]$FirstPersonFormat = "bsi",
    [string]$TextureSource = ".build\pusfume_handoff\textures conv",
    [string]$GameBundleDir = "C:\Program Files (x86)\Steam\steamapps\common\Warhammer Vermintide 2\bundle",
    [string]$UnpackerExe = "C:\Tools\vt2_bundle_unpacker\target\release\unpacker.exe",
    [string]$VmbLauncherExe = "C:\Users\danjo\source\repos\vermintide-2-tweaker\tools\vmb-launcher\bin\Release\net9.0-windows\win-x64\publish\VMBLauncher.exe",
    [string]$VmbLauncherSettings = ".build\vmb-pusfume-settings.json",
    [switch]$LegacyFur,
    [switch]$IntegratedFur,
    [string]$LegacyFurRoot = ".build\reference_legacy_pusfume",
    [double]$BodyDiffuseGain = 1.2,
    [double]$FurDiffuseGain = 0.55,
    [switch]$HeroPreview,
    [switch]$ParentChildMaterial,
    [switch]$NoDonorTextureShadow,
    [switch]$SplicedGameChild,
    [switch]$EmissionProbe,
    [switch]$UseBsiSkinFallback,
    [switch]$Upload,
    [switch]$NoRemote,
    [switch]$NoDeploy
)

$ErrorActionPreference = "Stop"

function Invoke-HiddenTool {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string[]]$ArgumentList,
        [string]$WorkingDirectory = "",
        [string]$StandardInput = ""
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = -not [string]::IsNullOrEmpty($StandardInput)
    $startInfo.WorkingDirectory = if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        (Get-Location).Path
    } else {
        $WorkingDirectory
    }

    foreach ($argument in $ArgumentList) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            throw "Failed to start hidden tool: $FilePath"
        }

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if ($startInfo.RedirectStandardInput) {
            $process.StandardInput.Write($StandardInput)
            $process.StandardInput.Close()
        }

        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()

        if (-not [string]::IsNullOrWhiteSpace($stdout)) {
            Write-Host $stdout.TrimEnd()
        }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            Write-Host $stderr.TrimEnd()
        }

        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            ProcessId = $process.Id
            MainWindowHandle = $process.MainWindowHandle
            Stdout = $stdout
            Stderr = $stderr
        }
    }
    finally {
        $process.Dispose()
    }
}

function Assert-HiddenToolSuccess {
    param(
        [Parameter(Mandatory)]
        [psobject]$Result,
        [Parameter(Mandatory)]
        [string]$Operation
    )

    if ($Result.ExitCode -ne 0) {
        throw "$Operation failed with exit code $($Result.ExitCode)"
    }
}

function Invoke-HiddenPython {
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    return Invoke-HiddenTool -FilePath "py.exe" -ArgumentList $ArgumentList
}

if ($Upload -and $NoDeploy) {
    throw "Upload requires deployment; remove -NoDeploy"
}
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
if ($LegacyFur) {
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
# Opt-in emission-channel A/B probe. It edits the spliced body child's atlases
# and sets a red emissive tint, so it only makes sense on the Track D path.
if ($EmissionProbe -and -not $SplicedGameChild) {
    throw "EmissionProbe requires -SplicedGameChild (it probes the spliced body child)"
}
if ($ParentChildMaterial -and -not $NoDonorTextureShadow) {
    throw "Parent-child and ordered texture-shadow experiments are mutually exclusive; add -NoDonorTextureShadow"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourceMod = Join-Path $repoRoot "pusfume"
$firstPersonEnabled = -not [string]::IsNullOrWhiteSpace($FirstPersonBlend)
$versusFirstPersonEnabled = -not [string]::IsNullOrWhiteSpace($VersusFirstPersonBlend)
if ($firstPersonEnabled -and -not $SplicedGameChild) {
    throw "FirstPersonBlend requires -SplicedGameChild for the proven skinned material binding"
}
$versusFirstPersonBlendPath = $null
$versusFirstPersonDonorUnitPath = $null
if ($versusFirstPersonEnabled -and -not $firstPersonEnabled) {
    throw "VersusFirstPersonBlend requires the hero-compatible FirstPersonBlend"
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
if ($versusFirstPersonEnabled) {
    if ([string]::IsNullOrWhiteSpace($VersusFirstPersonDonorUnit)) {
        throw "VersusFirstPersonBlend requires -VersusFirstPersonDonorUnit for the exact Skaven rest-skeleton rebind"
    }
    $versusFirstPersonBlendPath = if ([IO.Path]::IsPathRooted($VersusFirstPersonBlend)) {
        (Resolve-Path $VersusFirstPersonBlend).Path
    } else {
        (Resolve-Path (Join-Path $repoRoot $VersusFirstPersonBlend)).Path
    }
    if ([IO.Path]::GetExtension($versusFirstPersonBlendPath) -ine ".blend") {
        throw "VersusFirstPersonBlend must be a Blender source file: $versusFirstPersonBlendPath"
    }
    $versusFirstPersonDonorUnitPath = if ([IO.Path]::IsPathRooted($VersusFirstPersonDonorUnit)) {
        (Resolve-Path $VersusFirstPersonDonorUnit).Path
    } else {
        (Resolve-Path (Join-Path $repoRoot $VersusFirstPersonDonorUnit)).Path
    }
    if ([IO.Path]::GetExtension($versusFirstPersonDonorUnitPath) -ine ".unit") {
        throw "VersusFirstPersonDonorUnit must be an extracted compiled VT2 unit: $versusFirstPersonDonorUnitPath"
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
    if (-not (Test-Path -LiteralPath $legacyFurPath -PathType Leaf)) {
        throw "Dalokraff legacy fur FBX is missing: $legacyFurPath"
    }
    if (-not (Test-Path -LiteralPath $legacyBodyPath -PathType Leaf)) {
        throw "Dalokraff legacy body FBX is missing: $legacyBodyPath"
    }
    if (-not (Test-Path -LiteralPath $legacyLicense -PathType Leaf) -or
            (Get-Content -LiteralPath $legacyLicense -Raw) -notmatch
                'MIT License[\s\S]*Copyright \(c\) 2022 dalokraff') {
        throw "Dalokraff legacy fur license/provenance contract is missing"
    }
} elseif ($IntegratedFur) {
    $thirdPartyNotices = Join-Path $repoRoot "THIRD_PARTY_NOTICES.md"
    if (-not (Test-Path -LiteralPath $thirdPartyNotices -PathType Leaf) -or
            (Get-Content -LiteralPath $thirdPartyNotices -Raw) -notmatch
                'MIT License[\s\S]*Copyright \(c\) 2022 dalokraff') {
        throw "Tracked Dalokraff integrated-fur attribution is missing"
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
    $firstPersonArguments = @(
        "--background", "--factory-startup", "--disable-autoexec",
        "--python", $firstPersonTool, "--",
        $firstPersonBlendPath, $firstPersonDonorUnitPath, $firstPersonAssetPath,
        "--align-native-hero-grips")
    $result = Invoke-HiddenTool -FilePath $blenderExePath `
        -ArgumentList $firstPersonArguments
    Assert-HiddenToolSuccess $result `
        "First-person Pusfume $($FirstPersonFormat.ToUpperInvariant()) preparation"
    if ((Get-FileHash -LiteralPath $firstPersonBlendPath -Algorithm SHA256).Hash -ne $sourceBlendHash) {
        throw "First-person preparation modified its source blend: $firstPersonBlendPath"
    }
    if (-not (Test-Path -LiteralPath $firstPersonAssetPath -PathType Leaf) -or `
            (Get-Item -LiteralPath $firstPersonAssetPath).Length -lt 1024) {
        throw "First-person Pusfume $($FirstPersonFormat.ToUpperInvariant()) preparation produced no usable output"
    }
}

$versusFirstPersonAssetPath = $null
if ($versusFirstPersonEnabled) {
    $versusFirstPersonExtension = if ($FirstPersonFormat -eq "bsi") { "bsi" } else { "fbx" }
    $versusFirstPersonAssetPath = Join-Path $generatedRoot "pusfume_1p_versus_arms.$versusFirstPersonExtension"
    $versusFirstPersonTool = if ($FirstPersonFormat -eq "bsi") {
        Join-Path $repoRoot "tools\prepare_pusfume_1p_bsi.py"
    } else {
        Join-Path $repoRoot "tools\prepare_pusfume_1p_blend.py"
    }
    $sourceBlendHash = (Get-FileHash -LiteralPath $versusFirstPersonBlendPath -Algorithm SHA256).Hash

    $result = Invoke-HiddenTool -FilePath $blenderExePath -ArgumentList @(
        "--background", "--factory-startup", "--disable-autoexec",
        "--python", $versusFirstPersonTool, "--",
        $versusFirstPersonBlendPath, $versusFirstPersonDonorUnitPath,
        $versusFirstPersonAssetPath)
    Assert-HiddenToolSuccess $result `
        "Versus first-person Pusfume $($FirstPersonFormat.ToUpperInvariant()) preparation"
    if ((Get-FileHash -LiteralPath $versusFirstPersonBlendPath -Algorithm SHA256).Hash -ne $sourceBlendHash) {
        throw "Versus first-person preparation modified its source blend: $versusFirstPersonBlendPath"
    }
    if (-not (Test-Path -LiteralPath $versusFirstPersonAssetPath -PathType Leaf) -or `
            (Get-Item -LiteralPath $versusFirstPersonAssetPath).Length -lt 1024) {
        throw "Versus first-person preparation produced no usable output"
    }
}

$idleFbxPath = Join-Path $generatedRoot "pusfume_3p_idle.fbx"
if ([string]::IsNullOrWhiteSpace($IdleAnimationFbx)) {
    $idleFbxTool = Join-Path $repoRoot "tools\generate_idle_pusfume_fbx.py"
    $result = Invoke-HiddenTool -FilePath $blenderExePath -ArgumentList @(
        "--background", "--factory-startup", "--disable-autoexec",
        "--python", $idleFbxTool, "--", $modelFbxPath, $idleFbxPath)
    Assert-HiddenToolSuccess $result "Idle Pusfume FBX generation"
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
$result = Invoke-HiddenTool -FilePath $blenderExePath -ArgumentList @(
    "--background", "--factory-startup", "--disable-autoexec",
    "--python", $animationContractTool, "--",
    $modelFbxPath, $idleFbxPath, $animationFbxPath)
Assert-HiddenToolSuccess $result "Pusfume animation contract validation"

$animatedModelFbxPath = $modelFbxPath
if ($useFbxDcc) {
    $animatedFbxTool = Join-Path $repoRoot "tools\prepare_animated_pusfume_fbx.py"
    $animatedModelFbxPath = Join-Path $generatedRoot "pusfume_3p_animated.fbx"

    $animatedArguments = @(
        "--background", "--factory-startup", "--disable-autoexec",
        "--python", $animatedFbxTool, "--",
        $modelFbxPath, $animationFbxPath, $animatedModelFbxPath)
    if ($LegacyFur) {
        $animatedArguments += @($legacyFurPath, $legacyBodyPath)
    }
    $result = Invoke-HiddenTool -FilePath $blenderExePath `
        -ArgumentList $animatedArguments
    Assert-HiddenToolSuccess $result "Animated Pusfume FBX preparation"
    if (-not (Test-Path -LiteralPath $animatedModelFbxPath -PathType Leaf) -or `
            (Get-Item -LiteralPath $animatedModelFbxPath).Length -lt 1024) {
        throw "Animated Pusfume FBX preparation produced no usable output"
    }
}
$stageRoot = Join-Path $repoRoot ".build\native-workshop"
$stageMod = Join-Path $stageRoot "pusfume"
$vmbLauncherCandidate = if ([IO.Path]::IsPathRooted($VmbLauncherExe)) {
    $VmbLauncherExe
} else {
    Join-Path $repoRoot $VmbLauncherExe
}
$vmbLauncherPath = (Resolve-Path $vmbLauncherCandidate).Path
$vmbLauncherSettingsPath = if ([IO.Path]::IsPathRooted($VmbLauncherSettings)) {
    [IO.Path]::GetFullPath($VmbLauncherSettings)
} else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $VmbLauncherSettings))
}

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

# Mirror VMBLauncher's machine settings into ignored staging and bind only the
# ProjectRoot. This preserves its canonical SDK, Workshop, and enabled-remote
# configuration without mutating the user's live GUI settings.
$globalLauncherSettings = Join-Path $env:APPDATA "VMBLauncher\settings.json"
if (-not (Test-Path -LiteralPath $globalLauncherSettings -PathType Leaf)) {
    throw "VMBLauncher settings are missing: $globalLauncherSettings"
}
if ([IO.Path]::GetFullPath($globalLauncherSettings) -eq
        [IO.Path]::GetFullPath($vmbLauncherSettingsPath)) {
    throw "Staged VMBLauncher settings must not overwrite the live GUI settings"
}
$launcherSettings = Get-Content -LiteralPath $globalLauncherSettings -Raw |
    ConvertFrom-Json
if ($launcherSettings.PSObject.Properties.Name -contains "ProjectRoot") {
    $launcherSettings.ProjectRoot = $resolvedStageRoot
} else {
    $launcherSettings | Add-Member -NotePropertyName ProjectRoot `
        -NotePropertyValue $resolvedStageRoot
}
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName(
    $vmbLauncherSettingsPath)) -Force | Out-Null
$launcherSettingsJson = $launcherSettings | ConvertTo-Json -Depth 20
$utf8NoBom = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText(
    $vmbLauncherSettingsPath, $launcherSettingsJson, $utf8NoBom)

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
if ($versusFirstPersonEnabled) {
    Copy-Item -LiteralPath $versusFirstPersonAssetPath `
        -Destination (Join-Path $unitRoot "pusfume_1p_versus_arms.$FirstPersonFormat") -Force
    if ($FirstPersonFormat -eq "bsi") {
        $versusFirstPersonBonesPath = [IO.Path]::ChangeExtension($versusFirstPersonAssetPath, ".bones")
        Copy-Item -LiteralPath $versusFirstPersonBonesPath `
            -Destination (Join-Path $unitRoot "pusfume_1p_versus_arms.bones") -Force
    } else {
    @'
_data_root_version = 1
_id = "274e72fd-bfb1-486b-95c4-6e58bfc3d592"
_name = "units/pusfume/pusfume_1p_versus_arms"
asset = "units/pusfume/pusfume_1p_versus_arms"
extension = ".fbx"
'@ | Set-Content -LiteralPath (Join-Path $unitRoot "pusfume_1p_versus_arms.dcc_asset") -Encoding utf8
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
    # Diffuse and normal maps compile as BC7 to match Fatshark's own SDK
    # normal-map treatment (endurance_badges *_nm.texture ships format="BC7").
    # BC7 is the same 8 bpp as DXT5 (no bundle-size cost) but carries ~8-bit
    # RGB precision instead of DXT5's 5:6:5, recovering normal/diffuse detail,
    # and its alpha still carries the donor's gloss-in-alpha channel. Specular
    # and mask maps stay DXT5.
    $format = if ($Name.EndsWith("df") -or $Name.EndsWith("nm")) {
        "BC7"
    } else {
        "DXT5"
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
        format = "$format"
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
    # See Write-NativeTexture: diffuse/normal atlases compile as BC7 (same 8 bpp
    # as DXT5, higher RGB precision, gloss-in-alpha preserved); specular stays
    # DXT5. Matches the atlas the spliced Globadier child samples for the body.
    $format = if ($Name.EndsWith("df") -or $Name.EndsWith("nm")) {
        "BC7"
    } else {
        "DXT5"
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
        format = "$format"
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
    $opaqueGainAttributes = $null
    if ($forceOpaque) {
        $opaqueAttributes = New-Object Drawing.Imaging.ImageAttributes
        $opaqueMatrix = New-Object Drawing.Imaging.ColorMatrix
        $opaqueMatrix.Matrix33 = 0
        $opaqueMatrix.Matrix43 = 1
        $opaqueAttributes.SetColorMatrix($opaqueMatrix)
        if ($Suffix -eq "df") {
            # BodyDiffuseGain applies to the body tile ONLY; the outfit tiles
            # (globadier/armor/metal/ammo) keep their authored brightness
            # instead of a 1.2x highlight-clipping boost.
            $opaqueGainAttributes = New-Object Drawing.Imaging.ImageAttributes
            $gainMatrix = New-Object Drawing.Imaging.ColorMatrix
            $gainMatrix.Matrix00 = $BodyDiffuseGain
            $gainMatrix.Matrix11 = $BodyDiffuseGain
            $gainMatrix.Matrix22 = $BodyDiffuseGain
            $gainMatrix.Matrix33 = 0
            $gainMatrix.Matrix43 = 1
            $opaqueGainAttributes.SetColorMatrix($gainMatrix)
        }
    }

    function Draw-AtlasTile {
        param(
            [string]$Texture,
            [int]$X,
            [int]$Y,
            [int]$Width,
            [int]$Height,
            [bool]$ApplyGain = $false
        )

        $sourcePath = Join-Path $textureSourcePath "$Texture.png"
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Required Pusfume atlas texture is missing: $sourcePath"
        }

        $source = [Drawing.Image]::FromFile($sourcePath)
        try {
            $top = $atlasSize - $Y - $Height
            if ($forceOpaque) {
                $tileAttributes = if ($ApplyGain -and $null -ne $opaqueGainAttributes) {
                    $opaqueGainAttributes
                } else {
                    $opaqueAttributes
                }
                $destination = New-Object Drawing.Rectangle($X, $top, $Width, $Height)
                $graphics.DrawImage(
                    $source, $destination, 0, 0, $source.Width, $source.Height,
                    [Drawing.GraphicsUnit]::Pixel, $tileAttributes)
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
                        $width $height ($tileProperty.Name -eq "body")
                }
            }
        }

        $output = Join-Path $textureRoot "$Name.png"
        $atlas.Save($output, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        if ($null -ne $opaqueAttributes) {
            $opaqueAttributes.Dispose()
        }
        if ($null -ne $opaqueGainAttributes) {
            $opaqueGainAttributes.Dispose()
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

function Set-PusfumeEmissionProbe {
    # Opt-in A/B diagnostic (-EmissionProbe). Zero one channel of a composed
    # atlas everywhere, then stamp a solid blob back into one region, so exactly
    # that region can self-illuminate through that channel once the splice sets a
    # red emissive tint. Blue mode targets the normal atlas's blue; alpha mode
    # targets the MA atlas's alpha. Never called on a normal build.
    param(
        [Parameter(Mandatory)][string]$AtlasPath,
        [Parameter(Mandatory)][ValidateSet("blue", "alpha")][string]$Channel,
        [Parameter(Mandatory)][int]$BlobX,
        [Parameter(Mandatory)][int]$BlobY,
        [Parameter(Mandatory)][int]$BlobWidth,
        [Parameter(Mandatory)][int]$BlobHeight
    )

    Add-Type -AssemblyName System.Drawing
    $source = [Drawing.Image]::FromFile($AtlasPath)
    try {
        $width = $source.Width
        $height = $source.Height
        $output = New-Object Drawing.Bitmap($width, $height, `
            [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($output)
        $attributes = New-Object Drawing.Imaging.ImageAttributes
        $matrix = New-Object Drawing.Imaging.ColorMatrix
        # Zero the probed channel across the whole atlas; the blob re-adds it in
        # exactly one region so only that region can emit.
        if ($Channel -eq "blue") { $matrix.Matrix22 = 0 } else { $matrix.Matrix33 = 0 }
        $attributes.SetColorMatrix($matrix)
        try {
            $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
            $full = New-Object Drawing.Rectangle(0, 0, $width, $height)
            $graphics.DrawImage($source, $full, 0, 0, $width, $height, `
                [Drawing.GraphicsUnit]::Pixel, $attributes)
            # SourceCopy overwrites the blob outright: blue mode writes B=255,
            # alpha mode writes A=255. The blob's other channels go neutral,
            # acceptable for a throwaway diagnostic build.
            $blobColor = if ($Channel -eq "blue") {
                [Drawing.Color]::FromArgb(255, 0, 0, 255)
            } else {
                [Drawing.Color]::FromArgb(255, 0, 255, 0)
            }
            $brush = New-Object Drawing.SolidBrush($blobColor)
            try {
                $graphics.FillRectangle($brush, $BlobX, $BlobY, $BlobWidth, $BlobHeight)
            } finally {
                $brush.Dispose()
            }
            $output.Save($AtlasPath, [Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $attributes.Dispose()
            $graphics.Dispose()
            $output.Dispose()
        }
    } finally {
        $source.Dispose()
    }
}

function Set-PusfumeEmissionMask {
    # Emission on this character rides the MA atlas ALPHA channel - confirmed
    # in-game 2026-07-19 (v0.6.40 screenshot): with the _s tile alphas passed
    # through, the whole body self-illuminated and ONLY the eyes were dark
    # (the eye tile has no _s source, so its MA alpha stayed at the cleared 0) -
    # the exact inverse of intent. That settles the A/B test: the game shader
    # reads MA.alpha, NOT normal.blue. Janfon's normal-blue claim described his
    # Blender ubershader, not the shipped game shader (disproven here).
    #
    # This helper zeros the emission channel across a whole atlas so no tile's
    # source alpha/blue leaks in, then optionally stamps skaven_eyemask (the eye
    # emission-strength mask) into the eye tile, tiled to the layout cells. Used:
    #   - MA atlas, channel "alpha", -StampEye: kills the body/outfit glow and
    #     lights only the eyes; the eye cells keep RGB at the neutral MA clear
    #     (metallic=0 / AO=255 / B=255) with alpha = mask.
    #   - normal atlas, channel "blue", no stamp: keeps blue at 0 for vanilla
    #     parity (engine reconstructs Z from RG; donor E334 blue is 99.8% black),
    #     proven harmless in-game.
    param(
        [Parameter(Mandatory)][string]$AtlasPath,
        [Parameter(Mandatory)][ValidateSet("blue", "alpha")][string]$Channel,
        [switch]$StampEye,
        [string]$EyeMaskPath,
        [int]$AtlasSize,
        [int]$EyeOriginX,
        [int]$EyeOriginY,
        [int]$EyeCell,
        [int]$EyeGrid
    )

    Add-Type -AssemblyName System.Drawing
    $source = [Drawing.Image]::FromFile($AtlasPath)
    $mask = $null
    try {
        $width = $source.Width
        $height = $source.Height
        $output = New-Object Drawing.Bitmap($width, $height, `
            [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($output)
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        # 1) Zero the emission channel across the whole atlas.
        $zeroAttributes = New-Object Drawing.Imaging.ImageAttributes
        $zeroMatrix = New-Object Drawing.Imaging.ColorMatrix
        if ($Channel -eq "blue") { $zeroMatrix.Matrix22 = 0 } else { $zeroMatrix.Matrix33 = 0 }
        $zeroAttributes.SetColorMatrix($zeroMatrix)
        # 2) Optional eye stamp: route the mask luminance (source red) into the
        #    emission channel while pinning the other channels to neutral.
        $eyeAttributes = $null
        if ($StampEye) {
            $eyeAttributes = New-Object Drawing.Imaging.ImageAttributes
            $eyeMatrix = New-Object Drawing.Imaging.ColorMatrix
            $eyeMatrix.Matrix00 = 0
            $eyeMatrix.Matrix11 = 0
            $eyeMatrix.Matrix22 = 0
            $eyeMatrix.Matrix33 = 0
            if ($Channel -eq "blue") {
                $eyeMatrix.Matrix02 = 1   # source red -> blue (emission mask)
                $eyeMatrix.Matrix40 = 0.5 # red   = 128 (flat normal x)
                $eyeMatrix.Matrix41 = 0.5 # green = 128 (flat normal y)
                $eyeMatrix.Matrix43 = 1   # alpha = 255 (gloss)
            } else {
                $eyeMatrix.Matrix03 = 1   # source red -> alpha (emission mask)
                $eyeMatrix.Matrix41 = 1   # green = 255 (AO neutral)
                $eyeMatrix.Matrix42 = 1   # blue  = 255 (unused neutral)
                # red stays 0 (metallic neutral); alpha diagonal zeroed above.
            }
            $eyeAttributes.SetColorMatrix($eyeMatrix)
        }
        try {
            $full = New-Object Drawing.Rectangle(0, 0, $width, $height)
            $graphics.DrawImage($source, $full, 0, 0, $width, $height, `
                [Drawing.GraphicsUnit]::Pixel, $zeroAttributes)
            # GDI+ keeps the FromFile handle locked; release it before Save
            # targets the same path or Save throws a generic GDI+ error.
            $source.Dispose()
            $source = $null
            if ($StampEye) {
                $mask = [Drawing.Image]::FromFile($EyeMaskPath)
                foreach ($row in 0..($EyeGrid - 1)) {
                    foreach ($column in 0..($EyeGrid - 1)) {
                        $cellX = $EyeOriginX + $column * $EyeCell
                        $cellY = $EyeOriginY + $row * $EyeCell
                        $top = $AtlasSize - $cellY - $EyeCell
                        $cell = New-Object Drawing.Rectangle($cellX, $top, $EyeCell, $EyeCell)
                        $graphics.DrawImage($mask, $cell, 0, 0, $mask.Width, $mask.Height, `
                            [Drawing.GraphicsUnit]::Pixel, $eyeAttributes)
                    }
                }
            }
            $output.Save($AtlasPath, [Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $zeroAttributes.Dispose()
            if ($null -ne $eyeAttributes) { $eyeAttributes.Dispose() }
            $graphics.Dispose()
            $output.Dispose()
        }
    } finally {
        if ($null -ne $mask) { $mask.Dispose() }
        if ($null -ne $source) { $source.Dispose() }
    }
}

Write-PusfumeAtlas "pusfume_atlas_df" "df" ([Drawing.Color]::Black)
Write-PusfumeAtlas "pusfume_atlas_nm" "nm" ([Drawing.Color]::FromArgb(255, 128, 128, 255))
Write-PusfumeAtlas "pusfume_atlas_s" "s" ([Drawing.Color]::Black)
# MA (metallic / AO / unused / mask) atlas fed to the spliced body child's third
# slot (channel 909D00F3, build alias texture_map_27b67fd2). Verified against the
# installed Globadier's own MA texture 45FFAEEF53695A86 (BC3/DXT5, dxgi=77):
# R=metallic, G=AO, B=255 unused, A = the EMISSION mask; Fatshark's "M/AO/x/EM"
# packing. Janfon's _s maps carry the same R/G order (skaven_body_s: R=0 skin
# non-metal, G high), so the s-suffix sources compose straight in for metallic +
# AO. Emission rides THIS slot's ALPHA - confirmed in-game 2026-07-19 v0.6.40:
# letting the _s alphas pass through lit the whole body and left the eyes dark
# (normal.blue was disproven). So Set-PusfumeEmissionMask later zeros this alpha
# and stamps ONLY the eye mask into it. The clear is the neutral value
# metallic=0 / AO=255 / B=255 / alpha=0.
Write-PusfumeAtlas "pusfume_atlas_ma" "s" ([Drawing.Color]::FromArgb(0, 0, 255, 255))
Write-NativeTextureRecipe "pusfume_atlas_df" $true
Write-NativeTextureRecipe "pusfume_atlas_nm" $false
Write-NativeTextureRecipe "pusfume_atlas_s" $false
Write-NativeTextureRecipe "pusfume_atlas_ma" $false

if ($EmissionProbe) {
    # Emission-channel A/B probe. Split the body atlas tile (left half, image
    # region 0..2048 x 0..4096) into two disjoint halves and light each through a
    # different donor channel: the normal atlas's BLUE gets the TOP half, the MA
    # atlas's ALPHA gets the BOTTOM half, and the splice sets a red emissive
    # tint. In game, whichever body half glows red identifies the channel the
    # shader honors (top -> normal.blue; bottom -> MA.alpha; both -> both
    # contribute; neither -> emission rides a third path). Only the two atlas
    # PNGs are rewritten; the compiled-material splice, package list, texture
    # recipes, and every other build path are byte-identical to a normal build.
    Set-PusfumeEmissionProbe -AtlasPath (Join-Path $textureRoot "pusfume_atlas_nm.png") `
        -Channel "blue" -BlobX 0 -BlobY 0 -BlobWidth 2048 -BlobHeight 2048
    Set-PusfumeEmissionProbe -AtlasPath (Join-Path $textureRoot "pusfume_atlas_ma.png") `
        -Channel "alpha" -BlobX 0 -BlobY 2048 -BlobWidth 2048 -BlobHeight 2048
    Write-Host ("EMISSION PROBE ACTIVE: normal.blue mask = body-tile TOP half, " +
        "MA.alpha mask = body-tile BOTTOM half, emissive tint = red [25,0,0]. " +
        "This is a DIAGNOSTIC build, not a shippable candidate.")
} elseif ($SplicedGameChild) {
    # Shipped emission (Janfon: the eyes are the ONLY emissive on the character;
    # the red arm is plain diffuse). The game reads emission from MA.alpha, so
    # zero the MA alpha - otherwise the body/outfit _s alphas light the whole
    # model - then stamp the eye mask into the eye tile's MA alpha. The normal
    # atlas keeps its blue zeroed for vanilla parity (no stamp). Eye tile
    # geometry is read from the layout so it always tracks the df/s cells.
    $eyeLayout = Get-Content -LiteralPath (Join-Path $repoRoot `
        "tools\pusfume_atlas_layout.json") -Raw | ConvertFrom-Json
    $eyeTile = $eyeLayout.tiles.eye
    Set-PusfumeEmissionMask `
        -AtlasPath (Join-Path $textureRoot "pusfume_atlas_ma.png") -Channel "alpha" -StampEye `
        -EyeMaskPath (Join-Path $textureSourcePath "skaven_eyemask.png") `
        -AtlasSize ([int]$eyeLayout.atlas_size) `
        -EyeOriginX ([int]$eyeTile.origin[0]) -EyeOriginY ([int]$eyeTile.origin[1]) `
        -EyeCell ([int]$eyeTile.size[0]) -EyeGrid ([int]$eyeTile.grid[0])
    Set-PusfumeEmissionMask `
        -AtlasPath (Join-Path $textureRoot "pusfume_atlas_nm.png") -Channel "blue"
    Write-Host "Eye emission baked into MA.alpha (eye tile, 3x3); body/outfit MA alpha and normal blue zeroed."
}

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
if ($versusFirstPersonEnabled) {
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
'@ | Set-Content -LiteralPath (Join-Path $unitRoot "pusfume_1p_versus_arms.unit") -Encoding utf8
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
$versusFirstPersonUnitValue = if ($versusFirstPersonEnabled) {
    '"units/pusfume/pusfume_1p_versus_arms"'
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
# A custom blend makes the human rig the default controller, so the old
# all-Skaven fallback remains off. The separate dual-rig path keeps native
# role-specific Skaven arms resident only for Versus weapon families.
$nativeSkavenFirstPersonValue = if ($firstPersonEnabled) { "false" } else { "true" }
$dualFirstPersonRigsValue = if ($firstPersonEnabled -and $versusFirstPersonEnabled) { "true" } else { "false" }

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
    native_skaven_first_person = $nativeSkavenFirstPersonValue,
    dual_first_person_rigs = $dualFirstPersonRigsValue,
    first_person_unit = $firstPersonUnitValue,
    versus_first_person_unit = $versusFirstPersonUnitValue,
    hero_preview_enabled = $heroPreviewEnabled,
    hide_donor_weapons = false,
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
$versusFirstPersonUnitPackageEntry = if ($versusFirstPersonEnabled) {
    '    "units/pusfume/pusfume_1p_versus_arms"'
} else {
    ""
}

@"

unit = [
    "units/pusfume/pusfume_3p"
$firstPersonUnitPackageEntry
$versusFirstPersonUnitPackageEntry
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
        '    "textures/pusfume/pusfume_atlas_s"',
        '    "textures/pusfume/pusfume_atlas_ma"'
    )
}

@"

texture = [
$($rootTextureEntries -join "`n")
]
"@ | Add-Content -LiteralPath (Join-Path $stageMod `
    "resource_packages\pusfume\pusfume.package") -Encoding utf8

$result = Invoke-HiddenTool -FilePath $vmbLauncherPath -ArgumentList @(
    "build", "pusfume", "--clean", "--no-banner",
    "--config", $vmbLauncherSettingsPath)
Assert-HiddenToolSuccess $result "VMBLauncher native build"

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
if ($versusFirstPersonEnabled) {
    $requiredCompiledResources += "units/pusfume/pusfume_1p_versus_arms,unit,"
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
    $result = Invoke-HiddenPython @(
        $compiledRestTool, $compiledFirstPersonUnit, $firstPersonDonorUnitPath)
    Assert-HiddenToolSuccess $result `
        "Compiled first-person rest-skeleton validation"
}
if ($versusFirstPersonEnabled) {
    $versusFirstPersonCompiledMatch = [regex]::Match(
        $debugIndexText,
        '"(data/[^"\r\n]+)"\s*=\s*"units/pusfume/pusfume_1p_versus_arms\.unit"')
    if (-not $versusFirstPersonCompiledMatch.Success) {
        throw "Compiled debug index omitted the Versus first-person arms unit"
    }

    $compiledVersusFirstPersonUnit = Join-Path $stageRoot (
        ".temp\pusfumeV2\compile\" +
        $versusFirstPersonCompiledMatch.Groups[1].Value.Replace('/', '\'))
    $result = Invoke-HiddenPython @(
        $compiledRestTool, $compiledVersusFirstPersonUnit,
        $versusFirstPersonDonorUnitPath)
    Assert-HiddenToolSuccess $result `
        "Compiled Versus first-person rest-skeleton validation"
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
        $result = Invoke-HiddenPython @(
            $stripTool, $bundleFile.FullName, "--type", "material",
            "--old", $donorParentPath, "--new",
            "units/pusfume/retired_stub_parent", "--dry-run")
        $dryOutput = @($result.Stdout, $result.Stderr)
        $found = 0
        if ($dryOutput -join "`n" -match '(\d+) occurrence') {
            $found = [int]$Matches[1]
        }

        if ($found -gt 0) {
            $result = Invoke-HiddenPython @(
                $stripTool, $bundleFile.FullName, "--type", "material",
                "--old", $donorParentPath, "--new",
                "units/pusfume/retired_stub_parent", "--expect", "$found")
            Assert-HiddenToolSuccess $result `
                "Stub strip on $($bundleFile.Name)"
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
        $result = Invoke-HiddenPython @(
            $stripTool, $bundleFile.FullName, "--type", "material",
            "--old", $donorParentPath, "--new",
            "units/pusfume/retired_stub_parent", "--expect", "0", "--dry-run")
        Assert-HiddenToolSuccess $result `
            "Stub identity verification on $($bundleFile.Name)"
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
    $result = Invoke-HiddenTool -FilePath $UnpackerExe -ArgumentList @(
        "extract", $donorGameBundle, $spliceExtractDir, "--flatten")
    Assert-HiddenToolSuccess $result "Globadier donor bundle extraction"
    $gameChildPath = Join-Path $spliceExtractDir "90BDF3BAC6F81BA8.material"
    if (-not (Test-Path -LiteralPath $gameChildPath -PathType Leaf)) {
        throw "Donor bundle extraction did not produce 90BDF3BAC6F81BA8.material"
    }

    # Slot semantics: names resolved by matching the donor child's texture keys
    # to the parent shader's __tex_ bindings (3D25339231384C80.shader), plus a
    # channel-content decode of the vanilla textures (2026-07-19). The child's
    # three character textures are texture_map_02af90f8 (key F9292771) = diffuse
    # (DD74D8319F514D96); texture_map_8bf37d8e (key 9AD51991) = NORMAL, BC7,
    # with gloss in ALPHA and a clean localized mask in BLUE (donor B is 99.8%
    # black); texture_map_27b67fd2 (key 909D00F3) = MA (45FFAEEF53695A86, DXT5):
    # R=metallic, G=AO, B=unused, A a clean localized mask. The other four child
    # slots are shared engine defaults (vfx_mask_1/2, snow_mask, blood_decal) -
    # there is no dedicated per-character emission map. Earlier builds left slot
    # 3 on the Globadier's OWN MA (metal/AO baked to Globadier UVs, misaligned to
    # Pusfume) and zeroed the emissive tint C985395A. We now patch all three to
    # Pusfume atlases. The MA feed restores per-pixel metallic (peg leg/buckles)
    # from Janfon's _s.R and occlusion from _s.G (Janfon authors G as roughness;
    # the game slot reads G as AO - close enough, and true roughness still comes
    # from the normal alpha). EMISSIVE stays OFF (tint [0,0,0]): the game's
    # emissive mask is one of two clean donor masks (normal.B or MA.A) and the
    # bytecode wiring is unreadable, while Janfon's handoff has NO game-ready
    # emission mask (his normal.B is standard normal-Z, his _s.A is a TINT mask
    # per his V2 Ubershader graph). Lighting the red arm needs Janfon's emission
    # mask + an in-game A/B test of which channel the shader reads - see report.
    # Emissive tint (C985395A). The mask is the eyes (baked into MA.alpha by
    # Set-PusfumeEmissionMask), so this tint colours the eye glow. Hue is taken
    # from Janfon's authored eye colour pusfume_eyenormal (dominant 138,9,2 =
    # a warpstone red), its 138:9:2 ratio scaled so the red channel is ~15 HDR -
    # the middle of the donor's own emissive_color magnitudes (green was
    # [14.2,25.3,2]) - giving a visible bloom without blowing out. TUNABLE: raise
    # the scale for a hotter glow. Under -EmissionProbe use an obvious flat red.
    $bodyEmissiveColor = if ($EmissionProbe) {
        "emissive_color=25,0,0"
    } else {
        "emissive_color=15,1,0.2"
    }
    $splicePayload = Join-Path $generatedRoot "spliced_child_payload.bin"
    $result = Invoke-HiddenPython @(
        (Join-Path $repoRoot "tools\make_spliced_child.py"),
        "--extracted", $gameChildPath,
        "--resource", "hash:90BDF3BAC6F81BA8", "--expect-size", "768",
        "--expect-parent", "3D25339231384C80",
        "--map", "DD74D8319F514D96=C263ECB79A8DCEC0",
        "--map", "E334A8CB6BCB5E6D=A4215592F6297E57",
        "--map", "45FFAEEF53695A86=818C87B860407405",
        "--set-variable", $bodyEmissiveColor,
        "--expect-texture", "texture_map_02af90f8=C263ECB79A8DCEC0",
        "--expect-texture", "texture_map_27b67fd2=818C87B860407405",
        "--expect-texture", "texture_map_8bf37d8e=A4215592F6297E57",
        "--out", $splicePayload)
    Assert-HiddenToolSuccess $result "Spliced child payload generation"

    $spliceTool = Join-Path $repoRoot "tools\splice_bundle_resource.py"
    $childId = "hash:F72D636600F7F598"
    $splicedInto = @()

    foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
        $result = Invoke-HiddenPython @(
            $spliceTool, $bundleFile.FullName, "--type", "material",
            "--name", $childId, "--payload", $splicePayload, "--dry-run")
        if ($result.ExitCode -eq 0) {
            $result = Invoke-HiddenPython @(
                $spliceTool, $bundleFile.FullName, "--type", "material",
                "--name", $childId, "--payload", $splicePayload)
            Assert-HiddenToolSuccess $result "Splice on $($bundleFile.Name)"
            $splicedInto += $bundleFile.Name
        }
    }

    if ($splicedInto.Count -ne 1) {
        throw "Expected the compiled child in exactly 1 bundle, spliced $($splicedInto.Count)"
    }

    Write-Host "Spliced game child payload (768 bytes, atlas texture ids) into $($splicedInto[0])"

    if ($firstPersonEnabled) {
        # Keep the payload that rendered Janfon's direct-UV maps correctly in
        # live tests. The native human 1P payload was isolated in v0.6.51 and
        # produced black, mirror-like arms despite correct resource loading.
        $firstPersonPayload = Join-Path $generatedRoot "spliced_1p_child_payload.bin"
        $result = Invoke-HiddenPython @(
            (Join-Path $repoRoot "tools\make_spliced_child.py"),
            "--extracted", $gameChildPath,
            "--resource", "hash:90BDF3BAC6F81BA8", "--expect-size", "768",
            "--expect-parent", "3D25339231384C80",
            "--map", "DD74D8319F514D96=E0C4E09D80AE735B",
            "--map", "E334A8CB6BCB5E6D=3B3F6545AF6782F5",
            "--set-variable", "emissive_color=0,0,0",
            "--expect-texture", "texture_map_02af90f8=E0C4E09D80AE735B",
            "--expect-texture", "texture_map_27b67fd2=45FFAEEF53695A86",
            "--expect-texture", "texture_map_8bf37d8e=3B3F6545AF6782F5",
            "--out", $firstPersonPayload)
        Assert-HiddenToolSuccess $result `
            "Spliced first-person child payload generation"

        $firstPersonSplicedInto = @()
        foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
            $result = Invoke-HiddenPython @(
                $spliceTool, $bundleFile.FullName, "--type", "material",
                "--name", "child_materials/pusfume/pusfume_1p_body_child",
                "--payload", $firstPersonPayload, "--dry-run")
            if ($result.ExitCode -eq 0) {
                $result = Invoke-HiddenPython @(
                    $spliceTool, $bundleFile.FullName, "--type", "material",
                    "--name", "child_materials/pusfume/pusfume_1p_body_child",
                    "--payload", $firstPersonPayload)
                Assert-HiddenToolSuccess $result `
                    "First-person material splice on $($bundleFile.Name)"
                $firstPersonSplicedInto += $bundleFile.Name
            }
        }

        if ($firstPersonSplicedInto.Count -ne 1) {
            throw "Expected the first-person child in exactly 1 bundle, spliced $($firstPersonSplicedInto.Count)"
        }

        Write-Host "Spliced proven skinned 1P payload (768 bytes, direct UV maps) into $($firstPersonSplicedInto[0])"
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
    $result = Invoke-HiddenTool -FilePath $UnpackerExe -ArgumentList @(
        "extract", $laurelGameBundle, $laurelExtractDir, "--flatten",
        "--include", "*C70B1AAD3B363E24*")
    Assert-HiddenToolSuccess $result "Laurel donor bundle extraction"
    $laurelMaterialPath = Join-Path $laurelExtractDir "C70B1AAD3B363E24.material"
    if (-not (Test-Path -LiteralPath $laurelMaterialPath -PathType Leaf)) {
        throw "Laurel bundle extraction did not produce C70B1AAD3B363E24.material"
    }

    $whiskerPayload = Join-Path $generatedRoot "spliced_whisker_payload.bin"
    $result = Invoke-HiddenPython @(
        (Join-Path $repoRoot "tools\make_spliced_child.py"),
        "--extracted", $laurelMaterialPath,
        "--resource", "hash:C70B1AAD3B363E24", "--expect-size", "128",
        "--expect-parent", "F85B289742D5D69A",
        "--map", "C9CF19C214612D75=7F060B4938ADCF12",
        "--map", "CDA03B9B0226037A=950FC5950CCEBCD0",
        "--map", "D3FD8377A3DE498A=BEB4D8D9891A6D4A",
        "--expect-texture", "texture_map_c0ba2942=7F060B4938ADCF12",
        "--expect-texture", "texture_map_59cd86b9=950FC5950CCEBCD0",
        "--expect-texture", "texture_map_b788717c=BEB4D8D9891A6D4A",
        "--out", $whiskerPayload)
    Assert-HiddenToolSuccess $result `
        "Spliced Laurel whisker payload generation"

    $whiskerSplicedInto = @()
    foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
        $result = Invoke-HiddenPython @(
            $spliceTool, $bundleFile.FullName, "--type", "material",
            "--name", "child_materials/pusfume/pusfume_whiskers_child",
            "--payload", $whiskerPayload, "--dry-run")
        if ($result.ExitCode -eq 0) {
            $result = Invoke-HiddenPython @(
                $spliceTool, $bundleFile.FullName, "--type", "material",
                "--name", "child_materials/pusfume/pusfume_whiskers_child",
                "--payload", $whiskerPayload)
            Assert-HiddenToolSuccess $result `
                "Whisker material splice on $($bundleFile.Name)"
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
        $result = Invoke-HiddenPython @(
            (Join-Path $repoRoot "tools\make_spliced_child.py"),
            "--extracted", $laurelMaterialPath,
            "--resource", "hash:C70B1AAD3B363E24", "--expect-size", "128",
            "--expect-parent", "F85B289742D5D69A",
            "--map", "C9CF19C214612D75=20A7120B25F414F7",
            "--map", "CDA03B9B0226037A=57505EBDF932A68B",
            "--map", "D3FD8377A3DE498A=D7B1C45DEFA31C39",
            "--expect-texture", "texture_map_c0ba2942=20A7120B25F414F7",
            "--expect-texture", "texture_map_59cd86b9=57505EBDF932A68B",
            "--expect-texture", "texture_map_b788717c=D7B1C45DEFA31C39",
            "--out", $furPayload)
        Assert-HiddenToolSuccess $result "Spliced Laurel fur payload generation"

        $furSplicedInto = @()
        foreach ($bundleFile in (Get-ChildItem -LiteralPath $bundleRoot -Filter *.mod_bundle -File)) {
            $result = Invoke-HiddenPython @(
                $spliceTool, $bundleFile.FullName, "--type", "material",
                "--name", "child_materials/pusfume/pusfume_fur_child",
                "--payload", $furPayload, "--dry-run")
            if ($result.ExitCode -eq 0) {
                $result = Invoke-HiddenPython @(
                    $spliceTool, $bundleFile.FullName, "--type", "material",
                    "--name", "child_materials/pusfume/pusfume_fur_child",
                    "--payload", $furPayload)
                Assert-HiddenToolSuccess $result `
                    "Fur material splice on $($bundleFile.Name)"
                $furSplicedInto += $bundleFile.Name
            }
        }

        if ($furSplicedInto.Count -ne 1) {
            throw "Expected the fur child in exactly 1 bundle, spliced $($furSplicedInto.Count)"
        }

        Write-Host "Spliced Laurel feather payload (128 bytes, dalokraff fur maps) into $($furSplicedInto[0])"
    }
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
            $result = Invoke-HiddenPython @(
                $stripTool, $bundleFile.FullName, "--type", "texture", "--bare",
                "--old", $atlasPath, "--new-hash", $donorId, "--dry-run")
            $dryOutput = @($result.Stdout, $result.Stderr)
            $found = 0
            if ($dryOutput -join "`n" -match '(\d+) occurrence') {
                $found = [int]$Matches[1]
            }

            if ($found -gt 0) {
                $result = Invoke-HiddenPython @(
                    $stripTool, $bundleFile.FullName, "--type", "texture", "--bare",
                    "--old", $atlasPath, "--new-hash", $donorId,
                    "--expect", "$found")
                Assert-HiddenToolSuccess $result `
                    "Donor texture shadow rename on $($bundleFile.Name) for $atlasPath"
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
            $result = Invoke-HiddenPython @(
                $stripTool, $bundleFile.FullName, "--type", "texture", "--bare",
                "--old", $atlasPath, "--new-hash", $donorId,
                "--expect", "0", "--dry-run")
            Assert-HiddenToolSuccess $result `
                "Atlas identity verification on $($bundleFile.Name)"
        }

        Write-Host "Donor texture shadow: $atlasPath -> $donorId ($totalRenamed occurrence(s))"
    }
}

if (-not $NoDeploy) {
    $deployArguments = @(
        "deploy", "pusfume", "--no-banner",
        "--config", $vmbLauncherSettingsPath)
    if ($NoRemote) {
        $deployArguments += "--no-remote"
    }

    $result = Invoke-HiddenTool -FilePath $vmbLauncherPath `
        -ArgumentList $deployArguments
    Assert-HiddenToolSuccess $result "VMBLauncher verified deployment"
}

if ($Upload) {
    $workshopLog = "C:\Program Files (x86)\Steam\logs\workshop_log.txt"
    $uploadStarted = Get-Date
    $result = Invoke-HiddenTool -FilePath $vmbLauncherPath -ArgumentList @(
        "upload", "pusfume", "--no-banner",
        "--config", $vmbLauncherSettingsPath)
    Assert-HiddenToolSuccess $result "VMBLauncher friends-only Workshop upload"

    $manifestLine = Get-Content -LiteralPath $workshopLog -Tail 200 |
        Where-Object {
            $_ -match "Uploaded new content \( ManifestID (\d+) \) for item 3764954245"
        } | Select-Object -Last 1
    if (-not $manifestLine -or $manifestLine -notmatch
            "^\[(?<timestamp>[^]]+)\].*ManifestID (?<manifest>\d+)") {
        throw "Workshop upload returned success without a manifest confirmation for item 3764954245"
    }
    $manifestTime = [datetime]::Parse($matches.timestamp)
    if ($manifestTime -lt $uploadStarted.AddMinutes(-1)) {
        throw "Workshop manifest confirmation is stale: $manifestLine"
    }

    Write-Host "Steam confirmed Pusfume Workshop ManifestID $($matches.manifest) at $($matches.timestamp)"
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
Write-Host "Native Pusfume Versus first-person arms enabled: $versusFirstPersonEnabled format=$FirstPersonFormat"
