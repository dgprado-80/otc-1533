package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sync"
	"sync/atomic"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
	"github.com/ulikunitz/xz/lzma"
)

type File struct {
	LocalFile    string `json:"localfile"`
	PackedHash   string `json:"packedhash"`
	PackedSize   int    `json:"packedsize"`
	URL          string `json:"url"`
	UnpackedHash string `json:"unpackedhash"`
	UnpackedSize int    `json:"unpackedsize"`
	Unpack       *bool  `json:"unpack"`
}

type AssetsInfo struct {
	Files   []File `json:"files"`
	Version int    `json:"version"`
}

type ClientInfo struct {
	Revision   int    `json:"revision"`
	Version    string `json:"version"`
	Files      []File `json:"files"`
	Executable string `json:"executable"`
	Generation string `json:"generation"`
	Variant    string `json:"variant"`
}

type App struct {
	ctx     context.Context
	logger  *logrus.Logger
	baseURL string
	appName string

	clientInfo ClientInfo
	assetsInfo AssetsInfo

	totalBytes      int64
	totalFiles      int64
	downloadedBytes int64
	downloadedFiles int64

	parallel int

	preferUnpacked bool

	activeDownloads map[string]struct{}
	mutex           sync.Mutex

	queue  chan File
	cancel chan struct{}

	lastUpdateError string
	updateErrorMu   sync.Mutex

	updateRunning bool
	updateMu      sync.Mutex

	httpClient *http.Client
}

func NewApp(logger *logrus.Logger, baseURL string, appName string, parallel int, preferUnpacked bool) *App {
	return &App{
		logger:          logger,
		baseURL:         baseURL,
		queue:           make(chan File, 16),
		cancel:          make(chan struct{}),
		activeDownloads: make(map[string]struct{}),
		parallel:        parallel,
		appName:         appName,
		preferUnpacked:  preferUnpacked,
		httpClient:      &http.Client{Timeout: 20 * time.Minute},
	}
}

func (a *App) expectedHash(file File) string {
	if file.Unpack != nil && !*file.Unpack {
		return file.PackedHash
	}
	if file.UnpackedHash != "" {
		return file.UnpackedHash
	}
	return file.PackedHash
}

func (a *App) fileDownloadURL(file File) string {
	if file.Unpack != nil && !*file.Unpack {
		return a.baseURL + file.URL
	}
	if a.preferUnpacked {
		return a.baseURL + file.LocalFile
	}
	return a.baseURL + file.URL
}

