# Godot 4.7 headless regressions

Run `./tests/run.ps1 -Godot /absolute/path/to/godot.exe` in PowerShell.
Use `-Cases issue_34` to select a case; omit it to run all cases.
After the first import, `-SkipImport` runs against the cached class registry.
Re-import when adding/removing global classes; changed scripts compile during the run.

The generated ignored `.regression` host installs all production scripts, examples,
UI and assets under `addons/gas_regression_plugin` and enables the real editor plugin.
No production files are excluded. A full import rebuilds the generated import cache;
use it when changing global classes, the installation layout, or resource references.
No ability, cost, vital, effect, or behavior-tree production implementation is mocked.
Cases use lightweight fixtures to count lifecycle calls and observe outcomes.
An import error or a failed assertion exits with failure.

`issue_1` loads the bundled scenes/resources, runs all four example scenes, checks
modifier instance isolation, and runs a real physics query with caster exclusion.
Cases may await physics/process frames; invalid case scripts fail without hanging.
Some negative cases deliberately print diagnostics. Exit-time resource retention
is reported separately; passing behavior assertions does not prove leak-free shutdown.
