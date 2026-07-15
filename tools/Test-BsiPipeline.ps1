param(
    [Parameter(Mandatory = $true)]
    [string]$InputFbx,
    [string]$Blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$inputPath = (Resolve-Path $InputFbx).Path
$vmbPath = (Resolve-Path (Join-Path $repoRoot "..\vmb\vmb.js")).Path
$fixtureRoot = Join-Path $repoRoot ".build\compiler-fixture"
$modRoot = Join-Path $fixtureRoot "pusfume_bsi_probe"
$unitRoot = Join-Path $modRoot "units\pusfume_probe"
$packageRoot = Join-Path $modRoot "resource_packages"
$bsiPath = Join-Path $unitRoot "pusfume_3p.bsi"

if (-not (Test-Path -LiteralPath $Blender -PathType Leaf)) {
    throw "Blender executable not found: $Blender"
}

New-Item -ItemType Directory -Force $unitRoot, $packageRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot "pusfume\preview.png") `
    -Destination (Join-Path $modRoot "preview.png") -Force

@'
title = "Pusfume BSI Compiler Probe";
description = "Local compiler fixture. Never publish.";
preview = "preview.png";
content = "bundleV2";
language = "english";
visibility = "private";
published_id = 0L;
apply_for_sanctioned_status = false;
tags = [ ];
'@ | Set-Content -LiteralPath (Join-Path $modRoot "itemV2.cfg") -Encoding utf8

@'
return {
    run = function()
    end,
    packages = {
        "resource_packages/pusfume_bsi_probe",
    },
}
'@ | Set-Content -LiteralPath (Join-Path $modRoot "pusfume_bsi_probe.mod") -Encoding utf8

@'
unit = [
    "units/pusfume_probe/pusfume_3p"
]
'@ | Set-Content -LiteralPath (Join-Path $packageRoot "pusfume_bsi_probe.package") -Encoding utf8

@'
materials = []
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

& $Blender --background --factory-startup --disable-autoexec `
    --python (Join-Path $PSScriptRoot "export_blender_bsi.py") -- `
    $inputPath $bsiPath --compress --skin
if ($LASTEXITCODE -ne 0) {
    throw "Blender BSI export failed with exit code $LASTEXITCODE"
}

$buildArgs = @(
    $vmbPath, "build", "pusfume_bsi_probe", "-f", $fixtureRoot,
    "--rc", $repoRoot, "--no-workshop"
)
if ($Clean) {
    $buildArgs += "--clean"
}

& node @buildArgs
if ($LASTEXITCODE -ne 0) {
    throw "VT2 SDK compile failed with exit code $LASTEXITCODE"
}

$bundlePath = Join-Path $modRoot "bundleV2\0612a6f5087076f7.mod_bundle"
if (-not (Test-Path -LiteralPath $bundlePath -PathType Leaf)) {
    throw "SDK reported success but the compiler-probe bundle was not produced"
}

Write-Host "Pusfume skinned BSI compiler probe passed: $bundlePath"
