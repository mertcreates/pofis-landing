#!/bin/bash
# macOS ships Bash 3.2 and all tools used here; Node, Bun and Homebrew are not needed.
set -euo pipefail
umask 077
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

die() { printf 'Pofis: %s\n' "$*" >&2; return 1; }
json() { /usr/bin/plutil -extract "$2" raw -o - "$1" 2>/dev/null || die "Dosya alanı okunamadı: $2"; }
valid_version() { [[ "$1" != *[!0-9.]* && "$1" =~ ^(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})$ ]]; }
older() {
  local a b c x y z
  IFS=. read -r a b c <<< "$1"
  IFS=. read -r x y z <<< "$2"
  (( a < x || (a == x && b < y) || (a == x && b == y && c < z) ))
}

download() {
  local protocols='=https'
  case "$1" in
    https://*) ;;
    http://127.0.0.1:*/*|http://localhost:*/*) protocols='=http,https' ;;
    *) die 'İndirme adresi HTTPS olmalı; yerel testte yalnız loopback HTTP kullanılabilir.'; return 1 ;;
  esac
  /usr/bin/curl -fLsS --proto "$protocols" --proto-redir '=https' \
    --connect-timeout 15 --max-time 180 --output "$2" "$1" || { die 'İndirme tamamlanamadı. Mevcut kurulum korundu.'; return 1; }
}

assert_bundle() {
  local bundle="$1" version="$2" resources plist file minimum actual cpu
  resources="$bundle/Contents/Resources"
  plist="$bundle/Contents/Info.plist"
  for file in "$plist" "$bundle/Contents/MacOS/Pofis" "$resources/release.json" \
    "$resources/app/package.json" "$resources/app/electron/main.cjs" \
    "$resources/app/electron/server.cjs" "$resources/app/electron/server-entry.cjs" \
    "$resources/app/electron/startup.cjs" "$resources/app/electron/platform.cjs" \
    "$resources/app/server/server.js" "$resources/app/server/.next/BUILD_ID" \
    "$resources/app/server/node_modules/next/package.json"; do
    [[ -f "$file" ]] || { die 'Paketin gerekli dosyaları eksik.'; return 1; }
  done
  [[ "$(json "$resources/release.json" schemaVersion)" == 1 && \
    "$(json "$resources/release.json" platform)" == darwin && \
    "$(json "$resources/release.json" arch)" == "$arch" && \
    "$(json "$resources/release.json" version)" == "$version" && \
    "$(json "$resources/app/package.json" version)" == "$version" && \
    "$(json "$plist" CFBundleIdentifier)" == app.pofis.client && \
    "$(json "$plist" CFBundleShortVersionString)" == "$version" ]] || { die 'Paket kimliği, sürümü veya mimarisi eşleşmiyor.'; return 1; }
  # file is a system tool; lipo can prompt end users to install Xcode Command Line Tools.
  cpu="$(/usr/bin/file -b "$bundle/Contents/MacOS/Pofis")"
  case "$arch:$cpu" in
    arm64:'Mach-O 64-bit executable arm64'*|x64:'Mach-O 64-bit executable x86_64'*) ;;
    *) die 'Uygulamanın mimarisi eşleşmiyor.'; return 1 ;;
  esac
  minimum="$(json "$plist" LSMinimumSystemVersion 2>/dev/null || true)"
  if [[ -n "$minimum" ]]; then
    actual="$(/usr/bin/sw_vers -productVersion)"
    while [[ "$minimum" != *.*.* ]]; do minimum="$minimum.0"; done
    while [[ "$actual" != *.*.* ]]; do actual="$actual.0"; done
    if ! valid_version "$minimum" || ! valid_version "$actual"; then die 'macOS sürümü doğrulanamadı.'; return 1; fi
    if older "$actual" "$minimum"; then die "macOS $minimum veya üzeri gerekli."; return 1; fi
  fi
  /usr/bin/codesign --verify --deep --strict --verbose=3 "$bundle" || { die 'Uygulama imzası doğrulanamadı.'; return 1; }
}

