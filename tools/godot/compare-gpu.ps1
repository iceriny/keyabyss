[CmdletBinding()]
param(
    [ValidateSet('baseline', 'extreme')][string]$Workload = 'baseline',
    [string]$Reference = 'ad5fe67',
    [ValidatePattern('^[a-z0-9-]*$')][string]$Label = '',
    [switch]$GenerateOnly
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location -LiteralPath $root
try {
    $revision = (& git rev-parse --verify "$Reference^{commit}" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Invalid GPU reference revision.' }
    $relative = ".temp/gpu-compute-20261025/reference/$revision"
    $destination = Join-Path $root $relative
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $manifest = [ordered]@{ revision = $revision; sources = @() }
    foreach ($name in @('frost_growth', 'fluid_gpu')) {
        $shaderName = if ($name -eq 'fluid_gpu') { 'fluid_solver' } else { $name }
        $script = (& git show "${revision}:ui/effects/$name.gd") -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Cannot read reference $name.gd" }
        $shader = (& git show "${revision}:ui/effects/$shaderName.glsl") -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Cannot read reference $shaderName.glsl" }
        # Generated reference only: supply the exact old GLSL as an RDShaderFile
        # at runtime, without importing hidden files or changing production code.
        $script = $script -replace '^class_name [^\n]+\n', ''
        $declaration = "const SHADER: RDShaderFile = preload(`"res://ui/effects/$shaderName.glsl`")"
        if (-not $script.Contains($declaration)) { throw 'Reference layout changed; review the adapter.' }
        $script = $script.Replace($declaration, 'var reference_shader: RDShaderFile')
        $script = $script.Replace('EffectPipeline.acquire(SHADER)', 'EffectPipeline.acquire(reference_shader)')
        [IO.File]::WriteAllText((Join-Path $destination "$name.gd"), $script + "`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $destination "$shaderName.glsl"), $shader + "`n", [Text.UTF8Encoding]::new($false))
        $manifest.sources += [ordered]@{ script = $name; shader = $shaderName; shaderSha256 = (Get-FileHash -LiteralPath (Join-Path $destination "$shaderName.glsl") -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $destination 'manifest.json') -Encoding utf8
    Write-Output "GPU reference: $revision"
    if ($GenerateOnly) { return }
    $evidence = Join-Path $root '.temp/gpu-compute-20261025'
    $env:APPDATA = Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    $stem = if ($Label) { "$Label-$Workload" } else { $Workload }
    & (Join-Path $PSScriptRoot 'godot.ps1') -Task run -EngineArguments @('--debug', '--ignore-error-breaks', '--script', 'res://tests/godot/test_gpu_compute.gd', '--log-file', (Join-Path $evidence "$stem.log"), '--', "--workload=$Workload", "--reference=res://$relative", "--label=$Label", '--gpu-profile')
    if ($LASTEXITCODE -ne 0) { throw 'GPU comparison failed; inspect the report and engine log.' }
} finally { Pop-Location }
