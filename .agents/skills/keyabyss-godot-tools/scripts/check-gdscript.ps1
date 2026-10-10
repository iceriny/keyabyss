[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Scripts
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$prefix = $root + [IO.Path]::DirectorySeparatorChar
$targets = foreach ($entry in $Scripts) {
    $relative = if ($entry.StartsWith('res://')) { $entry.Substring(6) } else { $entry }
    $absolute = [IO.Path]::GetFullPath($relative, $root)
    if (-not $absolute.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetExtension($absolute) -ne '.gd' -or
        -not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
        throw "Expected an existing .gd file inside the project: $entry"
    }
    $absolute
}
$targets = @($targets | Select-Object -Unique)

# Reuse the project's version, executable hash and SDK checks without a build.
& pwsh -NoProfile -File (Join-Path $root 'tools/godot/godot.ps1') doctor
if ($LASTEXITCODE -ne 0) { throw 'Toolchain doctor failed; inspect its output.' }
$engine = $env:GODOT_PATH
if (-not $engine) {
    $engine = (Get-Content -LiteralPath (Join-Path $root 'tools/godot/local.paths.json') -Raw -Encoding utf8 | ConvertFrom-Json).godot
}
$lock = Get-Content -LiteralPath (Join-Path $root 'tools/godot/toolchain.json') -Raw -Encoding utf8 | ConvertFrom-Json
$runId = 'check-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$evidence = Join-Path $root ('.temp/skill-tools/' + $runId)
New-Item -ItemType Directory -Path $evidence | Out-Null
$head = (& git -C $root rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot read source Git HEAD.' }
$status = @(& git -C $root status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Cannot read source Git status.' }
$results = @()
$failed = $false

for ($index = 0; $index -lt $targets.Count; $index++) {
    $target = $targets[$index]
    $resource = 'res://' + [IO.Path]::GetRelativePath($root, $target).Replace('\', '/')
    $sourceHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $stem = '{0:D2}-{1}' -f ($index + 1), [IO.Path]::GetFileNameWithoutExtension($target)
    $log = Join-Path $evidence ($stem + '.engine.log')
    # Keep debug warnings but prevent parser errors from opening the stdin debugger.
    $arguments = @('--headless', '--path', $root, '--debug', '--ignore-error-breaks', '--check-only', '--script', $resource, '--log-file', $log)
    Write-Output "Checking $resource"
    $output = @(& $engine @arguments 2>&1 | ForEach-Object { $_.ToString() })
    $engineExitCode = $LASTEXITCODE
    $output | Set-Content -LiteralPath (Join-Path $evidence ($stem + '.output.log')) -Encoding utf8
    $output | ForEach-Object { Write-Output $_ }
    $logLines = if (Test-Path -LiteralPath $log) { @(Get-Content -LiteralPath $log -Encoding utf8) } else { @() }
    $diagnostics = @(@($output) + @($logLines) | Where-Object {
        $_ -match '(SCRIPT ERROR:|(^|\s)ERROR:|(^|\s)WARNING:)'
    } | Select-Object -Unique)
    $sourceChanged = $sourceHash -ne (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $passed = $engineExitCode -eq 0 -and $diagnostics.Count -eq 0 -and -not $sourceChanged
    if (-not $passed) { $failed = $true }
    $results += [ordered]@{
        script = $resource
        sourceSha256 = $sourceHash
        arguments = $arguments
        engineExitCode = $engineExitCode
        diagnostics = $diagnostics
        sourceChangedDuringCheck = $sourceChanged
        passed = $passed
        engineLog = $log
    }
}
$report = [ordered]@{
    createdUtc = [DateTime]::UtcNow.ToString('o')
    projectRoot = $root
    sourceHead = $head
    sourceStatus = $status
    engineVersion = $lock.engineVersion
    checks = $results
    passed = -not $failed
    scope = 'Explicit scripts and diagnostics emitted by their parse dependency chain; no runtime or editor validation.'
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'report.json') -Encoding utf8
Write-Output "Evidence: $evidence"
if ($failed) { exit 1 }
exit 0
