#Requires -Version 5.1

param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'rbxmulti')
)

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if (Test-Path (Join-Path $scriptDir 'server-utils.ps1')) {
    . (Join-Path $scriptDir 'server-utils.ps1')
    Stop-RbxMultiServer -Dir $InstallDir
}
elseif (Test-Path (Join-Path $InstallDir 'server-utils.ps1')) {
    . (Join-Path $InstallDir 'server-utils.ps1')
    Stop-RbxMultiServer -Dir $InstallDir
}

$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
Remove-ItemProperty -Path $runKey -Name 'rbxmulti-server' -ErrorAction SilentlyContinue

$scheme = 'rbxmulti'
$regBase = "HKCU:\Software\Classes\$scheme"

if (Test-Path $regBase) {
    Remove-Item -Path $regBase -Recurse -Force
}

if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
}

Write-Host 'rbxmulti removed' -ForegroundColor Green
