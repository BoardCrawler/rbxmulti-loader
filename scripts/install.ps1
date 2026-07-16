#Requires -Version 5.1

param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'rbxmulti')
)

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

. (Join-Path $scriptDir 'server-utils.ps1')

$scheme = 'rbxmulti'
$displayName = 'Roblox Multi Launcher'

$files = @('launch.ps1', 'post-launch.ps1', 'SingletonCloser.cs', 'launch.vbs', 'server.ps1', 'server.vbs', 'server-utils.ps1')
foreach ($file in $files) {
    $src = Join-Path $scriptDir $file
    if (-not (Test-Path $src)) {
        Write-Error "File not found: $src"
        exit 1
    }
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

foreach ($file in $files) {
    Copy-Item -Path (Join-Path $scriptDir $file) -Destination (Join-Path $InstallDir $file) -Force
}

$vbsPath = Join-Path $InstallDir 'launch.vbs'
$handler = "wscript.exe `"$vbsPath`" `"%1`""

$regBase = "HKCU:\Software\Classes\$scheme"

New-Item -Path $regBase -Force | Out-Null
Set-ItemProperty -Path $regBase -Name '(default)' -Value $displayName
New-ItemProperty -Path $regBase -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null

$iconPath = Join-Path $regBase 'DefaultIcon'
New-Item -Path $iconPath -Force | Out-Null
Set-ItemProperty -Path $iconPath -Name '(default)' -Value 'powershell.exe,0'

$commandPath = Join-Path $regBase 'shell\open\command'
New-Item -Path $commandPath -Force | Out-Null
Set-ItemProperty -Path $commandPath -Name '(default)' -Value $handler

$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$serverVbs = Join-Path $InstallDir 'server.vbs'
Set-ItemProperty -Path $runKey -Name 'rbxmulti-server' -Value "wscript.exe `"$serverVbs`""

Start-RbxMultiServer -Dir $InstallDir
Start-Sleep -Milliseconds 800

Write-Host ''
Write-Host 'rbxmulti installed' -ForegroundColor Green
Write-Host "Dir:    $InstallDir"
Write-Host "Scheme: ${scheme}://"
Write-Host "Ping:   http://localhost:17391/"
Write-Host ''
Write-Host 'Log files:'
Write-Host "  $InstallDir\launch.log"
Write-Host "  $InstallDir\server.log"
Write-Host ''
Write-Host "Uninstall: $(Join-Path $scriptDir 'uninstall.ps1')"
Write-Host ''
