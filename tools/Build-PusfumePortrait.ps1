<#
.SYNOPSIS
    Imports Pusfume's canonical portrait and generates VT2 UI variants.

.DESCRIPTION
    Preserves the supplied source art under art_source, center-crops it to the
    110:130 VT2 portrait aspect ratio, and emits the three standalone Gui
    textures used by hero selection, HUD/scoreboard, and compact UI surfaces.
    HUD and compact alpha are borrowed from proven Dynamic Cosmetic Portraits
    masks so pixels cannot bleed outside vanilla frames.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePng,
    [string]$HudMask = "",
    [string]$SmallMask = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourcePath = (Resolve-Path $SourcePng).Path
$maskRoot = Join-Path $repoRoot "tools\portrait_masks"
New-Item -ItemType Directory -Force $maskRoot | Out-Null
if ([string]::IsNullOrWhiteSpace($HudMask)) {
    $HudMask = Join-Path $maskRoot "vanilla_hud_alpha_mask_86x108.png"
}
if ([string]::IsNullOrWhiteSpace($SmallMask)) {
    $SmallMask = Join-Path $maskRoot "vanilla_small_alpha_mask_60x70.png"
}

# Bootstrap the masks from the sibling, live-tested portrait project only on
# the maintainer machine. Clean clones use the committed local mask files.
$legacyPortraitRoot = Join-Path (Split-Path $repoRoot -Parent) `
    "vermintide-2-tweaker\dynamic_cosmetic_portraits"
$legacyMasks = @{
    $HudMask = Join-Path $legacyPortraitRoot "tools\vanilla_hud_alpha_mask_86x108.png"
    $SmallMask = Join-Path $legacyPortraitRoot `
        "gui\1080p\single_textures\custom_portraits\small_portrait_kruber_mercenary_hat_0001.png"
}
foreach ($target in $legacyMasks.Keys) {
    if (-not (Test-Path -LiteralPath $target)) {
        $legacy = $legacyMasks[$target]
        if (-not (Test-Path -LiteralPath $legacy)) {
            throw "Portrait mask is missing: $target"
        }
        [IO.File]::WriteAllBytes($target, [IO.File]::ReadAllBytes($legacy))
    }
}

$hudMaskPath = (Resolve-Path $HudMask).Path
$smallMaskPath = (Resolve-Path $SmallMask).Path
$sourceRoot = Join-Path $repoRoot "art_source\ui"
$textureRoot = Join-Path $repoRoot "pusfume\gui\1080p\single_textures\pusfume_portraits"
$materialRoot = Join-Path $repoRoot "pusfume\materials\ui"

New-Item -ItemType Directory -Force $sourceRoot, $textureRoot, $materialRoot | Out-Null
[IO.File]::WriteAllBytes((Join-Path $sourceRoot "pusfume_frame2.png"), [IO.File]::ReadAllBytes($sourcePath))

function New-ResizedBitmap {
    param(
        [System.Drawing.Image]$Source,
        [int]$Width,
        [int]$Height,
        [System.Drawing.Rectangle]$SourceRectangle
    )

    $result = [System.Drawing.Bitmap]::new($Width, $Height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($result)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($Source, [System.Drawing.Rectangle]::new(0, 0, $Width, $Height),
            $SourceRectangle, [System.Drawing.GraphicsUnit]::Pixel)
    } finally {
        $graphics.Dispose()
    }

    return $result
}

function Set-AlphaFromMask {
    param(
        [System.Drawing.Bitmap]$Image,
        [string]$MaskPath,
        [switch]$UseRedChannel
    )

    $mask = [System.Drawing.Bitmap]::FromFile($MaskPath)
    try {
        if ($mask.Width -ne $Image.Width -or $mask.Height -ne $Image.Height) {
            throw "Portrait mask is $($mask.Width)x$($mask.Height), expected $($Image.Width)x$($Image.Height): $MaskPath"
        }

        for ($y = 0; $y -lt $Image.Height; $y++) {
            for ($x = 0; $x -lt $Image.Width; $x++) {
                $rgb = $Image.GetPixel($x, $y)
                $maskPixel = $mask.GetPixel($x, $y)
                $alpha = if ($UseRedChannel) { $maskPixel.R } else { $maskPixel.A }
                $Image.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(
                    $alpha, $rgb.R, $rgb.G, $rgb.B))
            }
        }
    } finally {
        $mask.Dispose()
    }
}

function Write-PortraitMetadata {
    param([string]$Name)

    $texturePath = "gui/1080p/single_textures/pusfume_portraits/$Name"
    $texture = @"
common = {
	input = {
		filename = "$texturePath"
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
		srgb = true
		streamable = false
	}
}
"@
    $material = @"
$Name = {
	material_contexts = {
		surface_material = ""
	}

	shader = "gui:DIFFUSE_MAP"

	textures = {
		diffuse_map = "$texturePath"
	}

	variables = {
	}
}
"@

    [IO.File]::WriteAllText((Join-Path $textureRoot "$Name.texture"), $texture)
    [IO.File]::WriteAllText((Join-Path $materialRoot "$Name.material"), $material)
}

$source = [System.Drawing.Bitmap]::FromFile($sourcePath)
try {
    $targetAspect = 110.0 / 130.0
    $sourceAspect = $source.Width / [double]$source.Height
    if ($sourceAspect -gt $targetAspect) {
        $cropHeight = $source.Height
        $cropWidth = [int][Math]::Round($cropHeight * $targetAspect)
        $crop = [System.Drawing.Rectangle]::new(
            [int](($source.Width - $cropWidth) / 2), 0, $cropWidth, $cropHeight)
    } else {
        $cropWidth = $source.Width
        $cropHeight = [int][Math]::Round($cropWidth / $targetAspect)
        $crop = [System.Drawing.Rectangle]::new(
            0, [int](($source.Height - $cropHeight) / 2), $cropWidth, $cropHeight)
    }

    $medium = New-ResizedBitmap $source 110 130 $crop
    try {
        $medium.Save((Join-Path $textureRoot "medium_portrait_pusfume.png"),
            [System.Drawing.Imaging.ImageFormat]::Png)

        $fullMedium = [System.Drawing.Rectangle]::new(0, 0, 110, 130)
        $hud = New-ResizedBitmap $medium 86 108 $fullMedium
        try {
            Set-AlphaFromMask $hud $hudMaskPath -UseRedChannel
            $hud.Save((Join-Path $textureRoot "portrait_pusfume.png"),
                [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $hud.Dispose()
        }

        $small = New-ResizedBitmap $medium 60 70 $fullMedium
        try {
            Set-AlphaFromMask $small $smallMaskPath
            $small.Save((Join-Path $textureRoot "small_portrait_pusfume.png"),
                [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $small.Dispose()
        }
    } finally {
        $medium.Dispose()
    }
} finally {
    $source.Dispose()
}

foreach ($name in @("portrait_pusfume", "medium_portrait_pusfume", "small_portrait_pusfume")) {
    Write-PortraitMetadata $name
}

$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$importedHash = (Get-FileHash -LiteralPath (Join-Path $sourceRoot "pusfume_frame2.png") -Algorithm SHA256).Hash
if ($sourceHash -ne $importedHash) {
    throw "Canonical portrait source changed during import"
}

Write-Host "Pusfume portrait generated: source=$sourceHash variants=86x108,110x130,60x70"
