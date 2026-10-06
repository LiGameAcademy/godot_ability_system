# Godot 4.7 headless regressions

Run `./tests/run.ps1 -Godot /absolute/path/to/godot_console.exe` in PowerShell.
Use `-Cases issue_34` to select a case; omit it to run all cases.

The generated ignored `.regression` host imports copies of the actual production
scripts and registers the actual autoloads. It excludes the two optional integrations
requiring `TalentEffectModifier` and `DebugDraw` (Issue #1), and game-dependent examples/UI.
No ability, cost, vital, effect, or behavior-tree production implementation is mocked.
Cases use lightweight fixtures to count lifecycle calls and observe outcomes.
An import error or a failed assertion exits with failure.
