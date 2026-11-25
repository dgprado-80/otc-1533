# Compila o launcher BestServerOt.exe a partir do fork do Slender usado pelo Astra.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$launcherDir = Join-Path $ProjectRoot "tools\bestotc-launcher"
$goExe = (Get-Command go -ErrorAction Stop).Source
$env:PATH = "$(Split-Path $goExe -Parent);$env:USERPROFILE\go\bin;$env:PATH"

$wails = Get-Command wails -ErrorAction SilentlyContinue
if (-not $wails) {
    & $goExe install github.com/wailsapp/wails/v2/cmd/wails@v2.5.1
}

Push-Location $launcherDir
try {
    if (-not (Test-Path "frontend\node_modules")) {
        Push-Location frontend
        npm install
        Pop-Location
    }
    wails build -tags native_webview2loader -nsis
    $built = Join-Path $launcherDir "build\bin\BestServerOt.exe"
    if (-not (Test-Path $built)) {
        throw "Build nao gerou $built"
    }
    $hash = (Get-FileHash -LiteralPath $built -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -Path "$built.sha256" -Value $hash -Encoding ASCII -NoNewline
    Write-Host "Build OK: $built"
    Write-Host "SHA256: $hash"
} finally {
    Pop-Location
}
