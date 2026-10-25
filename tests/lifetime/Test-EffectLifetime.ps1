param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$OutputDirectory = "",
    [switch]$Rendered
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (!$OutputDirectory) { $OutputDirectory = Join-Path $env:TEMP ('gas-effect-lifetime-' + [guid]::NewGuid().ToString('N')) }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$hostRoot = Join-Path $OutputDirectory 'host'
if (Test-Path -LiteralPath $hostRoot) { throw "Use a new output directory; existing host will not be overwritten: $hostRoot" }
$addon = Join-Path $hostRoot 'addons/godot_ability_system'
New-Item -ItemType Directory -Force $addon | Out-Null
foreach ($folder in @('scripts', 'assets', 'ui', 'examples')) {
    Copy-Item -LiteralPath (Join-Path $repo $folder) -Destination $addon -Recurse
}
$tests = Join-Path $addon 'tests'
New-Item -ItemType Directory -Force $tests | Out-Null
Copy-Item -LiteralPath $PSScriptRoot -Destination $tests -Recurse
@'
config_version=5
[application]
config/name="GAS Effect Lifetime"
[autoload]
GameplayAbilitySystem="*res://addons/godot_ability_system/scripts/singletons/gameplay_ability_system.gd"
DamageCalculator="*res://addons/godot_ability_system/scripts/singletons/damage_calculator.gd"
TagManager="*res://addons/godot_ability_system/scripts/singletons/gameplay_tag_manager.gd"
AbilityEventBus="*res://addons/godot_ability_system/scripts/singletons/ability_event_bus.gd"
GameplayCueManager="*res://addons/godot_ability_system/scripts/singletons/gameplay_cue_manager.gd"
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $hostRoot 'project.godot') -Encoding utf8
$failed = $false
foreach ($phase in @('import', 'load_only', 'instances')) {
    $log = Join-Path $OutputDirectory ($phase + '.log')
    $arguments = @('--headless', '--path', ('"' + $hostRoot + '"'), '--log-file', ('"' + $log + '.engine"'))
    if ($phase -eq 'import') { $arguments += @('--editor', '--import') }
    elseif ($phase -eq 'load_only') { $arguments += @('--script', "res://addons/godot_ability_system/tests/lifetime/load_only.gd") }
    else { $arguments += "res://addons/godot_ability_system/tests/lifetime/instances.tscn" }
    if ($Rendered -and $phase -ne 'import') { $arguments = @($arguments | Where-Object { $_ -ne '--headless' }) }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError ($log + '.stderr')
    $timedOut = $false
    try {
        while (!$process.WaitForExit(1000)) {
            if ($watch.Elapsed.TotalSeconds -ge 120) {
                $timedOut = $true
                $process.Kill($true)
                $process.WaitForExit()
                break
            }
        }
        $code = $process.ExitCode
    } finally { $watch.Stop(); $process.Dispose() }
    $text = (Get-Content -LiteralPath $log -Raw) + (Get-Content -LiteralPath ($log + '.stderr') -Raw)
    $valid = !$timedOut -and $null -ne $code -and $code -eq 0 -and $text -notmatch 'ERROR:|SCRIPT ERROR|Parse Error|Failed to load script|leaked at exit|GAS_EFFECT_.*FAIL'
    if ($phase -eq 'load_only') { $valid = $valid -and $text -match 'GAS_EFFECT_LOAD_PASS' }
    if ($phase -eq 'instances') { $valid = $valid -and $text -match 'GAS_EFFECT_INSTANCES_PASS' }
    [pscustomobject]@{ phase=$phase; exit_code=$code; timed_out=$timedOut; elapsed_ms=$watch.Elapsed.TotalMilliseconds; rendered=[bool]$Rendered; validation_pass=[bool]$valid } | ConvertTo-Json | Set-Content -LiteralPath ($log + '.result.json') -Encoding utf8
    Write-Output "$phase validation_pass=$valid; log=$log"
    $failed = $failed -or !$valid
    if ($timedOut -or $text -match 'SCRIPT ERROR|Parse Error|Failed to load script') { break }
}
if ($failed) { throw "Effect lifecycle failed; see $OutputDirectory" }
Write-Output 'GAS effect lifecycle PASS (resource checks, not a simulation-frame benchmark).'
