<?php
/**
 * Copie para updater-1533.config.php na mesma pasta de updater-1533.php.
 * Nao use o updater.config.php do cliente 1524.
 */

// Pasta publicada. Vazio = files-1533 ao lado de api/ (../files-1533).
// So preencha se os arquivos estiverem em outro caminho absoluto.
$files_dir = '';
$files_url = 'https://bestserverot.com.br/files-1533';

// false = nao troca o .exe. true somente ao publicar um build C++ novo.
$update_binaries = false;

$files_and_dirs = array(
    'init.lua',
    'otclientrc.lua',
    'cacert.pem',
    'data',
    'modules',
    'mods'
);

$binaries = array(
    'WIN32-WGL' => 'BestOTC.exe',
    'WIN32-EGL' => 'BestOTC.exe',
    'WIN32-WGL-GCC' => 'BestOTC.exe',
    'WIN32-EGL-GCC' => 'BestOTC.exe',
    'X11-GLX' => 'BestOTC.exe',
    'X11-EGL' => 'BestOTC.exe'
);
