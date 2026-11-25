# Best Server — Slender Launcher (fork)

Fork do [Slender Launcher](https://github.com/luan/slender-launcher) integrado com `https://bestserverot.com.br/files-global/`.

## Diferenças do upstream

| Item | Upstream | Best Server |
|------|----------|-------------|
| Nome / exe | Slender.exe | BestServer.exe |
| base_url | GitHub tibia-client | files-global |
| Downloads | `.lzma` compactados | Arquivos descompactados (`prefer_unpacked`) |
| Manifestos | client.windows.json | Gerados a partir de package.json / assets.json |

O cliente instala em `%AppData%\BestServer\` (comportamento padrão do Slender). O executável do jogo é `bin/client.exe`; a pasta `bin/BattlEye/` entra no deploy quando presente no client fonte.

## Build (Windows)

Requisitos: Go 1.22+, Node.js, WebView2 (já presente no Windows 10/11).

```powershell
# Instalar Go (se necessário)
winget install GoLang.Go

# Compilar
.\tools\build-slender-launcher.ps1

# Compilar e copiar para deploy/files-global/
.\tools\build-slender-launcher.ps1 -DeployToFilesGlobal
```

## Publicar cliente + launcher

```powershell
# Só copiar BestServer.exe se já compilado
.\tools\publish-global-client.ps1

# Publicar e compilar launcher na mesma execução
.\tools\publish-global-client.ps1 -BuildSlenderLauncher
```

Gera em `deploy/files-global/`:

- `client.windows.json`, `assets.windows.json` — manifests Slender
- `BestServer.exe`, `BestServer.exe.sha256` — auto-update do launcher
- Restante do cliente global (bin/, assets/, …)

Subir `deploy/files-global/` para `public_html/files-global/` no host.

## Config do jogador

Após a primeira execução: `%AppData%\BestServer\config.toml`

```toml
base_url = "https://bestserverot.com.br/files-global/"
prefer_unpacked = true
parallel = 64
```

## Desenvolvimento

```powershell
cd tools/slender-launcher
wails dev
```
