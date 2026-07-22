param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot "..\..\Vermintide-2-Source-Code")
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
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

function Test-ImageDimensions {
    param(
        [string]$Path,
        [int]$Width,
        [int]$Height
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        return $image.Width -eq $Width -and $image.Height -eq $Height
    } finally {
        $image.Dispose()
    }
}

$mainPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\pusfume.lua"
$configPath = Join-Path $repoRoot "pusfume\itemV2.cfg"
$backendPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_backend.lua"
$weaponsPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_weapons.lua"
$registryPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_registry.lua"
$preflightPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_preflight.lua"
$assetsPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_assets.lua"
$nativePath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_native.lua"
$nativeConfigPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_native_config.lua"
$uiPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_ui.lua"
$gameplayPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_gameplay.lua"
$accessPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\_pusfume_access.lua"
$localizationPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\pusfume_localization.lua"
$dataPath = Join-Path $repoRoot "pusfume\scripts\mods\pusfume\pusfume_data.lua"
$packagePath = Join-Path $repoRoot "pusfume\resource_packages\pusfume\pusfume.package"
$nativeUnitPackagePath = Join-Path $repoRoot "pusfume\units\pusfume\pusfume_3p.package"
$nativeBuildPath = Join-Path $repoRoot "tools\Build-NativePusfume.ps1"
$nativeMaterialTemplatePath = Join-Path $repoRoot "tools\material_templates\character_skinned.material"
$nativeCutoutTemplatePath = Join-Path $repoRoot "tools\material_templates\character_skinned_cutout.material"
$nativeExporterPath = Join-Path $repoRoot "tools\export_blender_bsi.py"
$animatedFbxToolPath = Join-Path $repoRoot "tools\prepare_animated_pusfume_fbx.py"
$idleFbxToolPath = Join-Path $repoRoot "tools\generate_idle_pusfume_fbx.py"
$firstPersonFbxToolPath = Join-Path $repoRoot "tools\prepare_pusfume_1p_blend.py"
$firstPersonBsiToolPath = Join-Path $repoRoot "tools\prepare_pusfume_1p_bsi.py"
$compiledFirstPersonRestPath = Join-Path $repoRoot "tools\validate_compiled_1p_rest.py"
$untouchedBodyToolPath = Join-Path $repoRoot "tools\prepare_pusfume_untouched_3p.py"
$firstPersonDiagnosticPath = Join-Path $repoRoot "tools\diagnose_pusfume_1p_blend.py"
$firstPersonSurfacePath = Join-Path $repoRoot "tools\compare_pusfume_1p_surfaces.py"
$firstPersonWeightAuditPath = Join-Path $repoRoot "tools\audit_pusfume_1p_weights.py"
$firstPersonWeightValidationPath = Join-Path $repoRoot "tools\validate_pusfume_1p_weight_transfer.py"
$firstPersonUnitScenePath = Join-Path $repoRoot "tools\stingray_unit_scene.py"
$changelogPath = Join-Path $repoRoot "CHANGELOG.md"
$contributingPath = Join-Path $repoRoot "CONTRIBUTING.md"
$thirdPartyNoticesPath = Join-Path $repoRoot "THIRD_PARTY_NOTICES.md"
$nativeMilestonePath = Join-Path $repoRoot "docs\NATIVE_CHARACTER_MILESTONE.md"
$workflowPath = Join-Path $repoRoot ".github\workflows\source-preflight.yml"
$previewPath = Join-Path $repoRoot "pusfume\textures\pusfume\pusfume_model_preview.png"
$previewTexturePath = Join-Path $repoRoot "pusfume\textures\pusfume\pusfume_model_preview.texture"
$previewMaterialPath = Join-Path $repoRoot "pusfume\materials\pusfume\pusfume_model_preview.material"
$portraitToolPath = Join-Path $repoRoot "tools\Build-PusfumePortrait.ps1"
$portraitTextureRoot = Join-Path $repoRoot "pusfume\gui\1080p\single_textures\pusfume_portraits"
$mainText = Get-Content -LiteralPath $mainPath -Raw
$configText = Get-Content -LiteralPath $configPath -Raw
$backendText = Get-Content -LiteralPath $backendPath -Raw
$weaponsText = Get-Content -LiteralPath $weaponsPath -Raw
$registryText = Get-Content -LiteralPath $registryPath -Raw
$preflightText = Get-Content -LiteralPath $preflightPath -Raw
$assetsText = Get-Content -LiteralPath $assetsPath -Raw
$nativeText = Get-Content -LiteralPath $nativePath -Raw
$nativeConfigText = Get-Content -LiteralPath $nativeConfigPath -Raw
$uiText = Get-Content -LiteralPath $uiPath -Raw
$gameplayText = Get-Content -LiteralPath $gameplayPath -Raw
$accessText = Get-Content -LiteralPath $accessPath -Raw
$localizationText = Get-Content -LiteralPath $localizationPath -Raw
$dataText = Get-Content -LiteralPath $dataPath -Raw
$packageText = Get-Content -LiteralPath $packagePath -Raw
$nativeUnitPackageText = Get-Content -LiteralPath $nativeUnitPackagePath -Raw
$nativeBuildText = Get-Content -LiteralPath $nativeBuildPath -Raw
$stripToolText = Get-Content -LiteralPath (Join-Path $repoRoot "tools\strip_bundle_resource.py") -Raw
$nativeMaterialTemplateText = Get-Content -LiteralPath $nativeMaterialTemplatePath -Raw
$nativeCutoutTemplateText = Get-Content -LiteralPath $nativeCutoutTemplatePath -Raw
$nativeExporterText = Get-Content -LiteralPath $nativeExporterPath -Raw
$animatedFbxToolText = Get-Content -LiteralPath $animatedFbxToolPath -Raw
$idleFbxToolText = Get-Content -LiteralPath $idleFbxToolPath -Raw
$firstPersonFbxToolText = Get-Content -LiteralPath $firstPersonFbxToolPath -Raw
$firstPersonBsiToolText = Get-Content -LiteralPath $firstPersonBsiToolPath -Raw
$compiledFirstPersonRestText = Get-Content -LiteralPath $compiledFirstPersonRestPath -Raw
$untouchedBodyToolText = Get-Content -LiteralPath $untouchedBodyToolPath -Raw
$firstPersonDiagnosticText = Get-Content -LiteralPath $firstPersonDiagnosticPath -Raw
$firstPersonSurfaceText = Get-Content -LiteralPath $firstPersonSurfacePath -Raw
$firstPersonWeightAuditText = Get-Content -LiteralPath $firstPersonWeightAuditPath -Raw
$firstPersonWeightValidationText = Get-Content -LiteralPath $firstPersonWeightValidationPath -Raw
$firstPersonUnitSceneText = Get-Content -LiteralPath $firstPersonUnitScenePath -Raw
$portraitToolText = Get-Content -LiteralPath $portraitToolPath -Raw
$changelogText = Get-Content -LiteralPath $changelogPath -Raw
$contributingText = Get-Content -LiteralPath $contributingPath -Raw
$nativeMilestoneText = if (Test-Path -LiteralPath $nativeMilestonePath) {
    Get-Content -LiteralPath $nativeMilestonePath -Raw
} else {
    ""
}
$workflowText = Get-Content -LiteralPath $workflowPath -Raw
$mainVersion = [regex]::Match($mainText, 'MOD_VERSION\s*=\s*"([^"]+)"').Groups[1].Value
$configVersion = [regex]::Match($configText, 'Prototype v([^";]+)').Groups[1].Value