func (a *App) fileDownloadSize(file File) int {
	if file.Unpack != nil && !*file.Unpack {
		return file.PackedSize
	}
	if a.preferUnpacked {
		return file.UnpackedSize
	}
	return file.PackedSize
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

func (a *App) OpenClientLocation() {
	fmt.Println("Opening client location")
	if runtime.GOOS == "darwin" {
		exec.Command("open", a.appDirectory()).Start()
	} else if runtime.GOOS == "windows" {
		exec.Command("explorer", a.appDirectory()).Start()
	} else if runtime.GOOS == "linux" {
		exec.Command("xdg-open", a.appDirectory()).Start()
	}
}

func (a *App) Exit() {
	os.Exit(0)
}

func (a *App) remoteClientJSON() string {
	return "client." + a.OS() + ".json"
}

func (a *App) remoteAssetsJSON() string {
	return "assets." + a.OS() + ".json"
}

func (a *App) refreshManifests() {
	if err := a.loadClientManifest(); err != nil {
		a.logger.Errorf("Error loading client manifest: %v", err)
		a.clientInfo = ClientInfo{}
	}
	if err := a.loadAssetsManifest(); err != nil {
		a.logger.Errorf("Error loading assets manifest: %v", err)
		a.assetsInfo = AssetsInfo{}
	}
}

func (a *App) loadClientManifest() error {
	localName := "slender-client.json"
	if err := a.downloadFile(a.baseURL+a.remoteClientJSON(), localName, false); err != nil {
		return err
	}
	path := filepath.Join(a.appDirectory(), localName)
	info, err := os.Stat(path)
	if err != nil || info.Size() == 0 {
		return fmt.Errorf("%s is empty or missing", localName)
	}
	var client ClientInfo
	if err := readJSON(path, &client); err != nil {
		return err
	}
	if client.Executable == "" || len(client.Files) == 0 {
		return fmt.Errorf("%s has no executable or file list", localName)
	}
	a.clientInfo = client
	return nil
}

func (a *App) loadAssetsManifest() error {
	localName := "slender-assets.json"
	if err := a.downloadFile(a.baseURL+a.remoteAssetsJSON(), localName, false); err != nil {
		return err
	}
	path := filepath.Join(a.appDirectory(), localName)
	info, err := os.Stat(path)
	if err != nil || info.Size() == 0 {
		return fmt.Errorf("%s is empty or missing", localName)
	}
	var assets AssetsInfo
	if err := readJSON(path, &assets); err != nil {
		return err
	}
	if len(assets.Files) == 0 {
		return fmt.Errorf("%s has no file list", localName)
	}
	a.assetsInfo = assets
	return nil
}

func (a *App) clientBinaryExists() bool {
	if a.clientInfo.Executable == "" {
		return false
	}
	info, err := os.Stat(filepath.Join(a.appDirectory(), a.clientInfo.Executable))
	return err == nil && info.Size() > 0
}

func (a *App) Version() string {
	a.refreshManifests()
	return a.clientInfo.Version
}

func (a *App) Revision() int {
	a.refreshManifests()
	return a.clientInfo.Revision
}

func (a *App) DownloadPercent() float64 {
	if a.totalBytes == 0 {
		return 0
	}
	percent := float64(a.downloadedBytes) / float64(a.totalBytes) * 100
	a.logger.Infof("Downloaded %d/%d files |  %d/%d bytes (%.2f%%)", a.downloadedFiles, a.totalFiles, a.downloadedBytes, a.totalBytes, percent)
	return percent
}

func (a *App) TotalFiles() int64 {
	return a.totalFiles
}

func (a *App) TotalBytes() int64 {
	return a.totalBytes
}

func (a *App) DownloadedFiles() int64 {
	return a.downloadedFiles
}

func (a *App) DownloadedBytes() int64 {
	return a.downloadedBytes
}

func (a *App) ToggleLocal(value bool) {
	a.logger.Infof("Setting enableLocal to %v", value)
	viper.Set("enableLocal", value)
	a.saveConfig()
}

func (a *App) saveConfig() {
	if err := viper.WriteConfigAs(filepath.Join(configDirectory(a.appName), "config.toml")); err != nil {
		a.logger.Errorf("Error writing config: %v", err)
	}
}

func (a *App) LocalEnabled() bool {
	return viper.GetBool("enableLocal")
}

func (a *App) OS() string {
	os := runtime.GOOS
	if os == "darwin" {
		return "mac"
	}
	return os
}

func (a *App) ActiveDownload() string {
	a.mutex.Lock()
	defer a.mutex.Unlock()
	for url := range a.activeDownloads {
		return url
	}
	return ""
}

func (a *App) setUpdateError(msg string) {
	a.updateErrorMu.Lock()
	a.lastUpdateError = msg
	a.updateErrorMu.Unlock()
}

func (a *App) UpdateError() string {
	a.updateErrorMu.Lock()
	defer a.updateErrorMu.Unlock()
	return a.lastUpdateError
}

func (a *App) UpdateRunning() bool {
	a.updateMu.Lock()
	defer a.updateMu.Unlock()
	return a.updateRunning
}

func (a *App) Update() {
	a.updateMu.Lock()
	if a.updateRunning {
		a.updateMu.Unlock()
		return
	}
	a.updateRunning = true
	a.updateMu.Unlock()

	go a.runUpdate()
}

func (a *App) runUpdate() {
	defer func() {
		a.updateMu.Lock()
		a.updateRunning = false
		a.updateMu.Unlock()
	}()

	a.setUpdateError("")
	a.refreshManifests()

	if len(a.clientInfo.Files) == 0 || len(a.assetsInfo.Files) == 0 {
		msg := fmt.Sprintf("Lista de arquivos indisponivel em %s — publique client.windows.json e assets.windows.json no servidor.", a.baseURL)
		a.setUpdateError(msg)
		a.logger.Error(msg)
		return
	}

	files, err := a.filesToUpdate()
	if err != nil {
		a.logger.Errorf("Error checking for updates: %v", err)
		a.setUpdateError("Erro ao verificar arquivos para download.")
		return
	}

	a.totalFiles = int64(len(files))
	a.totalBytes = 0
	a.downloadedFiles = 0
	a.downloadedBytes = 0
	for _, file := range files {
		a.totalBytes += int64(a.fileDownloadSize(file))
	}

	if len(files) == 0 {
		a.logger.Info("Nothing to update")
		return
	}

	sem := make(chan struct{}, a.parallel)
	var wg sync.WaitGroup
	var failedMu sync.Mutex
	var failedCount int
	var firstFailure string

	for _, file := range files {
		wg.Add(1)
		go func(file File) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			downloadURL := a.fileDownloadURL(file)
			var lastErr error
			for attempt := 1; attempt <= 3; attempt++ {
				a.mutex.Lock()
				a.activeDownloads[downloadURL] = struct{}{}
				a.mutex.Unlock()

				lastErr = a.downloadFile(downloadURL, file.LocalFile, true)

				a.mutex.Lock()
				delete(a.activeDownloads, downloadURL)
				a.mutex.Unlock()

				if lastErr == nil {
					return
				}
				a.logger.Warnf("Retry %d/3 for %s: %v", attempt, downloadURL, lastErr)
				time.Sleep(time.Duration(attempt) * time.Second)
			}

			failedMu.Lock()
			failedCount++
			if firstFailure == "" {
				firstFailure = file.LocalFile + ": " + lastErr.Error()
			}
			failedMu.Unlock()
			a.logger.Errorf("Failed to download %s: %v", downloadURL, lastErr)
		}(file)
	}

	wg.Wait()

	if failedCount > 0 {
		a.setUpdateError(fmt.Sprintf("Falha em %d arquivo(s). Exemplo: %s", failedCount, firstFailure))
	}
}

