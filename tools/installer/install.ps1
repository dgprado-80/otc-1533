$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $here "BestServerOt.exe"
if (-not (Test-Path $source)) {
    throw "BestServerOt.exe nao encontrado ao lado deste instalador."
}

$destDir = Join-Path $env:LOCALAPPDATA "BestServerOt"
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$destExe = Join-Path $destDir "BestServerOt.exe"
Copy-Item $source $destExe -Force

$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcut = $shell.CreateShortcut((Join-Path $desktop "BestserverOt.lnk"))
$shortcut.TargetPath = $destExe
$shortcut.WorkingDirectory = $destDir
$shortcut.Description = "BestserverOt"
$shortcut.Save()

$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$menuShortcut = $shell.CreateShortcut((Join-Path $startMenu "BestserverOt.lnk"))
$menuShortcut.TargetPath = $destExe
$menuShortcut.WorkingDirectory = $destDir
$menuShortcut.Description = "BestserverOt"
$menuShortcut.Save()

Start-Process $destExe