Test-Condition ($mainVersion -and $mainVersion -eq $configVersion) "version" "$mainVersion"
Test-Condition ($configText -match 'visibility\s*=\s*"friends"') "Workshop visibility" "friends only"
Test-Condition ($configText -match 'published_id\s*=\s*3764954245L') "Workshop identity" "3764954245"
Test-Condition ($changelogText -match '## \[Unreleased\]' -and `
    $changelogText -match '### Known Limitations' -and `
    $contributingText -match 'Update `CHANGELOG\.md`' -and `
    (Test-Path -LiteralPath $thirdPartyNoticesPath) -and `
    (Get-Content -LiteralPath $thirdPartyNoticesPath -Raw) -match
        'Copyright \(c\) 2022 dalokraff') `
    "release discipline" "changelog and contribution policy are present"
Test-Condition ((Test-Path -LiteralPath $nativeMilestonePath) -and `
    $nativeMilestoneText -match '2405082174877027150' -and `
    $nativeMilestoneText -match 'Build-NativePusfume\.ps1 -HeroPreview -SplicedGameChild' -and `
    $nativeMilestoneText -match 'texture_map_27b67fd2.*Emissive' -and `
    $nativeMilestoneText -match 'Only idle and walk are animated') `
    "native milestone documentation" "known-good build, material contract, and animation boundary are recorded"
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
Test-Condition ($nativeConfigText -match 'first_person_unit\s*=\s*false' -and `
    $nativeConfigText -match 'first_person_material_package\s*=\s*false' -and `
    $nativeConfigText -match 'first_person_materials\s*=\s*false') `
    "first-person source default" "private handoff remains disabled in public source"
Test-Condition ($firstPersonFbxToolText -match 'REQUIRED_GROUPS' -and `
    $firstPersonFbxToolText -match 'MAXIMUM_ORPHAN_WEIGHT\s*=\s*0\.05' -and `
    $firstPersonFbxToolText -match 'reset_bind_pose' -and `
    $firstPersonFbxToolText -match 'armature\.animation_data_clear\(\)' -and `
    $firstPersonFbxToolText -match 'maximum_delta > 0\.00001' -and `
    $firstPersonFbxToolText -match 'rebind_to_donor_rest' -and `
    $firstPersonFbxToolText -match 'maximum_matrix_delta > 0\.0001' -and `
    $firstPersonFbxToolText -match 'maximum_mesh_delta > 0\.00001' -and `
    $firstPersonFbxToolText -match 'apply_stingray_basis_counter_scale' -and `
    $firstPersonFbxToolText -match 'factor=100\.0' -and `
    $firstPersonFbxToolText -match 'global_scale=0\.01' -and `
    $firstPersonFbxToolText -match 'apply_scale_options="FBX_SCALE_ALL"' -and `
    $firstPersonFbxToolText -match 'source blend is never overwritten' -and `
    $firstPersonFbxToolText -match 'bake_anim=False') `
    "first-person Blender preparation" "donor-rest rebind and guarded 0.01 FBX position scale preserve Janfon's mesh and unit bone bases"
Test-Condition ($firstPersonBsiToolText -match 'rebind_to_donor_rest' -and `
    $firstPersonBsiToolText -match 'conform_mesh_to_donor_rest' -and `
    $firstPersonBsiToolText -match 'build_skin\(' -and `
    $firstPersonBsiToolText -match 'build_geometry\(' -and `
    $firstPersonBsiToolText -match 'bsi_format\.write' -and `
    $firstPersonBsiToolText -match 'material_names != \["p_main"\]' -and `
    $firstPersonBsiToolText -notmatch 'apply_stingray_basis_counter_scale') `
    "first-person direct BSI preparation" "weighted mesh, scene nodes, and inverse binds share the donor-rest coordinate space"
Test-Condition ($firstPersonUnitSceneText -match 'version != 189' -and `
    $firstPersonUnitSceneText -match 'channel_count \* 17' -and `
    $firstPersonUnitSceneText -match 'world_matrices' -and `
    $firstPersonUnitSceneText -match 'name_hashes') `
    "compiled donor unit parser" "VT2 scene graph matrices and bone hashes are read with guarded version and bounds"
Test-Condition ($firstPersonDiagnosticText -match 'def edge_stretch' -and `
    $firstPersonDiagnosticText -match 'maximum_vertex_delta' -and `
    $firstPersonDiagnosticText -match 'nonidentity_pose_bones') `
    "first-person Blender diagnostics" "bind deformation remains independently measurable"
Test-Condition ($firstPersonSurfaceText -match 'def weighted_group_centroids' -and `
    $firstPersonSurfaceText -match 'custom_to_donor' -and `
    $firstPersonWeightAuditText -match 'PUSFUME_1P_WEIGHT_AUDIT' -and `
    $firstPersonWeightValidationText -match 'transferred_error' -and `
    $firstPersonWeightValidationText -match 'original_error' -and `
    $firstPersonFbxToolText -match 'def transfer_weights_from_native_surface' -and `
    $firstPersonFbxToolText -match 'j_leftarmroll' -and `
    $firstPersonBsiToolText -match 'native_weight_donor' -and `
    $nativeBuildText -notmatch '--native-weight-donor' -and `
    $nativeBuildText -match '--align-native-hero-grips') `
    "first-person authored-weight guard" "the rejected surface transfer remains research-only and shipping preserves Janfon's skin weights"
Test-Condition ($nativeBuildText -match '\[string\]\$FirstPersonBlend' -and `
    $nativeBuildText -match '\[string\]\$FirstPersonDonorUnit' -and `
    $nativeBuildText -match '\[string\]\$VersusFirstPersonBlend' -and `
    $nativeBuildText -match '\[string\]\$VersusFirstPersonDonorUnit' -and `
    $nativeBuildText -match '\[ValidateSet\("bsi", "fbx"\)\]' -and `
    $nativeBuildText -match '\[string\]\$FirstPersonFormat = "bsi"' -and `
    $nativeBuildText -match 'FirstPersonBlend requires -FirstPersonDonorUnit' -and `
    $nativeBuildText -match 'prepare_pusfume_1p_bsi\.py' -and `
    $nativeBuildText -match 'prepare_pusfume_1p_blend\.py' -and `
    $nativeBuildText -match 'pusfume_1p_arms\.unit' -and `
    $nativeBuildText -match 'pusfume_1p_versus_arms\.unit' -and `
    $nativeBuildText -match 'native_1p_child\.package' -and `
    $nativeBuildText -match 'pusfume_1p_body_child' -and `
    $nativeBuildText -match 'E0C4E09D80AE735B' -and `
    $nativeBuildText -match '3B3F6545AF6782F5') `
    "first-person native build" "direct-UV arms use a dedicated spliced skin binding"
