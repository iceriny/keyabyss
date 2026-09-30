[CmdletBinding()]
param(
    [ValidateSet('doctor', 'import', 'run', 'editor', 'preview', 'export')]
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

switch ($Task) {
    'doctor' {
        $hash = (Get-FileHash -LiteralPath $godotPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $lock.engineConsoleSha256) { throw 'Engine executable SHA256 differs from toolchain.json.' }
        Write-Output "Godot: $version"
        Write-Output "Executable: $godotPath"
        Write-Output "Project: $projectRoot"
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
        $output = & $godotPath --headless --path $preview --editor --import 2>&1
        $engineExitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Output $_ }
        if ($engineExitCode -ne 0 -or ($output | Select-String -Pattern 'SCRIPT ERROR:|^ERROR:')) { throw 'Preview import failed; inspect the Godot output.' }
        Write-Output "MCP projectPath: $preview"
        return
    }
    'import' { $arguments = @('--headless', '--path', $projectRoot, '--editor', '--import') }
    'run' { $arguments = @('--path', $projectRoot) }
    'editor' { $arguments = @('--path', $projectRoot, '--editor') }
    'export' {
        if (Select-String -LiteralPath (Join-Path $projectRoot 'project.godot') -Pattern 'McpInteractionServer|mcp_interaction_server' -Quiet) {
            throw 'A development bridge is present in the source project. Restore the clean source configuration before exporting.'
        }
        New-Item -ItemType Directory -Path (Join-Path $projectRoot 'builds/windows') -Force | Out-Null
        $arguments = @('--headless', '--path', $projectRoot, '--export-debug', 'Windows Desktop', (Join-Path $projectRoot 'builds/windows/keyabyss.exe'))
    }
}
if ($Task -in @('import', 'export')) {
    $output = & $godotPath @arguments @EngineArguments 2>&1
    $engineExitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Output $_ }
    if ($engineExitCode -ne 0) { exit $engineExitCode }
    if ($output | Select-String -Pattern 'SCRIPT ERROR:|^ERROR:') { throw 'Godot reported errors; inspect the output.' }
} else {
    & $godotPath @arguments @EngineArguments
    exit $LASTEXITCODE
}