assert_archive_paths() {
  local entry
  while IFS= read -r entry; do
    case "$entry" in
      Pofis.app|Pofis.app/*|__MACOSX|__MACOSX/*) ;;
      *) die 'Arşivde beklenmeyen bir dosya yolu var.'; return 1 ;;
    esac
    case "/$entry/" in
      */../*|*/./*|*\\*) die 'Arşivde güvenli olmayan bir dosya yolu var.'; return 1 ;;
    esac
  done < "$1"
}

assert_links() {
  local bundle="$1" link value parent
  while IFS= read -r -d '' link; do
    value="$(/usr/bin/readlink "$link")"
    [[ "$value" != /* && -e "$link" ]] || { die 'Pakette geçersiz sembolik bağlantı var.'; return 1; }
    parent="$(cd "$(/usr/bin/dirname "$link")" && cd -P "$(/usr/bin/dirname "$value")" && pwd -P)" || return 1
    case "$parent/" in "$bundle/"*) ;; *) die 'Paket bağlantısı uygulama dışına çıkıyor.'; return 1 ;; esac
  done < <(/usr/bin/find "$bundle" -type l -print0)
}

running_pids() {
  /bin/ps -ww -axo pid=,comm= | /usr/bin/awk -v app="$app_path/Contents/" \
    '{pid=$1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); if (index($0,app)==1) print pid}'
}

confirm_close() {
  local answer
  # stdin can contain the installer itself (curl | bash); read consent from the terminal.
  [[ -t 1 ]] || { die "Pofis açık. Onay alınamadı. Pofis'i kapatıp komutu yeniden çalıştırabilirsin."; return 1; }
  if ! {
    printf '\n%s\n' '------------------------------------------------------------' > /dev/tty
    printf '%s\n' '   /\_/\' > /dev/tty
    if [[ "${2:-}" == force ]]; then
      printf '%s\n' '  ( o.o )   Pofis | Zorla kapatma onayı' > /dev/tty
    else
      printf '%s\n' '  ( o.o )   Pofis | Uygulama açık' > /dev/tty
    fi
    printf '%s\n' '   > ^ <' > /dev/tty
    printf '%s\n%s\n\n' '------------------------------------------------------------' "$1" > /dev/tty
    if [[ "${2:-}" == force ]]; then
      printf '%s\n' '  e = Uygulamayı zorla kapat ve güncellemeye devam et' > /dev/tty
    else
      printf '%s\n' '  e = Uygulamayı kapat ve güncellemeye devam et' > /dev/tty
    fi
    printf '%s\n\n%s' '  h veya Enter = Güncellemeyi iptal et' 'Seçimin [e/H] ' > /dev/tty
    IFS= read -r answer < /dev/tty
  } 2>/dev/null; then
    die "Pofis açık. Onay alınamadı. Pofis'i kapatıp komutu yeniden çalıştırabilirsin."; return 1
  fi
  case "$answer" in e|E|evet|Evet|EVET) return 0 ;; *) return 1 ;; esac
}

wait_closed() {
  local pids deadline=$((SECONDS + 10))
  while true; do
    pids="$(running_pids)" || return 1
    [[ -n "$pids" ]] || return 0
    (( SECONDS < deadline )) || return 1
    /bin/sleep 0.2
  done
}

request_close() {
  # Pass the exact bundle path as data; a timed-out quit falls through to separate force consent.
  /usr/bin/osascript - "$app_path" <<'APPLESCRIPT'
on run argv
  with timeout of 5 seconds
    tell application (item 1 of argv) to quit
  end timeout
end run
APPLESCRIPT
}

force_close() {
  local pid executable pids
  pids="$(running_pids)" || return 1
  for pid in $pids; do
    # Recheck the executable immediately before signalling; never kill by app/process name.
    executable="$(/bin/ps -ww -p "$pid" -o comm=)" || continue
    case "$executable" in "$app_path/Contents/"*) /bin/kill -KILL "$pid" || {
      [[ -z "$(/bin/ps -p "$pid" -o pid=)" ]] || return 1
    } ;; esac
  done
}

close_for_update() {
  local pids
  pids="$(running_pids)" || { die 'Pofis’in kapalı olduğu doğrulanamadı. Kurulu sürüm aynı kaldı.'; return 1; }
  [[ -n "$pids" ]] || return 0
  confirm_close 'Yeni sürüm hazır. Devam etmek için açık Pofis kapanacak.' || {
    die 'Güncelleme iptal edildi. Kurulu sürüm aynı kaldı.'; return 1
  }
  request_close || printf 'Pofis normal yolla kapatılamadı.\n' >&2
  if wait_closed; then return 0; fi
  confirm_close 'Pofis henüz kapanmadı. Zorla kapatılsın mı?
Kaydedilmemiş değişiklikler kaybolabilir.' force || {
    die "Güncelleme iptal edildi. Kurulu sürüm aynı kaldı. Pofis'i kapatıp yeniden deneyebilirsin."; return 1
  }
  force_close || { die 'Pofis kapatılamadığı için güncelleme durdu. Kurulu sürüm aynı kaldı.'; return 1; }
  wait_closed || { die 'Pofis kapanmadığı için güncelleme durdu. Kurulu sürüm aynı kaldı.'; return 1; }
}

activate() {
  local backup="$stage/previous.app"
  switching=true
  if [[ -d "$app_path" ]]; then /bin/mv "$app_path" "$backup"; fi
  if ! /bin/mv "$stage/Pofis.app" "$app_path"; then
    [[ ! -d "$backup" ]] || /bin/mv "$backup" "$app_path"
    die 'Pofis uygulama klasörüne taşınamadı. Mevcut kurulum korundu.'; return 1
  fi
  if ! /bin/mv -f "$work/manifest.json" "$install_root/installed.json"; then
    /bin/mv "$app_path" "$stage/Pofis.app"
    [[ ! -d "$backup" ]] || /bin/mv "$backup" "$app_path"
    die 'Kurulum kaydı yazılamadı. Mevcut kurulum korundu.'; return 1
  fi
  switching=false
}

clear_staging_versions() {
  local candidate name
  [[ -d "$install_root/versions" && ! -L "$install_root/versions" ]] || { die 'Sürüm dizini doğrulanamadı.'; return 1; }
  for candidate in "$install_root/versions/"*; do
    [[ -e "$candidate" || -L "$candidate" ]] || continue
    name="${candidate##*/}"
    [[ "$name" =~ ^[a-f0-9]{32}$ && -d "$candidate" && ! -L "$candidate" ]] || { die 'Sürüm dizininde beklenmeyen dosya var.'; return 1; }
    /bin/rm -rf "$candidate"
  done
}