func (a *App) NeedsUpdate() bool {
	a.refreshManifests()
	if len(a.clientInfo.Files) == 0 || len(a.assetsInfo.Files) == 0 {
		return true
	}
	if !a.clientBinaryExists() {
		return true
	}
	files, err := a.filesToUpdate()
	if err != nil {
		a.logger.Errorf("Error checking for updates: %v", err)
		return true
	}
	return len(files) > 0
}

func (a *App) appDirectory() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		a.logger.Errorf("Error getting config directory: %v", err)
		return ""
	}
	appName := a.appName
	if a.OS() == "mac" {
		appName = a.appName + ".app"
	}
	return filepath.Join(configDir, appName)
}

func (a *App) filesToUpdate() ([]File, error) {
	var files []File
	filesTocheck := append(a.assetsInfo.Files, a.clientInfo.Files...)

	mutex := sync.Mutex{}
	wg := sync.WaitGroup{}
	wg.Add(len(filesTocheck))

	for _, file := range filesTocheck {
		go func(file File) {
			defer wg.Done()

			localFilePath := filepath.Join(a.appDirectory(), file.LocalFile)
			if !fileExists(localFilePath) {
				a.logger.Infof("File %s does not exist", localFilePath)
				mutex.Lock()
				files = append(files, file)
				mutex.Unlock()
			} else {
				localHash, err := sha256Sum(localFilePath)
				if err != nil {
					a.logger.Errorf("Error reading local file: %s\n", err)
					return
				}

				if localHash != a.expectedHash(file) {
					a.logger.Infof("File %s has changed (local: %s, remote: %s)", localFilePath, localHash, a.expectedHash(file))
					mutex.Lock()
					files = append(files, file)
					mutex.Unlock()
				}
			}
		}(file)
	}

	wg.Wait()

	return files, nil
}

func fileExists(path string) bool {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return false
	}
	return true
}

func readJSON(s string, d interface{}) error {
	contents, err := os.ReadFile(s)
	if err != nil {
		return err
	}
	contents = bytes.TrimPrefix(contents, []byte{0xEF, 0xBB, 0xBF})
	err = json.Unmarshal(contents, &d)
	if err != nil {
		return err
	}
	return nil
}

func (a *App) downloadFile(url, dst string, progress bool) error {
	a.logger.Infof("Downloading %s to %s", url, dst)
	dst = filepath.Join(a.appDirectory(), dst)
	part := dst + ".part"
	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}

	out, err := os.Create(part)
	if err != nil {
		return err
	}

	resp, err := a.httpClient.Get(url)
	if err != nil {
		out.Close()
		os.Remove(part)
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		out.Close()
		os.Remove(part)
		return fmt.Errorf("download failed: %s (%d)", url, resp.StatusCode)
	}

	var reader io.Reader = resp.Body
	if progress {
		reader = io.TeeReader(reader, a)
	}

	if filepath.Ext(dst) != ".lzma" && filepath.Ext(url) == ".lzma" {
		lzmaReader, err := lzma.NewReader(reader)
		if err != nil {
			out.Close()
			os.Remove(part)
			return err
		}
		reader = lzmaReader
	}

	_, err = io.Copy(out, reader)
	out.Close()
	if err != nil {
		os.Remove(part)
		return err
	}

	if err := os.Remove(dst); err != nil && !os.IsNotExist(err) {
		os.Remove(part)
		return err
	}
	if err := os.Rename(part, dst); err != nil {
		os.Remove(part)
		return err
	}

	atomic.AddInt64(&a.downloadedFiles, 1)
	return nil
}

func (a *App) localExecutable() string {
	name := "Contents/MacOS/client-local"
	if a.OS() == "windows" {
		name = "bin/client-local.exe"
	}
	if a.OS() == "linux" {
		name = "bin/client-local"
	}
	return filepath.Join(a.appDirectory(), name)
}

func (a *App) executable() string {
	return filepath.Join(a.appDirectory(), a.clientInfo.Executable)
}

func (a *App) Play(local bool) {
	a.refreshManifests()

	executable := a.executable()
	if local {
		executable = a.localExecutable()
	}

	info, err := os.Stat(executable)
	if err != nil || info.Size() == 0 {
		a.logger.Errorf("Client not installed. Run Update first: %s", executable)
		return
	}

	a.logger.Infof("Launching %s", executable)
	cmd := exec.Command(executable)
	cmd.Dir = a.appDirectory()
	if err := cmd.Start(); err != nil {
		a.logger.Errorf("Failed to launch %s: %v", executable, err)
		return
	}

	time.Sleep(300 * time.Millisecond)
	os.Exit(0)
}

func (a *App) Write(p []byte) (n int, err error) {
	n = len(p)
	atomic.AddInt64(&a.downloadedBytes, int64(n))
	return
}

func sha256Sum(filename string) (string, error) {
	f, err := os.Open(filename)
	if err != nil {
		return "", err
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}

	return hex.EncodeToString(h.Sum(nil)), nil
}
