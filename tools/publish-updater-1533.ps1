# Monta deploy/files-1533 e deploy/api para o updater Windows do protocolo 1533.
# Nao mexe em /files/ nem em /api/updater.php do cliente 1524.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$deployRoot = Join-Path $ProjectRoot "deploy"
$deployFiles = Join-Path $deployRoot "files-1533"
$deployApi = Join-Path $deployRoot "api"

$exeSource = Join-Path $ProjectRoot "BestOTC.exe"
if (-not (Test-Path $exeSource)) {
    throw "BestOTC.exe ausente. Compile com: msbuild vc18\otclient.vcxproj /p:Configuration=DirectX /p:Platform=x64"
}

if (Test-Path $deployFiles) {
    Remove-Item $deployFiles -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $deployFiles | Out-Null
New-Item -ItemType Directory -Force -Path $deployApi | Out-Null

$rootFiles = @("init.lua", "otclientrc.lua", "cacert.pem")
foreach ($file in $rootFiles) {
    $source = Join-Path $ProjectRoot $file
    if (-not (Test-Path $source)) {
        throw "Arquivo obrigatorio ausente: $file"
    }
    Copy-Item $source (Join-Path $deployFiles $file) -Force
}

Copy-Item $exeSource (Join-Path $deployFiles "BestOTC.exe") -Force

function Copy-Tree {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path $Source)) {
        throw "Origem ausente: $Source"
    }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    robocopy $Source $Destination /MIR /NFL /NDL /NJH /NJS /NC /NS /NP `
        /XD ".git" ".github" "__pycache__" "_backup_original" `
        /XF "*.log" "*.pdb" "*.exp" "*.lib" "*.md" "devserver.flag" | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "Robocopy falhou ao copiar $Source (codigo $LASTEXITCODE)"
    }
}

Copy-Tree (Join-Path $ProjectRoot "data") (Join-Path $deployFiles "data")
Copy-Tree (Join-Path $ProjectRoot "modules") (Join-Path $deployFiles "modules")
Copy-Tree (Join-Path $ProjectRoot "mods") (Join-Path $deployFiles "mods")

Copy-Item (Join-Path $PSScriptRoot "api\updater-1533.php") (Join-Path $deployApi "updater-1533.php") -Force
Copy-Item (Join-Path $PSScriptRoot "api\updater-1533.config.example.php") (Join-Path $deployApi "updater-1533.config.php") -Force
$checksums = Join-Path $PSScriptRoot "api\crystalotc-1533-checksums.json"
if (Test-Path $checksums) {
    Copy-Item $checksums (Join-Path $deployApi "crystalotc-1533-checksums.json") -Force
}

$errors = @()
function Add-Error([string]$Msg) { $script:errors += $Msg }

if (Test-Path (Join-Path $deployFiles "devserver.flag")) {
    Add-Error "devserver.flag entrou no pacote"
}
if (Test-Path (Join-Path $deployFiles "data\images\_backup_original")) {
    Add-Error "_backup_original entrou no pacote"
}

$init = Get-Content (Join-Path $deployFiles "init.lua") -Raw
if ($init -notmatch "updater-1533\.php") { Add-Error "init.lua sem a URL do updater 1533" }
if ($init -notmatch "login-new\.php") { Add-Error "init.lua sem o login de producao" }
if ($init -notmatch "devserver\.flag") { Add-Error "init.lua perdeu a protecao do devserver.flag" }

$png = Join-Path $deployFiles "data\images\background.png"
$sig = [System.IO.File]::ReadAllBytes($png)[0..3]
if (($sig[0] -ne 0x89) -or ($sig[1] -ne 0x50) -or ($sig[2] -ne 0x4E) -or ($sig[3] -ne 0x47)) {
    Add-Error "data/images/background.png nao e um PNG"
}

$php = Get-Content (Join-Path $deployApi "updater-1533.php") -Raw
if ($php -notmatch "update_binaries = false") { Add-Error "updater-1533.php com troca de exe ligada" }
if ($php -match "files_url = 'https://bestserverot.com.br/files'") { Add-Error "updater-1533.php aponta para /files/ do 1524" }
if ($php -notmatch "files-1533") { Add-Error "updater-1533.php sem /files-1533" }

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "ERRO: $_" }
    throw "Pacote 1533 invalido"
}

$files = Get-ChildItem $deployFiles -Recurse -File
$sum = ($files | Measure-Object Length -Sum).Sum
Write-Host ""
Write-Host "Pacote 1533 pronto em: $deployRoot"
Write-Host "  deploy/files-1533/          -> https://bestserverot.com.br/files-1533/"
Write-Host "  deploy/api/updater-1533.php -> https://bestserverot.com.br/api/updater-1533.php"
Write-Host "  deploy/api/updater-1533.config.php -> mesma pasta api/ no servidor"
Write-Host "Arquivos: $($files.Count) | Tamanho: $([math]::Round($sum / 1MB, 1)) MB"
Write-Host "Nao substitua /files/ nem /api/updater.php do cliente 1524."
