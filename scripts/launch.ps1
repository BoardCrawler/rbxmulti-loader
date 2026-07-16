param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Uri
)

$ErrorActionPreference = 'Stop'

$installDir = Join-Path $env:LOCALAPPDATA 'rbxmulti'
$csPath = Join-Path $installDir 'SingletonCloser.cs'
$postScript = Join-Path $installDir 'post-launch.ps1'
$logPath = Join-Path $installDir 'launch.log'

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $logPath -Value $line -Encoding UTF8
}

try {
    if (-not (Test-Path $csPath)) {
        throw "Missing $csPath. Run install.ps1 first."
    }

    if (-not ('SingletonCloser' -as [type])) {
        Add-Type -TypeDefinition (Get-Content -Raw -Path $csPath) -Language CSharp -ErrorAction Stop
    }

    function Convert-RbxMultiUri {
        param([string]$Raw)

        $uri = $Raw.Trim().Trim('"')

        if ($uri.StartsWith('rbxmulti://')) {
            $payload = $uri.Substring('rbxmulti://'.Length)
        }
        elseif ($uri.StartsWith('rbxmulti:')) {
            $payload = $uri.Substring('rbxmulti:'.Length)
        }
        else {
            return $null
        }

        if ([string]::IsNullOrWhiteSpace($payload)) {
            return $null
        }

        return "roblox-player:$payload"
    }

    Write-Log "Received URI (length=$($Uri.Length))"

    $robloxUri = Convert-RbxMultiUri -Raw $Uri
    if (-not $robloxUri) {
        throw "Invalid URI: $Uri"
    }

    Write-Log "Converted to roblox-player URI (length=$($robloxUri.Length))"

    $existing = [SingletonCloser]::FindRobloxPids()
    if ($existing.Count -gt 0) {
        $existingStr = ($existing | ForEach-Object { $_.ToString() }) -join ','
    }
    else {
        $existingStr = '0'
    }

    $closedBefore = [SingletonCloser]::CloseAllRobloxSingletons()
    Write-Log "Closed $closedBefore singleton handle(s) before launch (roblox PIDs: $existingStr)"

    Start-Process -FilePath $robloxUri -WindowStyle Hidden
    Write-Log "Start-Process invoked"

    $postCmd = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$postScript`" $existingStr"
    Start-Process -FilePath 'powershell.exe' -ArgumentList $postCmd -WindowStyle Hidden
    Write-Log "Started post-launch worker (existing PIDs: $existingStr)"

    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