Test-Condition ($nativeBuildText -match 'processed_bundles\.csv' -and `
    $nativeBuildText -match 'medium_portrait_pusfume,texture' -and `
    $nativeBuildText -match 'units/pusfume/pusfume_1p_arms,unit' -and `
    $nativeBuildText -match 'units/pusfume/pusfume_1p_versus_arms,unit' -and `
    $nativeBuildText -match 'validate_compiled_1p_rest\.py' -and `
    $compiledFirstPersonRestText -match 'MINIMUM_SHARED_NODES = 53' -and `
    $compiledFirstPersonRestText -match 'TOLERANCE = 0\.001') `
    "compiled asset manifest" "native build rejects omitted resources and post-compiler skeleton drift"
Test-Condition ($untouchedBodyToolText -match 'EXPECTED_UNWEIGHTED = \{"p_glob": 670, "p_main": 12\}' -and `
    $untouchedBodyToolText -match 'j_lefthandpinky4.*j_lefthandpinky3' -and `
    $untouchedBodyToolText -match 'backpack\.add\(by_material\["p_glob"\], 1\.0' -and `
    $untouchedBodyToolText -match 'distance > 0\.00001' -and `
    $untouchedBodyToolText -match 'bake_anim_use_all_actions=False' -and `
    $nativeBuildText -match '\[switch\]\$IntegratedFur' -and `
    $nativeBuildText -match 'LegacyFur and IntegratedFur are mutually exclusive' -and `
    $nativeBuildText -match 'model contains p_fur; rebuild with -IntegratedFur') `
    "untouched-rig body" "known missing weights are narrowly repaired and integrated fur is not duplicated"
Test-Condition ($assetsText -match 'M\.first_person_retarget_pairs' -and `
    $assetsText -match 'source = "j_spine2", target = "j_spine1"' -and `
    $assetsText -match '"j_lefthandindex4"' -and `
    $assetsText -match '"j_righthandthumb3"' -and `
    $assetsText -match '(?s)M\.first_person_attachment\s*=\s*\{.*?root_point.*?\n\}' -and `
    $assetsText -match 'M\.first_person_direct_attachment = M\.first_person_retarget_pairs' -and `
    $assetsText -match 'pusfume_first_person_retarget_pairs') `
    "first-person bone bridge" "donor-rest builds use all native links while root-only retarget remains a fallback"
