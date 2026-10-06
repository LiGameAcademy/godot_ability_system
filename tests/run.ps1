param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string[]]$Cases = @(),
    [switch]$SkipImport
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$hostPath = Join-Path $repo '.regression'
New-Item -ItemType Directory -Force $hostPath | Out-Null
# Rebuild only these generated folders; otherwise tests from a previous branch survive.
foreach ($folder in @('scripts', 'tests')) {
    $generatedPath = [IO.Path]::GetFullPath((Join-Path $hostPath $folder))
    if (-not $generatedPath.StartsWith([IO.Path]::GetFullPath($hostPath) + [IO.Path]::DirectorySeparatorChar)) {
        throw 'Generated path escaped the regression host.'
    }
    if (Test-Path -LiteralPath $generatedPath) {
        Remove-Item -LiteralPath $generatedPath -Recurse -Force
    }
}
Copy-Item -LiteralPath (Join-Path $repo 'scripts') -Destination $hostPath -Recurse -Force
Copy-Item -LiteralPath $PSScriptRoot -Destination $hostPath -Recurse -Force
# These two optional integrations require game-owned classes (tracked in Issue #1).
# Tests use the real remaining production scripts and real production autoloads.
Remove-Item -LiteralPath (Join-Path $hostPath 'scripts/abilities/features/effect_modifer_feature.gd') -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $hostPath 'scripts/abilities/targeting/strategies/hit_detector/melee_box_hit_detector.gd') -ErrorAction SilentlyContinue
@'
config_version=5
[application]
config/name="GAS regression tests"
[autoload]
GameplayAbilitySystem="*res://scripts/singletons/gameplay_ability_system.gd"
TagManager="*res://scripts/singletons/gameplay_tag_manager.gd"
AbilityEventBus="*res://scripts/singletons/ability_event_bus.gd"
DamageCalculator="*res://scripts/singletons/damage_calculator.gd"
GameplayCueManager="*res://scripts/singletons/gameplay_cue_manager.gd"
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $hostPath 'project.godot') -Encoding utf8
if (-not $SkipImport) {
    & $Godot --headless --path $hostPath --editor --import 2>&1 | Tee-Object -Variable importOutput
    if ($LASTEXITCODE -ne 0 -or ($importOutput -match 'SCRIPT ERROR|Parse Error|Failed to load script')) {
        throw 'Regression host import failed.'
    }
} elseif (-not (Test-Path -LiteralPath (Join-Path $hostPath '.godot/global_script_class_cache.cfg'))) {
    throw 'SkipImport requires a previously imported regression host.'
}
& $Godot --headless --path $hostPath --script res://tests/runner.gd -- @Cases 2>&1 | Tee-Object -Variable testOutput
if ($LASTEXITCODE -ne 0 -or ($testOutput -match 'SCRIPT ERROR|Parse Error|Failed to load script')) {
    throw "Regression tests failed ($LASTEXITCODE)."
}
