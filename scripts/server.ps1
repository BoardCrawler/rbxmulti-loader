$ErrorActionPreference = 'SilentlyContinue'

$installDir = Join-Path $env:LOCALAPPDATA 'rbxmulti'
$port = 17391
$pidFile = Join-Path $installDir 'server.pid'
$logFile = Join-Path $installDir 'server.log'

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

if (Test-Path $pidFile) {
    $oldPid = [int](Get-Content -Raw $pidFile)
    if ($oldPid -gt 0) {
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) { exit 0 }
    }
}

$mutexName = 'Local\rbxmulti-http-server'
$created = $false
$mutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$created)
if (-not $created) { exit 0 }

Set-Content -Path $pidFile -Value $PID -Force

$body = '{"installed":true,"name":"rbxmulti","version":"1.0.0","scheme":"rbxmulti","port":17391}'

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:${port}/")
$listener.Prefixes.Add("http://localhost:${port}/")

try {
    $listener.Start()
    Write-Log "Listening on http://localhost:${port}/"
}
catch {
    Write-Log "Failed to start: $($_.Exception.Message)"
    if (Test-Path $pidFile) { Remove-Item $pidFile -Force }
    exit 1
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $response.Headers.Add('Access-Control-Allow-Origin', '*')
        $response.Headers.Add('Access-Control-Allow-Methods', 'GET, OPTIONS')
        $response.Headers.Add('Access-Control-Allow-Headers', 'Content-Type')

        if ($request.HttpMethod -eq 'OPTIONS') {
            $response.StatusCode = 204
            $response.Close()
            continue
        }

        $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
        $response.StatusCode = 200
        $response.ContentType = 'application/json; charset=utf-8'
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    }
}
catch {
    Write-Log "Server error: $($_.Exception.Message)"
}
finally {
    $listener.Stop()
    $listener.Close()
    if (Test-Path $pidFile) { Remove-Item $pidFile -Force }
    Write-Log 'Stopped'
}