Test-Condition ($nativeText -match 'PlayerUnitFirstPerson, "init"' -and `
    $nativeText -match 'PlayerUnitFirstPerson, "update"' -and `
    $nativeText -match 'apply_first_person_materials' -and `
    $nativeText -match 'first_person_attachment') `
    "first-person runtime" "Pusfume arms attach and receive the late skinned material"
Test-Condition ($nativeText -match 'config\.first_person_direct_link' -and `
    $nativeText -match 'AttachmentNodeLinking\.first_person_attachment' -and `
    $nativeText -match 'First-person donor-rest direct links active' -and `
    $nativeText -match '(?s)active_first_person_rig ~= "skaven".*?not config\.first_person_direct_link then\s*update_first_person_retarget') `
    "first-person donor-rest runtime" "exact-rest builds bypass all per-frame retarget and anchor corrections"
Test-Condition ($nativeText -match 'First-person attachment probe meshes=%d' -and `
    $nativeText -match 'Unit\.num_meshes\(target\)' -and `
    $nativeText -match 'source = "j_spine2", target = "j_spine2"' -and `
    $nativeText -notmatch 'Unit\.node\(target, node_name\)' -and `
    $nativeText -match 'Vector3\.distance\(source_position, target_position\)') `
    "first-person runtime probe" "live logs distinguish render visibility from node alignment"
Test-Condition ($nativeText -match 'config\.versus_first_person_unit' -and `
    $nativeText -match 'spawn_dual_first_person_rig' -and `
    $nativeText -match 'SimpleInventoryExtension, "wield"' -and `
    $nativeText -match 'SKAVEN_ROLE_BY_POSE\[item_template\.pusfume_role_pose\]' -and `
    $nativeText -match 'inventory_extension\._first_person_unit = first_person_unit' -and `
    $nativeText -match 'relink_first_person_slot' -and `
    $nativeText -match 'weapon_extension\.first_person_unit = first_person_unit' -and `
    $nativeText -notmatch '(?s)local function switch_first_person_rig.*?extension\.first_person_unit = first_person_unit.*?local function prepare_first_person_rig_for_wield' -and `
    $nativeBuildText -match 'dual_first_person_rigs = \$dualFirstPersonRigsValue') `
    "dual first-person rigs" "Versus weapons use Janfon's Skaven rig without replacing the hero camera base"
Test-Condition ($nativeText -match 'spawn_local_unit\(source_rest_unit_name\)' -and `
    $nativeText -match 'Matrix4x4\.multiply\(source_pose, Matrix4x4\.inverse\(source_rest\)\)' -and `
    $nativeText -match 'Matrix4x4\.set_translation\(target_pose, Matrix4x4\.translation\(target_rest\)\)' -and `
    $nativeText -match 'Unit\.set_local_pose\(target, pair\.target_node, target_pose\)' -and `
    $nativeText -match 'LODObject\.set_bounding_volume\(target_lod, LODObject\.bounding_volume\(source_lod\)\)') `
    "first-person rest retarget" "donor animation deltas preserve Janfon bind offsets and inherit donor bounds"
Test-Condition ($nativeText -match 'source_anchor - target_anchor' -and `
    $nativeText -match 'Unit\.world_pose\(target, retarget\.target_spine_node\)' -and `
    $nativeText -match 'Unit\.set_local_pose\(target, retarget\.target_spine_node, spine_local_pose\)' -and `
    $nativeText -match 'anchor_error = Vector3\.length\(correction\)' -and `
    $nativeBuildText -match '(?s)pusfume_1p_arms = \{.*?culling = "disabled"') `
    "first-person camera anchor" "rigid midpoint correction closes camera offset with mesh-bound culling disabled"
Test-Condition ($nativeText -match 'target_limb_root_nodes' -and `
    $nativeText -match 'Unit\.world_position\(source, retarget\.source_anchor_nodes\[index\]\)' -and `
    $nativeText -match 'local correction = hand_error - midpoint_correction' -and `
    $nativeText -match 'Unit\.set_local_pose\(\s*target,\s*retarget\.target_limb_root_nodes\[index\]' -and `
    $nativeText -match 'if retarget\.correction_applied then\s*for index = 1, 2 do\s*retarget\.limb_residuals\[index\] = Vector3\.distance') `
    "first-person per-arm anchors" "side corrections exclude inherited midpoint motion and residuals measure the resolved prior frame"
Test-Condition ($preflightText -match 'mod:echo\("%s", string\.format\(') `
    "preflight output" "percent-bearing details cannot become VMF format strings"
Test-Condition ($nativeText -match 'career\.name == registry\.CAREER_NAME' -and `
    $nativeText -match 'extension_init_data\.skin_name = config\.skin_name' -and `
    $nativeText -match 'extension_init_data\.skin_name = donor_skin_name' -and `
    $nativeText -match 'First-person skin substitution') `
    "first-person skin substitution" "Pusfume replaces donor arms before vanilla attachment spawn"
Test-Condition ($nativeText -match 'function M\.first_person_status\(\)' -and `
    $preflightText -match 'add\(checks, "native first-person arms"') `
    "first-person preflight" "runtime diagnostics separate unit, hook, package, and material state"
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
    $nativeBuildText -match '\[string\]\$IdleAnimationFbx' -and `
    $nativeBuildText -match 'validate_pusfume_animation_contract\.py' -and `
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
Test-Condition ($nativeBuildText -match '"deploy", "pusfume", "--no-banner"' -and `
    $nativeBuildText -match 'Assert-HiddenToolSuccess \$result "VMBLauncher verified deployment"' -and `
    $nativeBuildText -notmatch 'Copy-Item -LiteralPath \$_\.FullName -Destination \$deployedPath') `
    "canonical deployment" "VMBLauncher hash-verifies local and enabled-remote Workshop copies"
Test-Condition ($nativeBuildText -match 'function Invoke-HiddenTool' -and `
    $nativeBuildText -match '\$startInfo\.UseShellExecute\s*=\s*\$false' -and `
    $nativeBuildText -match '\$startInfo\.CreateNoWindow\s*=\s*\$true' -and `
    $nativeBuildText -match '\$startInfo\.WindowStyle\s*=\s*\[Diagnostics\.ProcessWindowStyle\]::Hidden' -and `
    $nativeBuildText -match '\$startInfo\.RedirectStandardOutput\s*=\s*\$true' -and `
    $nativeBuildText -match '\$startInfo\.RedirectStandardError\s*=\s*\$true' -and `
    $nativeBuildText -notmatch '(?m)^\s*&\s+') `
    "non-disruptive native tools" "all external build, post-process, VMBLauncher, and SDK children cannot create visible windows"
Test-Condition ($nativeBuildText -match '\[switch\]\$Upload' -and `
    $nativeBuildText -match '"build", "pusfume", "--clean"' -and `
    $nativeBuildText -match '"upload", "pusfume", "--no-banner"' -and `
    $nativeBuildText -match 'Uploaded new content' -and `
    $nativeBuildText -match 'ManifestID' -and `
    $nativeBuildText -match 'Steam confirmed Pusfume Workshop ManifestID') `
    "canonical native ship" "one hidden pipeline builds, deploys, uploads, and verifies Steam's manifest"
Test-Condition ($nativeBuildText -match '\[switch\]\$UseBsiSkinFallback' -and `
    $nativeBuildText -match '\$useFbxDcc\s*=\s*-not \$UseBsiSkinFallback\.IsPresent' -and `
    $nativeBuildText -match 'pusfume_3p\.dcc_asset' -and `
    $nativeBuildText -match 'extension\s*=\s*"\.fbx"') `
    "native FBX pipeline" "supported Stingray DCC import is default and BSI remains an explicit fallback"
Test-Condition ($nativeBuildText -match 'prepare_animated_pusfume_fbx\.py' -and `
    $nativeBuildText -match '\$modelFbxPath, \$animationFbxPath, \$animatedModelFbxPath' -and `
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
    $nativeBuildText -match '\[string\]\$IdleAnimationFbx' -and `
    $nativeBuildText -match 'pusfume_3p_walk\.animation' -and `
    $nativeBuildText -match 'pusfume_3p_idle\.animation' -and `
    $nativeBuildText -match 'animation_state_machine\s*=\s*"units/pusfume/pusfume_3p"' -and `
    $nativeBuildText -match 'name = "base/walk"') `
    "native animation" "separate authored idle and retargeted walk FBXs are packaged as controller states"
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
Test-Condition ($nativeBuildText -match '\[switch\]\$LegacyFur' -and `
    $nativeBuildText -match 'dalokraff legacy fur license/provenance contract is missing' -and `
    $animatedFbxToolText -match 'def add_legacy_fur\(' -and `
    $animatedFbxToolText -match 'def retarget_fur_surface\(' -and `
    $animatedFbxToolText -match 'def connected_vertex_islands\(' -and `
    $animatedFbxToolText -match 'Rigid fur-island retarget changed authored card geometry' -and `
    $animatedFbxToolText -match 'after\["mean"\] >= before\["mean"\] \* 0\.65' -and `
    $animatedFbxToolText -match 'Legacy fur weight transfer left' -and `
    $animatedFbxToolText -match 'Transferred action did not deform legacy fur' -and `
    $nativeBuildText -match '\[double\]\$BodyDiffuseGain = 1\.2' -and `
    $nativeBuildText -match '\[double\]\$FurDiffuseGain = 0\.55' -and `
    $nativeBuildText -match '\$furMaterialEntry = if \(\$furEnabled\)' -and `
    $nativeBuildText -match 'p_fur = "materials/pusfume/pusfume_fur"' -and `
    $nativeBuildText -match '\$furRenderableEntry = if \(\$LegacyFur\)' -and `
    $nativeBuildText -match 'child_materials/pusfume/pusfume_fur_child' -and `
    $nativeBuildText -match '20A7120B25F414F7' -and `
    $nativeConfigText -match 'fur_child_material\s*=\s*false' -and `
    $nativeText -match 'Unit\.set_material\(unit, FUR_MATERIAL_SLOT, config\.fur_child_material\)' -and `
    $nativeBuildText.IndexOf('function Write-LegacyFurTexture') -gt `
        $nativeBuildText.IndexOf('function Write-NativeTextureRecipe') -and `
    $nativeBuildText.IndexOf('function Write-LegacyFurTexture') -gt `
        $nativeBuildText.IndexOf('"@ | Set-Content -LiteralPath (Join-Path $textureRoot "$Name.texture")')) `
    "dalokraff fur integration" "licensed fur is weight-transferred, deformation-checked, and packaged by a callable texture helper"
Test-Condition ($nativeText -match 'function M\.native_skin_name' -and `
    $nativeText -notmatch 'third_person_attachment = nil' -and `
    $uiText -match 'MenuWorldPreviewer, "request_spawn_hero_unit"' -and `
    $uiText -match 'MenuWorldPreviewer, "_update_units_visibility"' -and `
    $uiText -match 'MenuWorldPreviewer, "_spawn_hero_unit"' -and `
    $uiText -match 'optional_skin = native_skin' -and `
    $uiText -match 'Unit\.enable_animation_state_machine\(mesh_unit\)') `
    "menu preview purity" "menu previewers force the native skin and start the mesh controller"
Test-Condition ($nativeConfigText -match 'parent_child_material\s*=\s*false' -and `
    $nativeConfigText -match 'parent_child_package\s*=\s*false' -and `
    $nativeConfigText -match 'whisker_child_material\s*=\s*false' -and `
    $nativeConfigText -match 'whisker_donor_package\s*=\s*false' -and `
    $nativeBuildText -match '\[switch\]\$ParentChildMaterial' -and `
    $nativeBuildText -match '"child_materials/pusfume/pusfume_outfit_child"' -and `
    $nativeBuildText -match '"child_materials/pusfume/pusfume_whiskers_child"' -and `
    $nativeBuildText -match 'native_child\.package' -and `
    $nativeBuildText -match 'parent_material = "units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/mtr_outfit"' -and `
    $nativeText -match 'function ensure_child_package' -and `
    $nativeText -match 'not state\.donor_package_loaded or not state\.whisker_donor_package_loaded' -and `
    $nativeText -notmatch 'can_get\("package", config\.parent_child_package\)' -and `
    $nativeText -match 'mod:load_package\(config\.parent_child_package, nil, true\)' -and `
    $nativeText -match 'mod:package_status\(config\.parent_child_package\) == "loaded"' -and `
    $nativeText -match 'Native child material package did not load through the mod handle' -and `
    $nativeText -match 'mod:unload_package\(config\.parent_child_package\)' -and `
    $nativeText -match 'Unit\.set_material\(unit, slot_name, material\)' -and `
    $nativeText -match 'Unit\.set_material\(unit, WHISKER_MATERIAL_SLOT, config\.whisker_child_material\)' -and `
    $nativeText -match 'Managers\.package:load\(config\.whisker_donor_package, WHISKER_DONOR_PACKAGE_REFERENCE\)' -and `
    $nativeText -match 'Managers\.package:unload\(config\.whisker_donor_package, WHISKER_DONOR_PACKAGE_REFERENCE\)' -and `
    $nativeBuildText -match 'units/beings/player/empire_soldier_knight/headpiece/es_k_hat_07') `
    "parent-child material" "VMF resolves opaque and skinned-alpha children through one ordered mod package"
Test-Condition ($nativeText -match 'pusfume_material_probe' -and `
    $nativeText -match 'donor_raw\s*=\s*true' -and `
    $nativeText -match 'donor_atlas\s*=\s*true' -and `
    $nativeText -match 'child\s*=\s*true' -and `
    $nativeText -match 'split\s*=\s*true' -and `
    $nativeText -match 'assignments=%s') `
    "live material A/B probe" "one session can compare donor, atlas override, child, and split-slot deformation"
Test-Condition ((Test-Path (Join-Path $repoRoot "tools\strip_bundle_resource.py")) -and `
    (Test-Path (Join-Path $repoRoot "tests\test_strip_bundle_resource.py")) -and `
    $nativeBuildText -match 'strip_bundle_resource\.py' -and `
    $nativeBuildText -match 'retired_stub_parent' -and `
    $nativeBuildText -match '\$totalStripped -lt 2' -and `
    $nativeBuildText -match '"--expect", "0", "--dry-run"') `
    "stub identity strip" "-ParentChildMaterial builds rename the bundled stub so the game parent resolves at runtime"
Test-Condition ($nativeText -match 'function M\.apply_donor_to_unit' -and `
    $nativeText -match 'not unit or not Unit\.alive\(unit\)' -and `
    $uiText -match 'local function initialize_native_preview\(previewer\)' -and `
    $uiText -match 'if not native\.apply_donor_to_unit\(mesh_unit\) then' -and `
    $uiText -match 'initialize_native_preview\(previewer\)') `
    "menu preview shader" "preview-world units retry the donor character shader before starting the native idle"
Test-Condition ($nativeConfigText -match 'donor_texture_shadow\s*=\s*false' -and `
    $nativeConfigText -match 'donor_texture_shadow_package\s*=\s*false' -and `
    $nativeBuildText -match '\[switch\]\$NoDonorTextureShadow' -and `
    $nativeBuildText -match 'Parent-child and ordered texture-shadow experiments are mutually exclusive' -and `
    $nativeBuildText -match 'donor_texture_shadow = \$donorTextureShadowValue' -and `
    $nativeBuildText -match 'donor_texture_shadow_package = \$donorTextureShadowPackageValue' -and `
    $nativeBuildText -match 'native_shadow\.package' -and `
    $nativeText -match 'function ensure_shadow_package' -and `
    $nativeText -match 'Requested late donor texture shadow package' -and `
    $nativeText -match 'mod:load_package\(config\.donor_texture_shadow_package, nil, true\)' -and `
    $nativeBuildText -match 'DD74D8319F514D96' -and `
    $nativeBuildText -match '45FFAEEF53695A86' -and `
    $nativeBuildText -match 'E334A8CB6BCB5E6D' -and `
    $nativeBuildText -match '"--type", "texture", "--bare"' -and `
    $nativeBuildText -match '\$totalRenamed -ne 2' -and `
    $stripToolText -match '--new-hash' -and `
    $stripToolText -match 'preexisting_new' -and `
    $nativeText -match 'mode == "donor_atlas" and not config\.donor_texture_shadow') `
    "donor texture shadow" "an isolated atlas package loads after the donor, renames to mtr_outfit texture ids, and skips the dead runtime restore"
Test-Condition ((Test-Path (Join-Path $repoRoot "tools\splice_bundle_resource.py")) -and `
    (Test-Path (Join-Path $repoRoot "tools\make_spliced_child.py")) -and `
    (Test-Path (Join-Path $repoRoot "tests\test_splice_bundle_resource.py")) -and `
    $nativeBuildText -match '\[switch\]\$SplicedGameChild' -and `
    $nativeBuildText -match '\$ParentChildMaterial = \$true' -and `
    $nativeBuildText -match '\$NoDonorTextureShadow = \$true' -and `
    $nativeBuildText -match 'make_spliced_child\.py' -and `
    $nativeBuildText -match '"--expect-size", "768"' -and `
    $nativeBuildText -match '"--expect-size", "96"' -and `
    $nativeBuildText -match '"--expect-size", "128"' -and `
    $nativeBuildText -match '"--expect-parent", "3D25339231384C80"' -and `
    $nativeBuildText -match '"--expect-parent", "D97596A091982F4B"' -and `
    $nativeBuildText -match '"--expect-parent", "F85B289742D5D69A"' -and `
    $nativeBuildText -match 'hash:F72D636600F7F598' -and `
    $nativeBuildText -match 'DD74D8319F514D96=C263ECB79A8DCEC0' -and `
    $nativeBuildText -match 'E334A8CB6BCB5E6D=A4215592F6297E57' -and `
    $nativeBuildText -match '45FFAEEF53695A86=818C87B860407405' -and `
    $nativeBuildText -match 'texture_map_02af90f8=C263ECB79A8DCEC0' -and `
    $nativeBuildText -match 'texture_map_27b67fd2=818C87B860407405' -and `
    $nativeBuildText -match 'texture_map_8bf37d8e=A4215592F6297E57' -and `
    $nativeBuildText -match '86FFDEB90C40C597=E0C4E09D80AE735B' -and `
    $nativeBuildText -match '258E4E4AEA37B1B8=45FFAEEF53695A86' -and `
    $nativeBuildText -match 'E04C4FD132004376=3B3F6545AF6782F5' -and `
    $nativeBuildText -match 'hash:C70B1AAD3B363E24' -and `
    $nativeBuildText -match 'C9CF19C214612D75=7F060B4938ADCF12' -and `
    $nativeBuildText -match 'CDA03B9B0226037A=950FC5950CCEBCD0' -and `
    $nativeBuildText -match 'D3FD8377A3DE498A=BEB4D8D9891A6D4A' -and `
    $nativeBuildText -match 'texture_map_c0ba2942=7F060B4938ADCF12' -and `
    $nativeBuildText -match 'texture_map_59cd86b9=950FC5950CCEBCD0' -and `
    $nativeBuildText -match 'texture_map_b788717c=BEB4D8D9891A6D4A' -and `
    $nativeBuildText -match '\$splicedInto\.Count -ne 1' -and `
    $nativeBuildText -match '\$whiskerSplicedInto\.Count -ne 1' -and `
    $nativeBuildText -notmatch 'spliced_child_payload\.bin"? *-Destination') `
    "spliced game children" "body and Laurel whisker bindings are validated from local game data and embedded only in generated output"
Test-Condition ($nativeText -match 'pusfume_tint' -and `
    $nativeText -match 'Material\.set_scalar\(material, "gradient_variation", variation\)' -and `
    $nativeText -match 'Material\.set_scalar\(material, "tint_columns_pair", columns_pair\)') `
    "gradient tint probe" "live tint sweep rides the engine's own character-tint scalars to neutralize the shader-applied Globadier green"
Test-Condition ($backendText -match 'mod:hook\(LoadoutUtils, "properties_to_rpc_params"' -and `
    $backendText -match 'rawget\(NetworkLookup\.properties, property_name\)' -and `
    $backendText -match 'rawget\(NetworkLookup\.traits, trait_name\)' -and `
    $backendText -match 'Stripped unencodable loadout property from sync' -and `
    $backendText -notmatch 'wire_guard_enabled') `
    "loadout sync wire guard" "unencodable item properties and traits are stripped sender-side before the vanilla RPC encoder, unconditionally"
Test-Condition ($nativeConfigText -match 'hide_donor_weapons\s*=\s*false' -and `
    $nativeBuildText -match 'hide_donor_weapons\s*=\s*false' -and `
    $nativeText -match 'unhide_weapons\(PACKMASTER_WEAPON_HIDE_REASON\)' -and `
    $nativeText -match 'unhide_weapons\(FIRST_PERSON_WEAPON_HIDE_REASON\)' -and `
    $nativeText -match 'Unit\.has_animation_event\(first_person_unit, "to_armed"\)' -and `
    $nativeText -match 'Unit\.animation_has_variable\(first_person_unit, "armed"\)' -and `
    $uiText -notmatch 'Unit\.set_unit_visibility\(weapon_unit, false\)') `
    "prototype weapon visibility" "staged builds clear diagnostic and Packmaster hide seams, then capability-guard the native armed presentation"
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
Test-Condition ($registryText -match 'career\.portrait_image\s*=\s*"portrait_pusfume"' -and `
    $registryText -match 'career\.picking_image\s*=\s*"medium_portrait_pusfume"' -and `
    $registryText -match 'career\.portrait_thumbnail\s*=\s*"small_portrait_pusfume"') `
    "Pusfume portrait registration" "career uses custom HUD, selector, and compact portraits"
Test-Condition ($dataText -match '"portrait_pusfume"' -and `
    $dataText -match '"level_end_view_base"' -and `
    $packageText -match 'materials/ui/portrait_pusfume') `
    "Pusfume portrait package" "standalone materials reach HUD, selector, and score renderers"
Test-Condition ([regex]::Matches($packageText, '(?m)^texture\s*=\s*\[').Count -le 1) `
    "resource package keys" "source manifest cannot create duplicate texture sections in native staging"
Test-Condition ($portraitToolText -match 'New-ResizedBitmap \$source 110 130' -and `
    $portraitToolText -match 'New-ResizedBitmap \$medium 86 108' -and `
    $portraitToolText -match 'New-ResizedBitmap \$medium 60 70' -and `
    $portraitToolText -match 'Set-AlphaFromMask') `
    "Pusfume portrait pipeline" "canonical source generates three masked VT2 variants"
Test-Condition (Test-ImageDimensions (Join-Path $portraitTextureRoot "portrait_pusfume.png") 86 108) `
    "Pusfume HUD portrait" "86x108"
Test-Condition (Test-ImageDimensions (Join-Path $portraitTextureRoot "medium_portrait_pusfume.png") 110 130) `
    "Pusfume selector portrait" "110x130"
Test-Condition (Test-ImageDimensions (Join-Path $portraitTextureRoot "small_portrait_pusfume.png") 60 70) `
    "Pusfume compact portrait" "60x70"
foreach ($portraitName in @("portrait_pusfume", "medium_portrait_pusfume", "small_portrait_pusfume")) {
    Test-Condition (Test-Path -LiteralPath (Join-Path $portraitTextureRoot "$portraitName.texture")) `
        "Pusfume portrait recipe" "$portraitName texture recipe exists"
    Test-Condition (Test-Path -LiteralPath (Join-Path $repoRoot "pusfume\materials\ui\$portraitName.material")) `
        "Pusfume portrait material" "$portraitName GUI material exists"
}
Test-Condition ($mainText -match 'registry\.refresh_item_permissions\(\)') `
    "item permissions" "late-loaded items are refreshed"
Test-Condition ($mainText -match 'weapons\.install\(registry\)' -and `
    $weaponsText -match 'pusfume_packmaster_hook' -and `
    $weaponsText -match 'pusfume_warpfire_thrower' -and `
    $weaponsText -match 'pusfume_ratling_gun' -and `
    $weaponsText -match 'pusfume_poison_wind_globe' -and `
    $weaponsText -match 'vs_packmaster_claw' -and `
    $weaponsText -match 'vs_warpfire_thrower_gun' -and `
    $weaponsText -match 'two_handed_axes_template_1' -and `
    $weaponsText -match 'Weapons\.vs_warpfire_thrower_gun' -and `
    $weaponsText -match 'adapt_warpfire_template' -and `
    $weaponsText -match 'template\.actions\.action_one\s*=\s*action_one' -and `
    $weaponsText -match 'template\.actions\.weapon_reload\s*=\s*action_reload' -and `
    $weaponsText -match 'template\.actions\.dark_pact_action_one\s*=\s*deep_clone\(action_one\)' -and `
    $weaponsText -match 'template\.actions\.dark_pact_reload\s*=\s*deep_clone\(action_reload\)' -and `
    $weaponsText -match 'bind_action_lookup_data\(action_one, "action_one"\)' -and `
    $weaponsText -match 'validate_action_graph' -and `
    $weaponsText -notmatch 'template\.actions\.dark_pact_action_one\s*=\s*nil' -and `
    $weaponsText -match 'pusfume_warpfire_targets' -and `
    $weaponsText -match 'side:enemy_units\(\)' -and `
    $weaponsText -match 'mod:hook\(ActionWarpfireThrower, "fire"' -and `
    $weaponsText -match 'DamageUtils\.add_damage_network\(target\.unit, owner_unit, 2' -and `
    $weaponsText -match 'sanitize_packmaster_melee_actions' -and `
    $weaponsText -match 'strike_with_packmaster_hook' -and `
    $weaponsText -match 'DamageUtils\.add_damage_network\(target_unit, owner_unit, 15' -and `
    $weaponsText -match 'adapt_ratling_template' -and `
    $weaponsText -match 'spawn_globadier_globe' -and `
    $weaponsText -match 'action\.anim_event_1p\s*=\s*"attack_grab"' -and `
    $weaponsText -match 'template\.wield_anim\s*=\s*"idle"' -and `
    $weaponsText -match 'template\.pusfume_role_pose\s*=\s*"to_packmaster"' -and `
    $weaponsText -notmatch 'to_packmaster_claw' -and `
    $weaponsText -match 'template_name\s*=\s*"pusfume_crossbow_template"' -and `
    $weaponsText -match 'installed_crossbow\.state_machine\s*=\s*nil' -and `
    $weaponsText -match 'sanitize_placeholder_animation_events' -and `
    $weaponsText -match 'first_person_hit_anim' -and `
    $weaponsText -match 'action\[field_name\] = nil' -and `
    $weaponsText -match 'action_hand_contract_ready') `
    "Pusfume weapon templates" "base Versus items retain coherent native hand contracts with guarded Adventure and animation adapters"
Test-Condition ($weaponsText -match 'can_wield\s*=\s*\{ registry\.CAREER_NAME \}' -and `
    $registryText -match 'local is_weapon = item\.slot_type == "melee" or item\.slot_type == "ranged"' -and `
    $registryText -match 'if not is_weapon and type\(can_wield\)' -and `
    $backendText -match 'can_wield_by_current_career' -and `
    $backendText -match 'weapons\.allowed_item_keys\(slot_name\)' -and `
    $backendText -match 'item_key == ' -and `
    $backendText -match 'weapons\.select_backend_id\(slot_name, backend_id\)' -and `
    $backendText -match 'weapons\.select_item_key\(slot_name, item_key\)' -and `
    $backendText -match 'slot_type == melee' -and `
    $backendText -match 'slot_type == ranged') `
    "Pusfume weapon isolation" "prototype items and weapon grids are career-only; Bardin weapons are not inherited"
Test-Condition ($weaponsText -match 'append_lookup\(NetworkLookup\.item_names, item_key\)' -and `
    $weaponsText -match 'append_lookup\(NetworkLookup\.damage_sources, item_key\)' -and `
    $backendText -match 'get_all_backend_items' -and `
    $backendText -match 'weapons\.inject_backend_items') `
    "Pusfume backend items" "stable owned-item records and synchronized network keys are injected into PlayFab"
Test-Condition ($registryText -match 'function M\.refresh_career_color\(\)' -and `
    $registryText -match 'color_definitions\[M\.CAREER_NAME\]\s*=\s*deep_clone\(donor_color\)') `
    "career color" "Pusfume owns a distinct donor-derived color table"
Test-Condition ($mainText -match 'registry\.refresh_career_color\(\)') `
    "career color" "registration is refreshed across game-state changes"
