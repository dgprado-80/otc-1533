# Monta deploy/files-otc no mesmo esquema do BestServer.exe do Astra.
# O jogador nao usa o updater de dentro do jogo.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$source = Join-Path $ProjectRoot "deploy\files-1533"
$dest = Join-Path $ProjectRoot "deploy\files-otc"
$launcher = Join-Path $ProjectRoot "tools\bestotc-launcher\build\bin\BestServerOt.exe"
$revFile = Join-Path $PSScriptRoot ".otc-launcher-revision"

if (-not (Test-Path (Join-Path $source "BestOTC.exe"))) {
    throw "Pacote base ausente: $source\BestOTC.exe"
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
robocopy $source $dest /MIR /NFL /NDL /NJH /NJS /NC /NS /NP /XD "_backup_original" ".git" | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "Robocopy falhou (codigo $LASTEXITCODE)"
}

foreach ($rel in @(
    "init.lua",
    "modules\client\client.lua",
    "modules\updater\updater.lua"
)) {
    Copy-Item (Join-Path $ProjectRoot $rel) (Join-Path $dest $rel) -Force
}

foreach ($junk in @(
    "devserver.flag",
    "BestserverOt-1533.zip",
    "crystalotc-1533-checksums.json"
)) {
    $path = Join-Path $dest $junk
    if (Test-Path $path) { Remove-Item $path -Force }
}
Get-ChildItem $dest -Recurse -File -Filter "*.log" -ErrorAction SilentlyContinue | Remove-Item -Force

$revision = 0
if (Test-Path $revFile) {
    $revision = [int](Get-Content $revFile -Raw).Trim()
}
$revision++
Set-Content -Path $revFile -Value $revision -Encoding ASCII -NoNewline

python (Join-Path $PSScriptRoot "generate-otc-launcher-manifests.py") $dest $revision "15.30"
if ($LASTEXITCODE -ne 0) { throw "Falha ao gerar os manifests" }

if (Test-Path $launcher) {
    Copy-Item $launcher (Join-Path $dest "BestServerOt.exe") -Force
    $hash = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -Path (Join-Path $dest "BestServerOt.exe.sha256") -Value $hash -Encoding ASCII -NoNewline

    $setup = Join-Path $ProjectRoot "deploy\BestServerOt-Setup"
    New-Item -ItemType Directory -Force -Path $setup | Out-Null
    $installer = Join-Path $ProjectRoot "tools\bestotc-launcher\build\bin\BestServerOt-amd64-installer.exe"
    if (Test-Path $installer) {
        Copy-Item $installer (Join-Path $setup "BestserverOt-Setup.exe") -Force
    }
} else {
    Write-Host "Launcher ainda nao compilado. Rode tools\build-bestotc-launcher.ps1 e publique de novo."
}

$note = @"
PASTA PRONTA PARA UPLOAD
========================

Suba o conteudo de deploy/files-otc/ para:

  public_html/files-otc/
  https://bestserverot.com.br/files-otc/

Sempre envie de novo, depois de mudar o cliente:
  client.windows.json
  assets.windows.json

O jogador executa deploy/BestServerOt-Setup/BestserverOt-Setup.exe.
O instalador cria o atalho BestserverOt na area de trabalho.
"@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $dest "UPLOAD-LEIA-ME.txt"), $note, $utf8)

Write-Host "files-otc pronto. revision=$revision"
