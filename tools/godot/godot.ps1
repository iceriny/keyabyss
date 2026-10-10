[CmdletBinding()]
param(
    [ValidateSet('doctor', 'import', 'run', 'editor', 'preview', 'export', 'export-release')]
    [string]$Task = 'doctor',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$EngineArguments = @()
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw -Encoding utf8 | ConvertFrom-Json
$localConfig = Join-Path $PSScriptRoot 'local.paths.json'
$godotPath = $env:GODOT_PATH
if (-not $godotPath -and (Test-Path -LiteralPath $localConfig)) {
    $godotPath = (Get-Content -LiteralPath $localConfig -Raw -Encoding utf8 | ConvertFrom-Json).godot
}
if (-not $godotPath -or -not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw 'Set GODOT_PATH or copy local.paths.example.json to local.paths.json and set godot.'
}
$version = (& $godotPath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne $lock.engineVersion) {
    throw "Engine mismatch: expected $($lock.engineVersion), got $version"
}

function Assert-DotNetSdk([string]$Root) {
    Push-Location -LiteralPath $Root
    try {
        $sdkVersion = (& dotnet --version | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $sdkVersion -ne $lock.dotnetSdkVersion) {
            throw ".NET SDK mismatch: expected $($lock.dotnetSdkVersion), got $sdkVersion"
        }
    } finally { Pop-Location }
    return $sdkVersion
}

function Build-ManagedDebug([string]$Root) {
    Push-Location -LiteralPath $Root
    try {
        & dotnet build Keyabyss.csproj --configuration Debug -p:RestoreLockedMode=true --nologo
        if ($LASTEXITCODE -ne 0) { throw 'Managed Debug build failed; inspect the dotnet output.' }
    } finally { Pop-Location }
}

$sdkVersion = Assert-DotNetSdk $projectRoot
if ($Task -in @('import', 'run', 'editor')) { Build-ManagedDebug $projectRoot }

switch ($Task) {
    'doctor' {
        $hash = (Get-FileHash -LiteralPath $godotPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $lock.engineConsoleSha256) { throw 'Engine executable SHA256 differs from toolchain.json.' }
        Write-Output "Godot: $version"
        Write-Output "Executable: $godotPath"
        Write-Output "Project: $projectRoot"
        Write-Output ".NET SDK: $sdkVersion"
        Write-Output "MCP built: $(Test-Path -LiteralPath (Join-Path $projectRoot '.tools/godot-mcp/build/index.js'))"
        Write-Output "Windows templates: $(Test-Path -LiteralPath (Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable.mono/windows_release_x86_64.exe'))"
        return
    }
    'preview' {
        # This generated copy is the only project to which the MCP injects its bridge.
        $preview = [IO.Path]::GetFullPath((Join-Path $projectRoot '.temp/godot-mcp/project'))
        $retired = [IO.Path]::GetFullPath((Join-Path $projectRoot ('.delete/godot-preview/' + [Guid]::NewGuid().ToString('N'))))
        foreach ($candidate in @($preview, $retired)) {
            if (-not $candidate.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar)) { throw 'Path escaped project.' }
        }
        if (Get-NetTCPConnection -LocalPort 9090 -State Listen -ErrorAction SilentlyContinue) {
            throw 'Stop the active MCP game before refreshing the preview (port 9090 is in use).'
        }
        if (Test-Path -LiteralPath $preview) {
            New-Item -ItemType Directory -Path (Split-Path $retired) -Force | Out-Null
            Move-Item -LiteralPath $preview -Destination $retired
        }
        New-Item -ItemType Directory -Path $preview -Force | Out-Null
        foreach ($name in @($lock.runtimeDirectories) + @($lock.runtimeFiles)) {
            $source = Join-Path $projectRoot $name
            if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $preview -Recurse }
        }
        $bridge = Join-Path $projectRoot '.tools/godot-mcp/build/scripts/mcp_interaction_server.gd'
        if (-not (Test-Path -LiteralPath $bridge)) { throw 'Build the pinned MCP before preparing a preview.' }
        Copy-Item -LiteralPath $bridge -Destination (Join-Path $preview 'mcp_interaction_server.gd')
        # HDR viewport captures are linear. Convert only the generated bridge's
        # PNG output to sRGB, otherwise visual review sees an artificially dark image.
        $previewBridge = Join-Path $preview 'mcp_interaction_server.gd'
        $bridgeSource = [IO.File]::ReadAllText($previewBridge)
        $captureConversion = @'
	if get_viewport().use_hdr_2d:
		var encoded := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				encoded.set_pixel(x, y, image.get_pixel(x, y).linear_to_srgb())
		image = encoded
	var png_buffer: PackedByteArray = image.save_png_to_buffer()
'@
        $bridgeSource = $bridgeSource.Replace("`tvar png_buffer: PackedByteArray = image.save_png_to_buffer()", $captureConversion)
        [IO.File]::WriteAllText($previewBridge, $bridgeSource, [Text.UTF8Encoding]::new($false))
        $projectFile = Join-Path $preview 'project.godot'
        $settings = [IO.File]::ReadAllText($projectFile)
        # Keep preview imports and settings out of the player's real user directory.
        $settings = $settings.Replace('config/custom_user_dir_name="Keyabyss"', 'config/custom_user_dir_name="Keyabyss-M1-Preview"')
        $bridgeEntry = 'McpInteractionServer="*res://mcp_interaction_server.gd"'
        if ($settings.Contains('[autoload]')) {
            $settings = $settings.Replace('[autoload]', "[autoload]`n$bridgeEntry")
        } else { $settings += "`n[autoload]`n$bridgeEntry`n" }
        [IO.File]::WriteAllText($projectFile, $settings, [Text.UTF8Encoding]::new($false))
        Build-ManagedDebug $preview
        $output = & $godotPath --headless --path $preview --editor --import 2>&1
        $engineExitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Output $_ }
        if ($engineExitCode -ne 0 -or ($output | Select-String -Pattern 'SCRIPT ERROR:|^ERROR:')) { throw "Preview import failed (exit code $engineExitCode); inspect the Godot output." }
        Write-Output "MCP projectPath: $preview"
        return
    }
    'import' { $arguments = @('--headless', '--path', $projectRoot, '--editor', '--import') }
    'run' { $arguments = @('--path', $projectRoot) }
    'editor' { $arguments = @('--path', $projectRoot, '--editor') }
    { $_ -in @('export', 'export-release') } {
        $managedConfiguration = if ($Task -eq 'export-release') { 'ExportRelease' } else { 'ExportDebug' }
        Push-Location -LiteralPath $projectRoot
        try {
            # Check the actual Godot SDK configuration without compiling twice.
            & dotnet restore Keyabyss.csproj --locked-mode -p:Configuration=$managedConfiguration --runtime win-x64 --nologo
            if ($LASTEXITCODE -ne 0) { throw "Managed $managedConfiguration locked restore failed; inspect the dotnet output." }
        } finally { Pop-Location }
        if (Select-String -LiteralPath (Join-Path $projectRoot 'project.godot') -Pattern 'McpInteractionServer|mcp_interaction_server' -Quiet) {
            throw 'A development bridge is present in the source project. Restore the clean source configuration before exporting.'
        }
        $outputDirectory = Join-Path $projectRoot $(if ($Task -eq 'export-release') { 'builds/windows-release' } else { 'builds/windows' })
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        # Converted resources can retain old script properties after a schema
        # change. Rebuild these disposable export outputs; keep import/shader caches.
        $convertedCache = [IO.Path]::GetFullPath((Join-Path $projectRoot '.godot/exported'))
        $retiredExport = [IO.Path]::GetFullPath((Join-Path $projectRoot ('.delete/godot-export-cache/' + [Guid]::NewGuid().ToString('N'))))
        if (-not $convertedCache.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar) -or
            -not $retiredExport.StartsWith((Join-Path $projectRoot '.delete') + [IO.Path]::DirectorySeparatorChar)) {
            throw 'Export cache archive escaped project.'
        }
        if (Test-Path -LiteralPath $convertedCache) {
            New-Item -ItemType Directory -Path (Split-Path $retiredExport) -Force | Out-Null
            Move-Item -LiteralPath $convertedCache -Destination $retiredExport
        }
        $exportFlag = if ($Task -eq 'export-release') { '--export-release' } else { '--export-debug' }
        # Shader Baker requires the real RenderingDevice; headless silently skips it.
        $arguments = @('--path', $projectRoot, '--screen', '0', $exportFlag, 'Windows Desktop', (Join-Path $outputDirectory 'keyabyss.exe'))
    }
}
if ($Task -in @('import', 'export', 'export-release')) {
    # Godot exports invoke dotnet publish with ExportDebug / ExportRelease.
    # Pass locked restore to that child process, retaining the caller's environment.
    $previousLockedMode = $env:RestoreLockedMode
    try {
        $env:RestoreLockedMode = 'true'
        Push-Location -LiteralPath $projectRoot
        try {
            $output = & $godotPath @arguments @EngineArguments 2>&1
            $engineExitCode = $LASTEXITCODE
        } finally { Pop-Location }
    } finally { $env:RestoreLockedMode = $previousLockedMode }
    $output | ForEach-Object { Write-Output $_ }
    if ($engineExitCode -ne 0) { exit $engineExitCode }
    if ($output | Select-String -Pattern 'SCRIPT ERROR:|^ERROR:') { throw 'Godot reported errors; inspect the output.' }
    if ($Task -in @('export', 'export-release')) {
        $publishedAssembly = Join-Path $outputDirectory 'data_Keyabyss_windows_x86_64/Keyabyss.dll'
        if (-not (Test-Path -LiteralPath $publishedAssembly -PathType Leaf)) {
            throw "Managed $managedConfiguration export assembly missing: $publishedAssembly"
        }
        # This checks packed resources with the current editor Debug assembly.
        # Official export templates do not support --script or --main-pack.
        Build-ManagedDebug $projectRoot
        $bossCheck = & $godotPath --headless --path $projectRoot --main-pack (Join-Path $outputDirectory 'keyabyss.pck') --script (Join-Path $projectRoot 'tests/godot/test_boss_resources.gd') 2>&1
        $bossExitCode = $LASTEXITCODE
        $bossCheck | ForEach-Object { Write-Output $_ }
        if ($bossExitCode -ne 0 -or ($bossCheck | Select-String -Pattern 'SCRIPT ERROR:|^ERROR:')) {
            throw 'Exported Boss resource check failed; this package is not ready to publish.'
        }
        $consoleWrapper = Join-Path $outputDirectory 'keyabyss.console.exe'
        if (-not (Test-Path -LiteralPath $consoleWrapper -PathType Leaf)) {
            throw "Export smoke check requires the console wrapper: $consoleWrapper"
        }
        $smokeDirectory = Join-Path $projectRoot ('.temp/export-smoke/' + [Guid]::NewGuid().ToString('N'))
        $smokeAppData = Join-Path $smokeDirectory 'appdata'
        $smokeLog = Join-Path $smokeDirectory 'engine.log'
        New-Item -ItemType Directory -Path $smokeAppData -Force | Out-Null
        $previousAppData = $env:APPDATA
        try {
            $env:APPDATA = $smokeAppData
            Push-Location -LiteralPath $outputDirectory
            try {
                # The console wrapper captures output and waits for the game.
                # A fresh user directory rebuilds all vocabulary indices in a worker.
                $smokeOutput = & $consoleWrapper --quit-after 1800 --max-fps 60 --headless --log-file $smokeLog 2>&1
                $smokeExitCode = $LASTEXITCODE
            } finally { Pop-Location }
        } finally { $env:APPDATA = $previousAppData }
        $smokeOutput | ForEach-Object { Write-Output $_ }
        if ($smokeExitCode -ne 0 -or -not (Test-Path -LiteralPath $smokeLog -PathType Leaf)) {
            throw "Export smoke check failed (exit code $smokeExitCode); inspect $smokeDirectory"
        }
        $smokeLogContents = Get-Content -LiteralPath $smokeLog -Raw -Encoding utf8
        if ($smokeLogContents -notmatch 'Keyabyss ready \|' -or $smokeLogContents -match 'SCRIPT ERROR:|(?m)^ERROR:' -or
            ($smokeOutput | Select-String -Pattern 'SCRIPT ERROR:|^ERROR:')) {
            throw "Export smoke check did not reach a clean startup; inspect $smokeLog"
        }
        Write-Output "Export smoke log: $smokeLog"
        Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE'), (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.md') -Destination $outputDirectory
        $licenseDirectory = Join-Path $outputDirectory 'licenses'
        New-Item -ItemType Directory -Path $licenseDirectory -Force | Out-Null
        foreach ($relative in @('licenses/GODOT_LICENSE.txt', 'licenses/GODOT_COPYRIGHT.txt', 'licenses/DOTNET_RUNTIME_LICENSE.txt', 'licenses/DOTNET_RUNTIME_NOTICES.txt', 'legacy/web/licenses/CMUdict-LICENSE.txt', 'legacy/web/licenses/Qwerty-Learner-GPL-3.0.txt')) {
            Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $licenseDirectory
        }
        Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/vocabulary/sources.json') -Destination (Join-Path $licenseDirectory 'vocabulary-sources.json')
        if ($Task -eq 'export') {
            Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'playtest') | Copy-Item -Destination $outputDirectory
        }
        Write-Output "Export and notices: $outputDirectory"
    }
} else {
    & $godotPath @arguments @EngineArguments
    exit $LASTEXITCODE
}
