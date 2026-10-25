[CmdletBinding()]
param(
    [string]$OutputDirectory = '.temp/release-performance/current'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$outputRoot = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $projectRoot $OutputDirectory }))
$temporaryRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.temp'))
if (-not $outputRoot.StartsWith($temporaryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDirectory must be a task directory below this workspace .temp directory.'
}
# Reject links along generated/retired paths before creating or moving anything.
foreach ($target in @($outputRoot, (Join-Path $projectRoot '.delete/release-performance'))) {
    $ancestor = $target
    while ($ancestor -and $ancestor.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) {
        if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Benchmark path contains a junction or symbolic link: $ancestor"
        }
        if ($ancestor -eq $projectRoot) { break }
        $ancestor = Split-Path $ancestor
    }
}
$copyRoot = Join-Path $outputRoot 'project'
$retiredRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot ('.delete/release-performance/' + [Guid]::NewGuid().ToString('N'))))
if (-not $retiredRoot.StartsWith((Join-Path $projectRoot '.delete') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Retired benchmark directory escaped workspace .delete.'
}
if (Test-Path -LiteralPath $outputRoot) {
    # Verify the existing absolute source in addition to the lexical check.
    $resolvedOutput = (Resolve-Path -LiteralPath $outputRoot).ProviderPath
    if (-not $resolvedOutput.StartsWith($temporaryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Existing benchmark directory resolved outside workspace .temp.'
    }
    New-Item -ItemType Directory -Path (Split-Path $retiredRoot) -Force | Out-Null
    Move-Item -LiteralPath $outputRoot -Destination $retiredRoot
}
New-Item -ItemType Directory -Path $copyRoot -Force | Out-Null
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw -Encoding utf8 | ConvertFrom-Json
$sourceFiles = @('project.godot', 'export_presets.cfg', 'tools/godot/godot.ps1', 'tools/godot/toolchain.json',
    'tests/godot/test_visual_quality.gd', 'Keyabyss.csproj', 'packages.ExportRelease.lock.json',
    'game/spells/spell_runtime.gd', 'game/session/battle_session.gd', 'game/combat/battle_threat.gd', 'ui/lightning_arc.gd', 'ui/battle_visuals.gd',
    'ui/battle_threat_glow.gd', 'app/debug_log.gd',
    'ui/effects/fluid_field_2d.gd', 'ui/effects/fluid_atmosphere.gd', 'ui/effects/ThreatRibbonGeometry.cs',
    'ui/effects/LightningGeometry.cs', 'ui/effects/FluidMotionKernel.cs', 'ui/render_preparation.gd')
$manifestPath = Join-Path $outputRoot 'manifest.json'
$manifest = [ordered]@{
    createdUtc = [DateTime]::UtcNow.ToString('o')
    sourceRoot = $projectRoot
    outputRoot = $outputRoot
    rootHead = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    sourceStatus = @(& git -C $projectRoot status --short --untracked-files=normal)
    engineVersion = $lock.engineVersion
    configuration = 'ExportRelease'
    template = [ordered]@{ directory = $lock.windowsTemplateDirectory; asset = $lock.templateAsset; assetSha512 = $lock.templateSha512 }
    status = 'preparing'
    sourceHashes = @()
    commands = @()
    artifacts = @()
}
foreach ($relative in $sourceFiles) {
    $manifest.sourceHashes += [ordered]@{ path = $relative; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $relative) -Algorithm SHA256).Hash.ToLowerInvariant() }
}