Test-Condition ($registryText -match 'career\.display_name\s*=\s*M\.CAREER_NAME' -and `
    $localizationText -match 'pusfume\s*=\s*\{\s*en\s*=\s*"Under-Empire Reject"' -and `
    $registryText -match 'career\.activated_ability\s*=\s*ActivatedAbilitySettings\.pusfume' -and `
    $registryText -match 'career\.passive_ability\s*=\s*PassiveAbilitySettings\.pusfume' -and `
    $uiText -match 'mod:localize\("pusfume_character_name"\)' -and `
    $uiText -match 'mod:localize\("pusfume_career_name"\)') `
    "career identity" "Pusfume owns localized selector names and gameplay settings"
Test-Condition ($registryText -notmatch 'career\.display_name\s*=\s*"pusfume_career_name"') `
    "profile request identity" "display_name remains the internal career token required by career_index_from_name"
Test-Condition ($mainText -match 'gameplay\.install\(\)' -and `
    $gameplayText -match 'CareerAbilityPusfumeIngenuity' -and `
    $gameplayText -match 'augmentation_armed\s*=\s*true' -and `
    $gameplayText -match 'local ACTIVE_COOLDOWN\s*=\s*90') `
    "Moulder Ingenuity" "v2 tool bag arms the next consumable with a 90-second cooldown"
Test-Condition ($preflightText -match 'add\(checks, "career kit"' -and `
    $preflightText -match 'add\(checks, "Aggressive Iteration proc"' -and `
    $preflightText -match 'add\(checks, "v2 passive perks"') `
    "career-kit preflight" "live diagnostics validate the v2 ability and passive registration"
