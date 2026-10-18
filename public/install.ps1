[CmdletBinding()]
param(
    [string]$ManifestUrl = 'https://pofis.app/releases/windows/latest.json',
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\Pofis'),
    [string]$ShortcutPath = (Join-Path ([Environment]::GetFolderPath('Programs')) 'Pofis.lnk'),
    [string]$UserDataDir = (Join-Path $env:APPDATA 'Pofis'),
    [string]$RegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Pofis'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-DownloadUri([string]$Value, [Uri]$Base) {
    $uri = if ($Base) { [Uri]::new($Base, $Value) } else { [Uri]$Value }
    if (-not $uri.IsAbsoluteUri -or $uri.UserInfo -or
        ($uri.Scheme -ne 'https' -and -not ($uri.Scheme -eq 'http' -and $uri.IsLoopback))) {
        throw 'İndirme adresi HTTPS olmalı. Yerel testte yalnız loopback HTTP kullanılabilir.'
    }
    return $uri
}

function Save-Download([Uri]$Uri, [string]$Target) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri.AbsoluteUri -OutFile $Target -PassThru -TimeoutSec 180
        if ($response.BaseResponse.PSObject.Properties['ResponseUri']) {
            $null = Get-DownloadUri $response.BaseResponse.ResponseUri.AbsoluteUri $null
        } elseif ($response.BaseResponse.PSObject.Properties['RequestMessage']) {
            $null = Get-DownloadUri $response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri $null
        }
    } catch { throw "İndirme tamamlanamadı: $($Uri.AbsolutePath)" }
}

function Write-AtomicJson([string]$Path, $Value) {
    $temporary = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        for ($attempt = 0; $attempt -lt 5; $attempt++) {
            try {
                if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
                else { [IO.File]::Move($temporary, $Path) }
                return
            } catch {
                $cause = $_.Exception
                while ($cause.InnerException) { $cause = $cause.InnerException }
                $code = $cause.HResult -band 0xFFFF
                # Sharing/lock violations and ERROR_UNABLE_TO_REMOVE_REPLACED can be transient.
                if ($code -notin @(32, 33, 1175) -or $attempt -eq 4) {
                    throw "Kurulum kaydı yenilenemedi ($([IO.Path]::GetFileName($Path)), Windows $code): $($cause.Message)"
                }
                Start-Sleep -Milliseconds 150
            }
        }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Assert-RequiredFiles([string]$Directory, [string]$Version) {
    foreach ($relative in @('Pofis.exe', 'resources\app\package.json',
        'resources\app\electron\main.cjs', 'resources\app\electron\server-entry.cjs',
        'resources\app\electron\server.cjs', 'resources\app\electron\startup.cjs', 'resources\app\electron\platform.cjs',
        'resources\app\electron\uninstall.ps1',
        'resources\app\server\.next\BUILD_ID', 'resources\app\server\server.js',
        'resources\app\server\node_modules\next\package.json', 'release.json')) {
        if (-not [IO.File]::Exists((Join-Path $Directory $relative))) { throw "Paket eksik: $relative" }
    }
    $release = Get-Content -LiteralPath (Join-Path $Directory 'release.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $app = Get-Content -LiteralPath (Join-Path $Directory 'resources\app\package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($release.version -ne $Version -or $app.version -ne $Version -or
        $release.platform -ne 'win32' -or $release.arch -ne 'x64') { throw 'Paket sürümü veya mimarisi manifestle eşleşmiyor.' }
    foreach ($relative in @('Pofis.exe')) {
        $stream = [IO.File]::OpenRead((Join-Path $Directory $relative))
        $reader = [IO.BinaryReader]::new($stream)
        try {
            if ($reader.ReadUInt16() -ne 0x5A4D) { throw 'Paket geçerli bir Windows uygulaması içermiyor.' }
            $stream.Position = 0x3C
            $offset = $reader.ReadInt32()
            $stream.Position = $offset
            if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664) { throw 'Paket Windows x64 ile uyumlu değil.' }
        } finally { $reader.Dispose() }
    }
}

function Expand-VerifiedArchive([string]$Archive, [string]$Directory) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    $prefix = [IO.Path]::GetFullPath($Directory).TrimEnd('\') + '\'
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName.Contains(':') -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {
                throw 'Pakette desteklenmeyen dosya yolu var.'
            }
            $target = [IO.Path]::GetFullPath([IO.Path]::Combine($Directory, $entry.FullName))
            if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Paket kurulum dizininin dışına yazmaya çalışıyor.' }
            # Normalize and check containment before applying the Windows long-path prefix.
            $target = '\\?\' + $target
            if (-not $entry.Name) { [IO.Directory]::CreateDirectory($target) | Out-Null; continue }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
            $inputStream = $entry.Open()
            $outputStream = [IO.File]::Open($target, [IO.FileMode]::CreateNew)
            try { $inputStream.CopyTo($outputStream) } finally { $inputStream.Dispose(); $outputStream.Dispose() }
        }
    } finally { $zip.Dispose() }
}