assert_startup_result() {
  local receipt="$1" id="$2" version="$3" status message
  if [[ "$(json "$receipt" schemaVersion)" != 1 || "$(json "$receipt" requestId)" != "$id" || \
    "$(json "$receipt" version)" != "$version" ]]; then
    die 'Pofis açılış sonucu doğrulanamadı. Uygulamayı kapatıp yeniden dene.'; return 1
  fi
  status="$(json "$receipt" status)"
  if [[ "$status" == error ]]; then
    message="$(json "$receipt" message)"
    die "${message:-Pofis başlatılamadı. Uygulamayı yeniden aç.}"; return 1
  fi
  if [[ "$status" != ready || "$(json "$receipt" windowReady)" != true ]]; then
    die 'Pofis penceresi hazır olmadı. Uygulamayı kapatıp yeniden dene.'; return 1
  fi
}

launch() {
  local bundle="$1" version="$2" id receipt deadline pid executable
  id="$(/usr/bin/uuidgen | /usr/bin/tr -d '-' | /usr/bin/tr '[:upper:]' '[:lower:]')"
  receipt="$user_data/launch-results/$id.json"
  printf 'Pofis açılıyor…\n'
  # -n delivers the request arguments even when the primary instance is already open.
  /usr/bin/open -n "$bundle" --args "--startup-id=$id" "--user-data-dir=$user_data" || { die 'Pofis başlatılamadı.'; return 1; }
  deadline=$((SECONDS + 45))
  while (( SECONDS < deadline )); do
    if [[ -f "$receipt" ]]; then
      if ! assert_startup_result "$receipt" "$id" "$version"; then
        /bin/rm -f "$receipt"
        return 1
      fi
      pid="$(json "$receipt" pid)"
      executable="$(json "$receipt" executable)"
      /bin/rm -f "$receipt"
      [[ "$pid" =~ ^[1-9][0-9]*$ && "$executable" == "$bundle/Contents/MacOS/Pofis" && \
        "$(/bin/ps -ww -p "$pid" -o comm=)" == "$executable" ]] || { die 'Çalışan Pofis süreci doğrulanamadı.'; return 1; }
      printf 'Pofis hazır\n'
      return 0
    fi
    /bin/sleep 0.2
  done
  die 'Pofis penceresi 45 saniye içinde hazır olmadı. Güvenlik uyarısı varsa Sistem Ayarları → Gizlilik ve Güvenlik bölümünü kontrol et.'
}