Test-Condition ($gameplayText -match 'poison_damage_types' -and `
    $gameplayText -match 'skaven_poison_wind_globadier\s*=\s*true' -and `
    $gameplayText -match 'PlayerUnitHealthExtension, "add_damage"') `
    "Hell Pit Native" "poison immunity is career-scoped before damage procs"
Test-Condition ($gameplayText -match 'duration\s*=\s*3' -and `
    $gameplayText -match 'multiplier\s*=\s*1\.2' -and `
    $gameplayText -match 'path_to_movement_setting_to_modify\s*=\s*\{ "move_speed" \}' -and `
    $gameplayText -match 'buff_perks\.no_moveslow_on_hit' -and `
    $gameplayText -match 'attack_type == "light_attack"' -and `
    $gameplayText -match 'attack_type == "heavy_attack"') `
    "Scaredy-rat" "hit slowdown is suppressed and enemy melee damage grants 20 percent speed for three seconds"
Test-Condition ($gameplayText -notmatch 'mod:add_proc_function' -and `
    $gameplayText -notmatch 'mod:add_buff_template' -and `
    $gameplayText -match 'ProcFunctions\.pusfume_aggressive_iteration_proc\s*=\s*function' -and `
    $gameplayText -match 'BuffTemplates\[name\]\s*=\s*\{' -and `
    $gameplayText -match 'definition\.name\s*=\s*name' -and `
    $gameplayText -match 'append_lookup\(NetworkLookup\.buff_templates, name\)' -and `
    $gameplayText -match 'rawget\(lookup, name\)' -and `
    $gameplayText -match 'rawset\(lookup, name, index\)' -and `
    $preflightText -match 'add\(checks, "career buff registry"') `
    "career buff APIs" "normalizes v2 templates and uses synchronized VT2 registries"
