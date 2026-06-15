#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

PROFILE="core"
YES=0

usage() {
  cat <<'USAGE'
الاستخدام: bash install-tools.sh --profile PROFILE [--yes]

الملفات المتاحة:
  core       أساسيات النظام والتحليل
  web        فحص تطبيقات الويب المصرح به
  network    أدوات الشبكات والتشخيص
  forensics  التحليل الجنائي والملفات
  audit      تدقيق كلمات المرور المصرح به
  all        جميع الملفات السابقة
USAGE
}

while (($#)); do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --yes|-y) YES=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "خيار غير معروف: $1" ;;
  esac
done

case "$PROFILE" in core|web|network|forensics|audit|all) ;; *) die "ملف أدوات غير صحيح: $PROFILE" ;; esac
ensure_termux
command -v nethunter >/dev/null 2>&1 || die "NetHunter غير مثبت أو أمر nethunter غير موجود."

profiles=("$PROFILE")
[[ "$PROFILE" == "all" ]] && profiles=(core web network forensics audit)

packages=()
for profile in "${profiles[@]}"; do
  file="$SCRIPT_DIR/packages/$profile.txt"
  [[ -f "$file" ]] || die "ملف الحزم مفقود: $file"
  while IFS= read -r package; do
    [[ -z "$package" || "$package" == \#* ]] && continue
    packages+=("$package")
  done < "$file"
done

mapfile -t packages < <(printf '%s\n' "${packages[@]}" | awk '!seen[$0]++')
((${#packages[@]})) || die "قائمة الحزم فارغة."

info "سيتم تثبيت ${#packages[@]} حزمة داخل Kali بدون full-upgrade."
printf '  %s\n' "${packages[@]}"
if ((YES == 0)); then
  read -r -p "متابعة؟ [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "أُلغي التثبيت."
fi

PKG_LINE="$(printf '%q ' "${packages[@]}")"
KALI_CMD="export DEBIAN_FRONTEND=noninteractive SYSTEMD_OFFLINE=1; printf '#!/bin/sh\\nexit 101\\n' > /usr/sbin/policy-rc.d; chmod 755 /usr/sbin/policy-rc.d; apt-get update; apt-get install -y --no-install-recommends $PKG_LINE"

if nethunter -r "$KALI_CMD"; then
  log "اكتمل تثبيت ملف الأدوات: $PROFILE"
else
  warn "فشل التثبيت المجمع؛ ستتم محاولة كل حزمة منفردة لمعرفة الحزم غير المتاحة."
  failed=()
  for package in "${packages[@]}"; do
    if nethunter -r "export DEBIAN_FRONTEND=noninteractive SYSTEMD_OFFLINE=1; apt-get install -y --no-install-recommends $(printf '%q' "$package")"; then
      log "مثبت: $package"
    else
      failed+=("$package")
      warn "تعذر تثبيت: $package"
    fi
  done
  if ((${#failed[@]})); then
    printf 'الحزم التي تعذر تثبيتها:\n  %s\n' "${failed[@]}"
    exit 1
  fi
fi
