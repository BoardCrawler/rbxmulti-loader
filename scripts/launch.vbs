Set args = WScript.Arguments
If args.Count = 0 Then WScript.Quit 1

uri = args(0)
installDir = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\rbxmulti"
launchScript = installDir & "\launch.ps1"

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & launchScript & """ """ & uri & """"
CreateObject("WScript.Shell").Run cmd, 0, False