function Get-InstalledProcess {
    $prefix = (Join-Path $InstallRoot 'versions').TrimEnd('\') + '\'
    @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -and $_.Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } catch { $false }
    })
}

function Set-PofisShortcut([string]$Executable) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($ShortcutPath)) | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $temporary = [IO.Path]::Combine([IO.Path]::GetDirectoryName($ShortcutPath), ([Guid]::NewGuid().ToString('N') + '.lnk'))
    try {
        $shortcut = $shell.CreateShortcut($temporary)
        $shortcut.TargetPath = $Executable
        $shortcut.WorkingDirectory = [IO.Path]::GetDirectoryName($Executable)
        $shortcut.Arguments = '--user-data-dir="' + $UserDataDir + '"'
        $shortcut.IconLocation = "$Executable,0"
        $shortcut.Description = 'Pofis'
        $shortcut.Save()
        Move-Item -LiteralPath $temporary -Destination $ShortcutPath -Force
    } finally { [Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null }
}

function Start-VerifiedPofis([string]$Executable, [string]$Version) {
    Write-Host 'Pofis açılıyor…'
    $id = [Guid]::NewGuid().ToString('N')
    $resultPath = Join-Path $UserDataDir "launch-results\$id.json"
    $process = Start-Process -FilePath $Executable -WorkingDirectory ([IO.Path]::GetDirectoryName($Executable)) -WindowStyle Normal `
        -ArgumentList @("--startup-id=$id", ('--user-data-dir="' + $UserDataDir + '"')) -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    $verified = $false
    try {
        while ([DateTime]::UtcNow -lt $deadline) {
            if (Test-Path -LiteralPath $resultPath) {
                $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($result.requestId -ne $id -or $result.schemaVersion -ne 1) { throw 'Açılış sonucu doğrulanamadı.' }
                if ($result.status -ne 'ready') { throw $result.message }
                $running = Get-Process -Id $result.pid -ErrorAction SilentlyContinue
                if (-not $running -or $result.version -ne $Version -or -not $result.windowReady -or
                    -not $running.Path.Equals($Executable, [StringComparison]::OrdinalIgnoreCase)) {
                    throw 'Çalışan Pofis sürümü doğrulanamadı. Açık Pofis pencerelerini kapatıp yeniden dene.'
                }
                Write-Host 'Pofis hazır'
                $verified = $true
                return
            }
            Start-Sleep -Milliseconds 150
            $process.Refresh()
            # A secondary instance may exit before the primary writes its result.
        }
        throw 'Pofis penceresi 45 saniye içinde hazır olmadı. Açık Pofis pencerelerini kapatıp yeniden dene.'
    } finally {
        # Allow a failed Electron process to release its single-instance lock before retry.
        if (-not $verified) { $null = $process.WaitForExit(10000) }
        if (Test-Path -LiteralPath $resultPath) { Remove-Item -LiteralPath $resultPath -Force }
    }
}

function Register-Pofis([string]$Directory, [string]$Version) {
    $uninstaller = Join-Path $InstallRoot 'uninstall.ps1'
    # Windows PowerShell 5.1 reads local scripts using the system code page without a BOM.
    [IO.File]::WriteAllText($uninstaller, [IO.File]::ReadAllText((Join-Path $Directory 'resources\app\electron\uninstall.ps1')), [Text.UTF8Encoding]::new($true))
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $command = '"' + $powershell + '" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $uninstaller + '"'
    New-Item -Path $RegistryPath -Force | Out-Null
    foreach ($entry in @{
        DisplayName = 'Pofis'; DisplayVersion = $Version; Publisher = 'Mert Ercan';
        URLInfoAbout = 'https://pofis.app';
        InstallLocation = $InstallRoot; DisplayIcon = (Join-Path $Directory 'Pofis.exe'); UninstallString = $command
    }.GetEnumerator()) {
        New-ItemProperty -LiteralPath $RegistryPath -Name $entry.Key -Value $entry.Value -PropertyType String -Force | Out-Null
    }
    foreach ($name in @('NoModify', 'NoRepair')) {
        New-ItemProperty -LiteralPath $RegistryPath -Name $name -Value 1 -PropertyType DWord -Force | Out-Null
    }
}

$lock = $null
$stage = $null
$archive = $null
$manifestFile = $null
$previous = $null
$exitCode = 0
try {
    Write-Host 'Pofis kurulumu başlatılıyor…'
    Write-Host 'Sistem kontrol ediliyor…'
    if ([Environment]::OSVersion.Platform -ne 'Win32NT' -or [Environment]::OSVersion.Version.Major -lt 10) { throw 'Windows 10 veya üzeri gerekli.' }
    $arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    if ($arch -ne 'AMD64') { throw 'Bu dağıtım Windows x64 içindir. Bu mimari henüz desteklenmiyor.' }
    Write-Host 'Windows x64 bulundu'
    $InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
    $UserDataDir = [IO.Path]::GetFullPath($UserDataDir)
    $ShortcutPath = [IO.Path]::GetFullPath($ShortcutPath)
    if ($RegistryPath -notmatch '^HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Pofis(?:-[a-f0-9]{32})?$') {
        throw 'Kaldırma kaydı geçersiz.'
    }
    if ($UserDataDir.StartsWith($InstallRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or $UserDataDir -eq $InstallRoot) {
        throw 'Kullanıcı verileri kurulum dizininden ayrı tutulmalı.'
    }
    [IO.Directory]::CreateDirectory($InstallRoot) | Out-Null
    try { $lock = [IO.File]::Open((Join-Path $InstallRoot 'install.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch { throw 'Kurulum dizinine yazılamıyor veya başka bir Pofis kurulumu çalışıyor.' }
    $versions = Join-Path $InstallRoot 'versions'
    [IO.Directory]::CreateDirectory($versions) | Out-Null
    $statePath = Join-Path $InstallRoot 'installed.json'
    if (Test-Path -LiteralPath $statePath) { $previous = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $source = Get-DownloadUri $ManifestUrl $null
    $manifestFile = Join-Path $InstallRoot ([Guid]::NewGuid().ToString('N') + '.json')
    Save-Download $source $manifestFile
    $manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or $manifest.platform -ne 'win32' -or $manifest.arch -ne 'x64' -or
        $manifest.version -notmatch '^\d+\.\d+\.\d+$' -or $manifest.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $manifest.size -le 0) {
        throw 'Dağıtım manifesti geçersiz.'
    }
    if ($previous) {
        if ($previous.version -notmatch '^\d+\.\d+\.\d+$' -or $previous.directory -notmatch '^[a-f0-9]{32}$') { throw 'Mevcut kurulum kaydı geçersiz.' }
        if ([Version]$manifest.version -lt [Version]$previous.version) { throw 'Dağıtım kurulu sürümden eski. Sürüm düşürülmedi.' }
        if ($previous.version -eq $manifest.version) {
            if ($previous.sha256 -ne $manifest.sha256) { throw 'Aynı sürümün paket içeriği değişmiş. Yeni bir sürüm numarası gerekli.' }
            $current = Join-Path $versions $previous.directory
            Assert-RequiredFiles $current $previous.version
            Write-Host "Pofis güncel ($($previous.version))"
            Set-PofisShortcut (Join-Path $current 'Pofis.exe')
            Register-Pofis $current $previous.version
            # Load the verified package's cleanup functions without executing a local script file.
            . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $InstallRoot 'uninstall.ps1'))))
            Remove-PofisVersions $InstallRoot $previous.directory
            Start-VerifiedPofis (Join-Path $current 'Pofis.exe') $previous.version
            return
        }
    }
    Write-Host 'Pofis indiriliyor…'
    $archive = Join-Path $InstallRoot ([Guid]::NewGuid().ToString('N') + '.zip')
    Save-Download (Get-DownloadUri $manifest.url $source) $archive
    Write-Host 'Paket doğrulanıyor…'
    if ((Get-Item -LiteralPath $archive).Length -ne $manifest.size -or
        (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $manifest.sha256) { throw 'Paket bütünlüğü doğrulanamadı. Mevcut kurulum korundu.' }
    $directory = [Guid]::NewGuid().ToString('N')
    # Prepare an inactive version in place. The atomic installed.json write activates it;
    # Directory.Move on deeply nested Next output fails under Windows PowerShell 5.1.
    $stage = Join-Path $versions $directory
    [IO.Directory]::CreateDirectory($stage) | Out-Null
    Expand-VerifiedArchive $archive $stage
    Assert-RequiredFiles $stage $manifest.version
    if (@(Get-InstalledProcess).Count -gt 0) { throw 'Pofis açık. Uygulamayı kapatıp aynı kurulum komutunu yeniden çalıştır.' }
    $target = $stage
    $state = @{ schemaVersion = 1; version = $manifest.version; sha256 = $manifest.sha256; directory = $directory
        installRoot = $InstallRoot; shortcutPath = $ShortcutPath; registryPath = $RegistryPath }
    Write-AtomicJson $statePath $state
    $stage = $null
    Set-PofisShortcut (Join-Path $target 'Pofis.exe')
    Register-Pofis $target $manifest.version
    . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $InstallRoot 'uninstall.ps1'))))
    Remove-PofisVersions $InstallRoot $directory
    Start-VerifiedPofis (Join-Path $target 'Pofis.exe') $manifest.version
    Write-Host "Kurulum tamamlandı · Pofis $($manifest.version)"
} catch {
    $exitCode = 1
    Write-Host "Pofis: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    foreach ($temporary in @($archive, $manifestFile, $stage)) {
        if ($temporary -and (Test-Path -LiteralPath $temporary)) {
            $resolved = [IO.Path]::GetFullPath($temporary)
            if (-not $resolved.StartsWith($InstallRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Geçici dosya temizleme sınırı aşıldı.' }
            if ([IO.Directory]::Exists($resolved)) { [IO.Directory]::Delete(('\\?\' + $resolved), $true) }
            else { [IO.File]::Delete($resolved) }
        }
    }
    if ($lock) { $lock.Dispose() }
}
if ($exitCode -ne 0) { throw 'Pofis kurulumu tamamlanamadı. Yukarıdaki açıklamayı izleyip yeniden dene.' }