try {
    # Copy saved workspace contents, including uncommitted runtime changes.
    foreach ($relative in @($lock.runtimeDirectories) + @($lock.runtimeFiles)) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $copyRoot -Recurse
    }
    foreach ($relative in @('export_presets.cfg', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'licenses')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $copyRoot -Recurse
    }
    $copiedTools = Join-Path $copyRoot 'tools/godot'
    New-Item -ItemType Directory -Path $copiedTools -Force | Out-Null
    foreach ($name in @('godot.ps1', 'toolchain.json')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $copiedTools
    }
    $localPaths = Join-Path $PSScriptRoot 'local.paths.json'
    if (Test-Path -LiteralPath $localPaths) { Copy-Item -LiteralPath $localPaths -Destination $copiedTools }
    foreach ($relative in @('legacy/web/licenses/CMUdict-LICENSE.txt', 'legacy/web/licenses/Qwerty-Learner-GPL-3.0.txt')) {
        $destination = Join-Path $copyRoot $relative
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $destination
    }
    $harnessRoot = Join-Path $copyRoot 'performance_harness'
    New-Item -ItemType Directory -Path $harnessRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'tests/godot/test_visual_quality.gd') -Destination (Join-Path $harnessRoot 'visual_quality.gd')
    $utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText((Join-Path $harnessRoot 'release_loop.gd'), "class_name ReleasePerformanceLoop`nextends `"res://performance_harness/visual_quality.gd`"`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $harnessRoot 'empty.tscn'), "[gd_scene format=3]`n`n[node name=`"PerformanceHarness`" type=`"Node`"]`n", $utf8)
    $projectFile = Join-Path $copyRoot 'project.godot'
    $settings = [IO.File]::ReadAllText($projectFile)
    if ($settings -notmatch '(?m)^run/main_scene=' -or $settings -notmatch '(?m)^config/custom_user_dir_name=') {
        throw 'Source project application settings changed; review generated entry transformation.'
    }
    $settings = $settings -replace '(?m)^run/main_scene=.*$', 'run/main_scene="res://performance_harness/empty.tscn"'
    $settings = $settings -replace '(?m)^config/custom_user_dir_name=.*$', 'config/custom_user_dir_name="Keyabyss-Release-Performance"'
    if ($settings -match '(?m)^run/main_loop_type=') {
        $settings = $settings -replace '(?m)^run/main_loop_type=.*$', 'run/main_loop_type="ReleasePerformanceLoop"'
    } else {
        $settings = $settings.Replace('[application]', "[application]`nrun/main_loop_type=`"ReleasePerformanceLoop`"")
    }
    [IO.File]::WriteAllText($projectFile, $settings, $utf8)
    $manifest.generatedProjectSha256 = (Get-FileHash -LiteralPath $projectFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest.harnessSha256 = (Get-FileHash -LiteralPath (Join-Path $harnessRoot 'visual_quality.gd') -Algorithm SHA256).Hash.ToLowerInvariant()
    $copiedDriver = Join-Path $copiedTools 'godot.ps1'
    foreach ($task in @('import', 'export-release')) {
        $logPath = Join-Path $outputRoot ($task + '.log')
        $manifest.status = $task
        $manifest.commands += [ordered]@{ executable = (Join-Path $PSHOME 'pwsh.exe'); arguments = @('-NoProfile', '-File', $copiedDriver, '-Task', $task); log = $logPath }
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8
        Write-Output "Benchmark ${task}: $logPath"
        & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $copiedDriver -Task $task 2>&1 | Out-File -LiteralPath $logPath -Encoding utf8
        $engineExitCode = $LASTEXITCODE
        $manifest.commands[-1].exitCode = $engineExitCode
        if ($engineExitCode -ne 0) {
            Get-Content -LiteralPath $logPath -Tail 40
            throw "Benchmark $task failed ($engineExitCode); inspect $logPath"
        }
    }
    $exportRoot = Join-Path $copyRoot 'builds/windows-release'
    foreach ($relative in @('keyabyss.exe', 'keyabyss.pck', 'data_Keyabyss_windows_x86_64/Keyabyss.dll')) {
        $artifact = Join-Path $exportRoot $relative
        $manifest.artifacts += [ordered]@{ path = $artifact; bytes = (Get-Item -LiteralPath $artifact).Length; sha256 = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $manifest.status = 'exported'
    Write-Output "Release benchmark exported: $exportRoot"
    Write-Output 'Run baseline and extreme separately with --combat and --output-root; this script does not start the exported game.'
} catch {
    $manifest.status = 'failed'
    $manifest.error = $_.Exception.Message
    throw
} finally {
    $manifest.rootConfigurationAfter = @('project.godot', 'export_presets.cfg') | ForEach-Object {
        [ordered]@{ path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8
}
