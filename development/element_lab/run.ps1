$ErrorActionPreference = 'Stop'
$labProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$labOriginalAppData = $env:APPDATA
$labOriginalLocalData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $labProjectRoot '.temp/element-lab/appdata'
    $env:LOCALAPPDATA = Join-Path $labProjectRoot '.temp/element-lab/localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
    & (Join-Path $labProjectRoot 'tools/godot/godot.ps1') -Task run -EngineArguments @(
        'res://development/element_lab/element_lab.tscn', '--max-fps', '60',
        '--log-file', (Join-Path $labProjectRoot '.temp/element-lab/interactive.log')
    )
} finally {
    $env:APPDATA = $labOriginalAppData
    $env:LOCALAPPDATA = $labOriginalLocalData
}