Test-Condition ($gameplayText -match 'stat_buff\s*=\s*"reload_speed"' -and `
    $gameplayText -match 'multiplier\s*=\s*-0\.15' -and `
    $gameplayText -match 'max_stacks\s*=\s*1') `
    "Swift Claws" "reload time uses the stock stacking multiplier at fifteen percent faster"
Test-Condition ($accessText -match 'mod:dofile\("scripts/mods/pusfume/pusfume_localization"\)' -and `
    $accessText -match 'for key, translations in pairs\(localization\)' -and `
    $accessText -match 'global_strings\[key\] = translations\.en' -and `
    $accessText -match 'mod:hook\(_G, "Localize"' -and `
    $preflightText -match 'add\(checks, "career localization"' -and `
    $preflightText -match 'value == "<" \.\. key \.\. ">"') `
    "career localization" "global Localize derives every career string from the VMF localization table"
Test-Condition ($gameplayText -match 'event\s*=\s*"on_kill"' -and `
    $gameplayText -match 'breed\.special' -and `
    $gameplayText -match 'pusfume_aggressive_iteration_ready' -and `
    $gameplayText -match 'buff_system:add_buff\(owner_unit, buff_name, owner_unit, false\)' -and `
    $gameplayText -notmatch 'pusfume_scheme_kill_skaven') `
    "Aggressive Iteration" "special kills capture a mapped power and synchronize readiness"
