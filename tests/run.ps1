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
$generatedFolders = @('scripts', 'tests', 'examples', 'assets', 'ui', 'addons')
if (-not $SkipImport) { $generatedFolders += '.godot' }
foreach ($folder in $generatedFolders) {
    $generatedPath = [IO.Path]::GetFullPath((Join-Path $hostPath $folder))
    if (-not $generatedPath.StartsWith([IO.Path]::GetFullPath($hostPath) + [IO.Path]::DirectorySeparatorChar)) {
        throw 'Generated path escaped the regression host.'
    }
    if (Test-Path -LiteralPath $generatedPath) {
        Remove-Item -LiteralPath $generatedPath -Recurse -Force
    }
}
$pluginPath = Join-Path $hostPath 'addons/gas_regression_plugin'
New-Item -ItemType Directory -Force $pluginPath | Out-Null
foreach ($folder in @('scripts', 'examples', 'assets', 'ui')) {
    Copy-Item -LiteralPath (Join-Path $repo $folder) -Destination $pluginPath -Recurse -Force
}
foreach ($file in @('plugin.gd', 'plugin.cfg')) {
    Copy-Item -LiteralPath (Join-Path $repo $file) -Destination $pluginPath -Force
}
Copy-Item -LiteralPath $PSScriptRoot -Destination $hostPath -Recurse -Force
@'
config_version=5
[application]
config/name="GAS regression tests"
[autoload]
GameplayAbilitySystem="*res://addons/gas_regression_plugin/scripts/singletons/gameplay_ability_system.gd"
TagManager="*res://addons/gas_regression_plugin/scripts/singletons/gameplay_tag_manager.gd"
AbilityEventBus="*res://addons/gas_regression_plugin/scripts/singletons/ability_event_bus.gd"
DamageCalculator="*res://addons/gas_regression_plugin/scripts/singletons/damage_calculator.gd"
GameplayCueManager="*res://addons/gas_regression_plugin/scripts/singletons/gameplay_cue_manager.gd"
[editor_plugins]
enabled=PackedStringArray("res://addons/gas_regression_plugin/plugin.cfg")
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $hostPath 'project.godot') -Encoding utf8
if (-not $SkipImport) {
    & $Godot --headless --path $hostPath --editor --import --quit 2>&1 | Tee-Object -Variable importOutput
    if ($LASTEXITCODE -ne 0 -or ($importOutput -match '^ERROR:|SCRIPT ERROR|Parse Error|Failed to load script')) {
        throw 'Regression host import failed.'
    }
} elseif (-not (Test-Path -LiteralPath (Join-Path $hostPath '.godot/global_script_class_cache.cfg'))) {
    throw 'SkipImport requires a previously imported regression host.'
}
& $Godot --headless --path $hostPath --script res://tests/runner.gd -- @Cases 2>&1 | Tee-Object -Variable testOutput
if ($LASTEXITCODE -ne 0 -or ($testOutput -match 'SCRIPT ERROR|Parse Error|Failed to load script')) {
    throw "Regression tests failed ($LASTEXITCODE)."
}
