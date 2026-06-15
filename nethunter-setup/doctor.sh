#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

FIX_SOURCES=0
CLEAN_PARTIALS=0

usage() {
  cat <<'USAGE'
الاستخدام: bash doctor.sh [--fix-sources] [--clean-partials]

--fix-sources     تعطيل ملفات مصادر APT الإضافية التي تشير إلى مستودع GitHub القديم المعطل
--clean-partials  حذف ملفات aria2 الجزئية فقط (لا يحذف rootfs المكتمل)
USAGE
}

while (($#)); do
  case "$1" in
    --fix-sources) FIX_SOURCES=1; shift ;;
    --clean-partials) CLEAN_PARTIALS=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "خيار غير معروف: $1" ;;
  esac
done

ensure_termux
prepare_dirs
ARCH="$(get_arch)"
CHROOT_DIR="$HOME/kali-$ARCH"
FAILURES=0

check() {
  local label="$1"; shift
  if "$@"; then log "$label"; else warn "$label"; FAILURES=$((FAILURES + 1)); fi
}

printf '\n=== NetHunter Doctor ===\n'
info "المعمارية: $ARCH"
info "المساحة المتاحة: $(human_gib_from_kb "$(free_kb)")"

check "DNS يعمل لـ kali.download" nslookup kali.download
check "المصدر الرسمي متاح" curl -fsSI --connect-timeout 20 "$NH_OFFICIAL_INSTALLER_URL"

BAD_SOURCE_PATTERN='raw.githubusercontent.com/ly5851575-oss/termux-apt-repo'
mapfile -t BAD_FILES < <(grep -RIl "$BAD_SOURCE_PATTERN" "$PREFIX/etc/apt" 2>/dev/null || true)
if ((${#BAD_FILES[@]})); then
  warn "تم العثور على مصدر APT قديم/معطل:"
  printf '  %s\n' "${BAD_FILES[@]}"
  if ((FIX_SOURCES)); then
    stamp="$(safe_timestamp)"
    for file in "${BAD_FILES[@]}"; do
      mv -- "$file" "$file.disabled.$stamp"
      log "عُطّل: $file"
    done
  else
    warn "للإصلاح: bash doctor.sh --fix-sources"
  fi
else
  log "لا توجد مصادر APT القديمة المعروفة."
fi

if ((CLEAN_PARTIALS)); then
  find "$HOME" -maxdepth 1 -type f -name 'kali-nethunter-rootfs-*.aria2' -print -delete
  log "تم تنظيف ملفات التنزيل الجزئية."
fi

shopt -s nullglob
archives=("$HOME"/kali-nethunter-rootfs-*.tar.xz)
if ((${#archives[@]})); then
  for archive in "${archives[@]}"; do
    info "فحص: $(basename "$archive")"
    if xz -t "$archive"; then log "الأرشيف سليم"; else warn "الأرشيف تالف: $archive"; FAILURES=$((FAILURES + 1)); fi
  done
else
  info "لا يوجد أرشيف rootfs محفوظ."
fi
shopt -u nullglob

if [[ -d "$CHROOT_DIR" ]]; then
  for required in usr/bin/env bin/bash etc/passwd; do
    if [[ -e "$CHROOT_DIR/$required" ]]; then
      log "موجود: $required"
    else
      warn "مفقود: $required"
      FAILURES=$((FAILURES + 1))
    fi
  done
else
  warn "مجلد Kali غير موجود: $CHROOT_DIR"
  FAILURES=$((FAILURES + 1))
fi

if command -v nethunter >/dev/null 2>&1; then
  log "أمر nethunter موجود."
  if timeout 30 nethunter -r 'printf NH_BOOT_OK' 2>/dev/null | grep -q NH_BOOT_OK; then
    log "اختبار الإقلاع نجح."
  else
    warn "اختبار الإقلاع فشل."
    FAILURES=$((FAILURES + 1))
  fi
else
  warn "أمر nethunter غير موجود."
  FAILURES=$((FAILURES + 1))
fi

printf '\n'
if ((FAILURES == 0)); then
  log "كل الفحوصات الأساسية نجحت."
else
  warn "عدد المشكلات المكتشفة: $FAILURES"
  exit 1
fi
