<?php
/**
 * Updater do BestOTC 1533 (somente Windows).
 *
 * Nao reutiliza /api/updater.php nem /files/ do cliente 1524.
 * Se os dois scripts ficarem na mesma pasta, este le updater-1533.config.php,
 * nao o updater.config.php do Astra.
 *
 * No servidor:
 *   /api/updater-1533.php
 *   /api/updater-1533.config.php   (copie o example)
 *   /files-1533/                   conteudo publicado do cliente Windows
 */

$configFile = __DIR__ . '/updater-1533.config.php';
if (is_file($configFile)) {
    require $configFile;
}

header('Content-Type: application/json; charset=utf-8');
@set_time_limit(300);

$rawInput = file_get_contents('php://input');
$data = json_decode($rawInput);
if (!$data) {
    $data = new stdClass();
}

$platform = isset($data->platform) ? $data->platform : '';

// The config path is only a hint. The live site serves /files-1533 next to /api,
// which is not /var/www/bestserverot/public on this host.
$siblingFiles = realpath(__DIR__ . '/../files-1533');
if (!isset($files_dir) || !is_dir($files_dir)) {
    if ($siblingFiles && is_dir($siblingFiles)) {
        $files_dir = $siblingFiles;
    }
}
if (!isset($files_url)) {
    $files_url = 'https://bestserverot.com.br/files-1533';
}
if (!isset($files_and_dirs)) {
    $files_and_dirs = array('init.lua', 'otclientrc.lua', 'cacert.pem', 'data', 'modules', 'mods');
}
if (!isset($checksum_file)) {
    $checksum_file = 'crystalotc-1533-checksums.json';
}
if (!isset($checksum_update_interval)) {
    $checksum_update_interval = 60;
}
// Trocar o .exe so quando um build C++ novo for publicado.
// false evita o loop otclient_dx_x64-TIMESTAMP-TIMESTAMP...
if (!isset($update_binaries)) {
    $update_binaries = false;
}
if (!isset($binary_extensions)) {
    $binary_extensions = array('exe', 'dll');
}
if (!isset($binaries)) {
    // DirectX|x64 defines OPENGL_ES, so the Windows client reports WIN32-EGL.
    // One exe contains every renderer. update_binaries stays false.
    $binaries = array(
        'WIN32-WGL' => 'BestOTC.exe',
        'WIN32-EGL' => 'BestOTC.exe',
        'WIN32-WGL-GCC' => 'BestOTC.exe',
        'WIN32-EGL-GCC' => 'BestOTC.exe',
        'X11-GLX' => 'BestOTC.exe',
        'X11-EGL' => 'BestOTC.exe',
    );
}

function sendError($error) {
    $body = json_encode(array('error' => $error));
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    header('Content-Length: ' . strlen($body));
    echo $body;
    die();
}

$binary = isset($binaries[$platform]) ? $binaries[$platform] : '';

$cache = null;
$manifest = __DIR__ . DIRECTORY_SEPARATOR . $checksum_file;
if (is_file($manifest)) {
    $cache = json_decode(file_get_contents($manifest), true);
}

$cache_file = sys_get_temp_dir() . DIRECTORY_SEPARATOR . $checksum_file;
if (!$cache && file_exists($cache_file) && (filemtime($cache_file) + $checksum_update_interval > time())) {
    $cache = json_decode(file_get_contents($cache_file), true);
}

if (!$cache && (!$files_dir || !is_dir($files_dir))) {
    sendError('Files directory not found: ' . $files_dir);
}

if (!$cache) {
    $dir = realpath($files_dir);
    $rii = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS));
    $cache = array();

    foreach ($rii as $file) {
        if (!$file->isFile()) {
            continue;
        }

        $path = str_replace($dir, '', $file->getPathname());
        $path = str_replace(DIRECTORY_SEPARATOR, '/', $path);
        if ($path === '' || $path[0] !== '/') {
            $path = '/' . ltrim($path, '/');
        }

        $checksum = hash_file('crc32b', $file->getPathname());
        if ($checksum === false || $checksum === '') {
            continue;
        }

        $parsed_checksum = ltrim($checksum, '0');
        if ($parsed_checksum === '') {
            $parsed_checksum = '0';
        }

        $cache[$path] = $parsed_checksum;
    }

    file_put_contents($cache_file . '.tmp', json_encode($cache));
    rename($cache_file . '.tmp', $cache_file);
}

$ret = array(
    'url' => rtrim($files_url, '/') . '/',
    'files' => array(),
    'keepFiles' => false
);

foreach ($cache as $file => $checksum) {
    $trimmed = ltrim($file, '/');
    $parts = explode('/', $trimmed);
    $base = $parts[0];
    $extension = strtolower(pathinfo($trimmed, PATHINFO_EXTENSION));

    if (in_array($extension, $binary_extensions, true)) {
        if ($update_binaries && !empty($binary) && $base === $binary) {
            $ret['binary'] = array('file' => $file, 'checksum' => $checksum);
        }
        continue;
    }

    if (in_array($base, $files_and_dirs, true)) {
        $ret['files'][$file] = $checksum;
    }
}

$body = json_encode($ret, JSON_PRETTY_PRINT);
header('Content-length: ' . strlen($body));
echo $body;
