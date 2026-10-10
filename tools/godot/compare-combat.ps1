[CmdletBinding()]
param(
    [string]$Reference = 'c39c032',
    [switch]$GenerateOnly,
    [switch]$Benchmark,
    [switch]$BenchmarkOnly,
    [switch]$DodgeOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location -LiteralPath $projectRoot
try {
    $revision = (& git rev-parse --verify "$Reference^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $revision -notmatch '^[0-9a-f]{40}$') { throw 'Invalid reference commit.' }
    $relative = ".temp/combat-comparison/$revision"
    $destination = Join-Path $projectRoot $relative
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $battle = (& git show "${revision}:game/session/battle_session.gd") -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read reference BattleSession.' }
    $runtime = (& git show "${revision}:game/spells/spell_runtime.gd") -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read reference SpellRuntime.' }
    $battleStart = $battle.IndexOf('func _remember_lock()')
    $runtimeStart = $runtime.IndexOf('func install(')
    if ($battleStart -lt 0 -or $runtimeStart -lt 0) { throw 'Reference layout changed; review the comparison adapter.' }
    # Inherit the current data declarations; override all baseline rule methods.
    # No reference gameplay source is edited or installed into the active game.
    $battle = "extends BattleSession`n`n" + $battle.Substring($battleStart)
    $battle = $battle.Replace('SpellRuntime.new(', "load(`"res://$relative/runtime_reference.gd`").new(")
    $battle = $battle.Replace('var candidates := runtime.arc_targets(effect, effect.origin)', 'var candidates: Array[BattleEnemy] = runtime.call("arc_targets", effect, effect.origin)')
    $runtime = "extends SpellRuntime`n`nfunc _init(session: BattleSession, combat_build: CompiledBuild, state: RunCombatState) -> void:`n`tsuper(session, combat_build, state)`n`n" + $runtime.Substring($runtimeStart)
    [IO.File]::WriteAllText((Join-Path $destination 'battle_reference.gd'), $battle + "`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $destination 'runtime_reference.gd'), $runtime + "`n", [Text.UTF8Encoding]::new($false))
    Write-Output "Reference: $revision"
    Write-Output "Generated: $destination"
    if ($GenerateOnly) { return }
    $arguments = @('--headless', '--debug', '--ignore-error-breaks', '--script', 'res://tests/godot/test_combat_algorithms.gd', '--', "--reference=res://$relative/battle_reference.gd")
    if ($Benchmark -or $BenchmarkOnly) { $arguments += '--benchmark' }
    if ($BenchmarkOnly) { $arguments += '--benchmark-only' }
    if ($DodgeOnly) { $arguments += '--dodge-only' }
    & (Join-Path $PSScriptRoot 'godot.ps1') run @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Combat comparison failed.' }
} finally { Pop-Location }
