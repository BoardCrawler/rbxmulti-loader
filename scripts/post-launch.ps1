param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ExistingPids
)

$ErrorActionPreference = 'SilentlyContinue'

$installDir = Join-Path $env:LOCALAPPDATA 'rbxmulti'
$csPath = Join-Path $installDir 'SingletonCloser.cs'
$logPath = Join-Path $installDir 'launch.log'

function Write-Log {
    param([string]$Message)
    $line = "[{0}] [post] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $logPath -Value $line -Encoding UTF8
}

try {
    if (-not ('SingletonCloser' -as [type])) {
        Add-Type -TypeDefinition (Get-Content -Raw -Path $csPath) -Language CSharp -ErrorAction Stop
    }

    $existing = New-Object 'System.Collections.Generic.List[uint32]'
    if ($ExistingPids -and $ExistingPids -ne '0') {
        foreach ($part in $ExistingPids.Split(',')) {
            if ($part -match '^\d+$') {
                [void]$existing.Add([uint32]$part)
            }
        }
    }

    $newPid = [SingletonCloser]::WaitForNewRobloxProcess($existing, 45000)
    if ($newPid -ne 0) {
        Write-Log "New Roblox PID: $newPid"
        Start-Sleep -Milliseconds 500
        for ($i = 0; $i -lt 10; $i++) {
            $found = [SingletonCloser]::CountRobloxSingletons($newPid)
            Write-Log "Attempt $($i + 1): found $found singleton handle(s) in PID $newPid"
            $closed = [SingletonCloser]::CloseSingletons($newPid)
            Write-Log "Attempt $($i + 1): closed $closed handle(s) in PID $newPid"
            $allClosed = [SingletonCloser]::CloseAllRobloxSingletons()
            Write-Log "Attempt $($i + 1): closed $allClosed handle(s) in all processes"
            if ($closed -gt 0 -or $allClosed -gt 0) { break }
            Start-Sleep -Milliseconds 1000
        }
    }
    else {
        Write-Log "No new RobloxPlayerBeta.exe detected, patching all running instances"
        for ($i = 0; $i -lt 15; $i++) {
            $closed = [SingletonCloser]::CloseAllRobloxSingletons()
            Write-Log "Fallback attempt $($i + 1): closed $closed handle(s)"
            if ($closed -gt 0) { break }
            Start-Sleep -Milliseconds 500
        }
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
}
