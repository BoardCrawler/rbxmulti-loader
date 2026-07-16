installDir = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\rbxmulti"
serverScript = installDir & "\server.ps1"

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & serverScript & """"
CreateObject("WScript.Shell").Run cmd, 0, False