cleanup() {
  local result=$?
  trap - EXIT INT TERM HUP
  if [[ "$switching" == true && -n "$stage" ]]; then
    # An interruption during the two renames must not discard the previous bundle.
    if [[ ! -d "$stage/Pofis.app" && -d "$app_path" ]]; then /bin/mv "$app_path" "$stage/Pofis.app"; fi
    if [[ -d "$stage/previous.app" ]]; then
      if ! /bin/mv "$stage/previous.app" "$app_path"; then
        printf 'Önceki uygulama %s konumunda korundu.\n' "$stage/previous.app" >&2
        stage=''
      fi
    fi
  fi
  if [[ -n "$work" && "$work" == "$install_root"/download.* ]]; then /bin/rm -rf "$work"; fi
  if [[ -n "$stage" && "$stage" == "$install_root/versions/"* ]]; then /bin/rm -rf "$stage"; fi
  if [[ "$locked" == true ]]; then /bin/rm -f "$install_root/install.lock/pid"; /bin/rmdir "$install_root/install.lock"; fi
  exit "$result"
}

main() {
  printf 'Pofis kurulumu başlatılıyor…\nSistem kontrol ediliyor…\n'
  [[ "$(/usr/bin/uname -s)" == Darwin ]] || { die 'Bu kurulum macOS içindir.'; return 1; }
  [[ "$(/usr/bin/id -u)" != 0 ]] || { die 'Komutu sudo kullanmadan kendi hesabında çalıştır.'; return 1; }
  arch="$(/usr/bin/uname -m)"
  if [[ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then arch=arm64; fi
  [[ "$arch" != x86_64 ]] || arch=x64
  [[ "$arch" == arm64 || "$arch" == x64 ]] || { die 'Bu macOS mimarisi desteklenmiyor.'; return 1; }
  printf 'macOS %s bulundu\n' "$arch"
  install_root="$HOME/Library/Application Support/Pofis Installer"
  app_path="$HOME/Applications/Pofis.app"
  user_data="$HOME/Library/Application Support/Pofis"
  manifest_url="https://pofis.app/releases/macos/$arch/latest.json"
  while (( $# )); do
    [[ $# -ge 2 ]] || { die 'Kurulum parametresi eksik.'; return 1; }
    case "$1" in
      --manifest-url) manifest_url="$2" ;;
      --install-root) install_root="$2" ;;
      --app-path) app_path="$2" ;;
      --user-data-dir) user_data="$2" ;;
      *) die 'Bilinmeyen kurulum parametresi.'; return 1 ;;
    esac
    shift 2
  done
  [[ "$install_root" == /* && "$app_path" == /* && "$user_data" == /* ]] || { die 'Kurulum yolları mutlak olmalı.'; return 1; }
  /bin/mkdir -p "$install_root/versions" "$(/usr/bin/dirname "$app_path")" "$user_data"
  install_root="$(cd "$install_root" && pwd -P)"
  user_data="$(cd "$user_data" && pwd -P)"
  app_path="$(cd "$(/usr/bin/dirname "$app_path")" && pwd -P)/$(/usr/bin/basename "$app_path")"
  case "$user_data/" in "$install_root/"*) die 'Profil kurulum dosyalarından ayrı tutulmalı.'; return 1 ;; esac
  case "$install_root/" in "$user_data/"*) die 'Kurulum dosyaları profilin dışında tutulmalı.'; return 1 ;; esac
  case "$app_path" in "$install_root"/*) die 'Uygulama simgesi sürüm dizininden ayrı tutulmalı.'; return 1 ;; esac
  case "$app_path/" in "$user_data/"*) die 'Uygulama kullanıcı verilerinden ayrı tutulmalı.'; return 1 ;; esac
  case "$user_data/" in "$app_path/"*) die 'Kullanıcı verileri uygulamanın dışında tutulmalı.'; return 1 ;; esac
  /bin/chmod 700 "$install_root"
  locked=false switching=false previous_version='' stage='' work=''
  if ! /bin/mkdir "$install_root/install.lock" 2>/dev/null; then
    die "Başka bir Pofis kurulumu çalışıyor veya yarım kalmış. Kurulum çalışmıyorsa $install_root/install.lock dizinini kaldırıp yeniden dene."; return 1
  fi
  locked=true
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
  printf '%s\n' "$$" > "$install_root/install.lock/pid"
  work="$(/usr/bin/mktemp -d "$install_root/download.XXXXXX")"
  download "$manifest_url" "$work/manifest.json"
  local version sha size url directory record old_sha
  version="$(json "$work/manifest.json" version)"
  sha="$(json "$work/manifest.json" sha256)"
  size="$(json "$work/manifest.json" size)"
  url="$(json "$work/manifest.json" url)"
  if [[ "$(json "$work/manifest.json" schemaVersion)" != 1 || "$(json "$work/manifest.json" platform)" != darwin || \
    "$(json "$work/manifest.json" arch)" != "$arch" ]] || ! valid_version "$version" || \
    [[ ! "$sha" =~ ^[a-f0-9]{64}$ || ! "$size" =~ ^[1-9][0-9]{0,9}$ ]] || (( size >= 2147483648 )); then
    die 'Dağıtım manifesti geçersiz.'; return 1
  fi
  if [[ -L "$app_path" ]]; then die 'Uygulama konumu sembolik bağlantı olamaz.'; return 1
  elif [[ -e "$app_path" ]]; then
    [[ -d "$app_path" && -f "$install_root/installed.json" ]] || { die 'Bu konumda kurulumun yönetmediği bir uygulama var; üzerine yazılmadı.'; return 1; }
    record="$install_root/installed.json"
    previous_version="$(json "$record" version)"; old_sha="$(json "$record" sha256)"
    valid_version "$previous_version" && [[ "$old_sha" =~ ^[a-f0-9]{64}$ ]] || { die 'Mevcut kurulum kaydı geçersiz.'; return 1; }
    assert_bundle "$app_path" "$previous_version"
    if older "$version" "$previous_version"; then die 'Sürüm düşürülmedi; mevcut kurulum korundu.'; return 1; fi
    if [[ "$version" == "$previous_version" ]]; then
      [[ "$sha" == "$old_sha" ]] || { die 'Aynı sürümün paket içeriği değişmiş. Yeni sürüm gerekli.'; return 1; }
      printf 'Pofis güncel (%s)\n' "$version"
      clear_staging_versions
      launch "$app_path" "$version"
      return
    fi
  fi
  case "$url" in
    "$version/Pofis-$version-darwin-$arch.zip") url="${manifest_url%/*}/$url" ;;
  esac
  printf 'Pofis indiriliyor…\n'
  download "$url" "$work/package.zip"
  printf 'Paket doğrulanıyor…\n'
  [[ "$(/usr/bin/stat -f %z "$work/package.zip")" == "$size" && \
    "$(/usr/bin/shasum -a 256 "$work/package.zip" | /usr/bin/awk '{print $1}')" == "$sha" ]] || { die 'Paket boyutu veya SHA-256 değeri eşleşmiyor.'; return 1; }
  /usr/bin/tar -tf "$work/package.zip" > "$work/entries.txt"
  assert_archive_paths "$work/entries.txt"
  directory="$(/usr/bin/uuidgen | /usr/bin/tr -d '-' | /usr/bin/tr '[:upper:]' '[:lower:]')"
  stage="$install_root/versions/$directory"
  /bin/mkdir "$stage"
  # macOS bsdtar rejects path traversal and extraction through unsafe symlinks by default.
  /usr/bin/tar -xf "$work/package.zip" -C "$stage"
  assert_links "$stage/Pofis.app"
  assert_bundle "$stage/Pofis.app" "$version"
  close_for_update
  activate
  clear_staging_versions
  stage=''
  launch "$app_path" "$version"
  printf 'Kurulum tamamlandı · Pofis %s\n' "$version"
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]:-}" == "$0" ]]; then main "$@"; fi
