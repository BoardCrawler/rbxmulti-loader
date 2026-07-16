# rbxmulti-loader

PowerShell URI handler for running **multiple Roblox instances** on Windows.

Repository: [github.com/BoardCrawler/rbxmulti-loader](https://github.com/BoardCrawler/rbxmulti-loader)

Registers a custom `rbxmulti://` protocol that proxies launch requests to `roblox-player://` and removes Roblox single-instance locks (`ROBLOX_singletonEvent` and `ROBLOX_singletonMutex`).

No executable required — PowerShell only.

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Roblox installed

## Install

**One-liner** (clone + install):

```powershell
git clone https://github.com/BoardCrawler/rbxmulti-loader.git "$env:LOCALAPPDATA\rbxmulti-src"; & "$env:LOCALAPPDATA\rbxmulti-src\scripts\install.ps1"
```

If you already have the repo:

```powershell
& "C:\path\to\rbxmulti-loader\scripts\install.ps1"
```

This copies files to `%LOCALAPPDATA%\rbxmulti`, registers the `rbxmulti://` URI scheme, and starts a background HTTP server on `http://localhost:17391/` (auto-starts on login).

## Extension ping

Check whether rbxmulti is installed from a browser extension:

```javascript
const res = await fetch('http://localhost:17391/');
const data = await res.json();
// { installed: true, name: "rbxmulti", version: "1.0.0", scheme: "rbxmulti", port: 17391 }
```

The server responds with CORS headers (`Access-Control-Allow-Origin: *`) and runs in the background after install, including after reboot (via `HKCU\...\Run`).

Quick test in PowerShell:

```powershell
Invoke-RestMethod http://localhost:17391/
```

## Usage

Replace `roblox-player:` with `rbxmulti:` in launch links:

```
rbxmulti:1+launchmode:play+gameinfo:TOKEN+launchtime:1234567890+placelauncherurl:...
```

On each launch the handler:

1. Closes singleton locks in all running Roblox processes
2. Starts Roblox via the standard `roblox-player:` protocol
3. Patches singleton locks in the background for the new instance

## Uninstall

```powershell
& "$env:LOCALAPPDATA\rbxmulti-src\scripts\uninstall.ps1"
```

## Logs

```
%LOCALAPPDATA%\rbxmulti\launch.log
%LOCALAPPDATA%\rbxmulti\server.log
```

## How it works

```
Browser
  → rbxmulti:// URI
  → launch.vbs (hidden)
  → launch.ps1
       ├── close singleton handles in existing Roblox processes
       ├── Start-Process roblox-player://...
       └── post-launch.ps1 (background)
            └── close singleton handles in the new process

Extension
  → GET http://localhost:17391/
  → server.ps1 (background, autostart on login)
       └── { "installed": true, ... }
```

## Files

| File | Purpose |
|------|---------|
| `install.ps1` | Register URI scheme, copy files to AppData, start server |
| `uninstall.ps1` | Remove URI scheme, stop server, delete AppData files |
| `launch.vbs` | Hidden launcher (no window) |
| `launch.ps1` | Parse URI, launch Roblox |
| `post-launch.ps1` | Background singleton patcher |
| `server.vbs` | Hidden server launcher |
| `server.ps1` | Local HTTP server on port 17391 |
| `server-utils.ps1` | Start/stop server helpers |
| `SingletonCloser.cs` | Win32 handle closing logic |

## License

MIT — see [LICENSE](LICENSE).

## Disclaimer

This tool bypasses Roblox single-instance restrictions by closing process handles at runtime. Use at your own risk. Not affiliated with Roblox Corporation.
