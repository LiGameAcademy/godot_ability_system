param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string[]]$Cases = @()
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$hostPath = Join-Path $repo '.regression'
New-Item -ItemType Directory -Force $hostPath | Out-Null
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
& $Godot --headless --path $hostPath --editor --import 2>&1 | Tee-Object -Variable importOutput
if ($LASTEXITCODE -ne 0 -or ($importOutput -match 'SCRIPT ERROR|Parse Error|Failed to load script')) {
    throw 'Regression host import failed.'
}
& $Godot --headless --path $hostPath --script res://tests/runner.gd -- @Cases
if ($LASTEXITCODE -ne 0) { throw "Regression tests failed ($LASTEXITCODE)." }