Test-Condition ($registryText -match 'career\.attributes\.max_hp\s*=\s*100') `
    "career health" "v2 specification fixes Pusfume at 100 maximum health"
Test-Condition ($registryText -match 'min_health_percentage\[career_name\]\s*=\s*\{\s*name\s*=\s*career_name,\s*value\s*=\s*1' -and `
    $registryText -match 'min_health_completed\[career_name\]\s*=\s*\{\s*name\s*=\s*career_name,' -and `
    $registryText -match 'career_levels\[level_key\]\[diff\]\s*=\s*\{\s*name\s*=\s*diff,') `
    "late statistics definitions" "all Pusfume leaves carry boot-time name metadata before player registration"
Test-Condition ($nativeBuildText -match '\$cutAlphaEnabled = "false"' -and `
    $nativeBuildText -match 'enable_cut_alpha_threshold = \$cutAlphaEnabled' -and `
    $nativeBuildText -notmatch '\$Name -eq "pusfume_whiskers_df"') `
    "whisker alpha" "fractional whisker coverage survives texture compilation for the native alpha shader"
Test-Condition ($preflightText -match 'add\(checks, "career color"') `
    "career color" "runtime preflight validates the player-list contract"
Test-Condition ($backendText -match 'mod:hook\(BackendUtils, "get_loadout_item"' -and `
    $backendText -match 'weapons\.item_for_slot\(slot_name\)') `
    "spawn guard" "BackendUtils resolves Pusfume's fixed weapon items before donor aliases"
Test-Condition ($backendText -match 'function expose_donor_loadout' -and `
    $backendText -match 'donor_loadout = \{\}') `
    "loadout UI guard" "direct loadout table always exposes an iterable Pusfume entry"
Test-Condition ($backendText -match 'function M\.refresh_runtime_aliases' -and `
    $backendText -match 'store\[registry\.CAREER_NAME\] = weapons\.overlay_loadout') `
    "loadout UI guard" "backend stores retain donor cosmetics while overlaying Pusfume's own weapons"
Test-Condition ($preflightText -match 'direct_loadouts.*item_interface:get_loadout\(\)' -and `
    $preflightText -match 'type\(direct_loadout\) == "table"') `
    "loadout UI guard" "preflight exercises the exact vanilla tooltip table API"
Test-Condition ($uiText -match 'request_spawn_hero_unit\(hero_name,' -and `
    $uiText -match 'window\._selected_career_index, true, spawn_callback') `
    "native selector preview" "Pusfume forces its base skin instead of the equipped Ranger skin"
Test-Condition ($uiText -match 'mod:hook_safe\(UnitFramesHandler, "_sync_player_stats"' -and `
    $uiText -match 'widget:set_portrait\("portrait_pusfume"\)' -and `
    $preflightText -match 'add\(checks, "live HUD portrait hook"') `
    "live HUD portrait" "custom portrait is reasserted after other unit-frame hooks"
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
        "get_loadout", "get_bot_loadout", "get_all_backend_items", "set_loadout_index", "add_loadout", "delete_loadout",
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
$actualGuardCount = [regex]::Matches($backendText, 'mod:hook\(BackendUtils,').Count + `
    [regex]::Matches($backendText, 'mod:hook\(ItemGridUI,').Count
Test-Condition ($declaredGuardCount -eq $actualGuardCount) `
    "runtime guard accounting" "$declaredGuardCount loadout and inventory methods"

$trackedBundleFiles = @(git -C $repoRoot ls-files "pusfume/bundleV2/**")
Test-Condition ($trackedBundleFiles.Count -eq 0) "generated output" "bundleV2 is not tracked"

if ($failures -gt 0) {
    Write-Error "Pusfume source preflight failed with $failures error(s)."
}

Write-Host "Pusfume source preflight passed."
