#Requires -Version 5.1

param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'rbxmulti')
)

function Start-RbxMultiServer {
    param([string]$Dir)

    $pidFile = Join-Path $Dir 'server.pid'
    if (Test-Path $pidFile) {
        $oldPid = [int](Get-Content -Raw $pidFile -ErrorAction SilentlyContinue)
        if ($oldPid -gt 0 -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
            return
        }
    }

    $vbs = Join-Path $Dir 'server.vbs'
    if (Test-Path $vbs) {
        Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$vbs`"" -WindowStyle Hidden
    }
}

function Stop-RbxMultiServer {
    param([string]$Dir)

    $pidFile = Join-Path $Dir 'server.pid'
    if (Test-Path $pidFile) {
        $oldPid = [int](Get-Content -Raw $pidFile -ErrorAction SilentlyContinue)
        if ($oldPid -gt 0) {
            Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
        }
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }

    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*\rbxmulti\server.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
