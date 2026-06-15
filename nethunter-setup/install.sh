#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

IMAGE="full"
PROFILE="core"
YES=0
REINSTALL=0
KEEP_ARCHIVE=1
SKIP_TOOLS=0
DOWNLOAD_ONLY=0
WAKE_LOCK=1

usage() {
  cat <<'USAGE'
NetHunter Setup — مثبت موثوق لـ Kali NetHunter Rootless على Termux

الاستخدام:
  bash install.sh [خيارات]

الخيارات:
  --image full|minimal|nano   نوع صورة NetHunter (الافتراضي: full)
  --profile core|web|network|forensics|audit|all|none
                             حزمة الأدوات بعد التثبيت (الافتراضي: core)
  --reinstall                حذف بيئة Kali الحالية وإعادة تثبيتها
  --delete-archive           حذف ملف rootfs بعد نجاح التثبيت
  --download-only            تنزيل الصورة والتحقق منها فقط
  --skip-tools               عدم تثبيت أدوات إضافية
  --yes, -y                  الموافقة التلقائية
  --no-wake-lock             عدم تفعيل منع نوم Termux
  --help, -h                 عرض المساعدة
USAGE
}

while (($#)); do
  case "$1" in
    --image) IMAGE="${2:-}"; shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --reinstall) REINSTALL=1; shift ;;
    --delete-archive) KEEP_ARCHIVE=0; shift ;;
    --download-only) DOWNLOAD_ONLY=1; shift ;;
    --skip-tools) SKIP_TOOLS=1; shift ;;
    --yes|-y) YES=1; shift ;;
    --no-wake-lock) WAKE_LOCK=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "خيار غير معروف: $1" ;;
  esac
done

case "$IMAGE" in full|minimal|nano) ;; *) die "--image يجب أن يكون full أو minimal أو nano" ;; esac
case "$PROFILE" in core|web|network|forensics|audit|all|none) ;; *) die "--profile غير صحيح" ;; esac

ensure_termux
prepare_dirs
ARCH="$(get_arch)"
CHROOT_DIR="$HOME/kali-$ARCH"
IMAGE_NAME="kali-nethunter-rootfs-${IMAGE}-${ARCH}.tar.xz"
IMAGE_PATH="$HOME/$IMAGE_NAME"
SHA_PATH="$HOME/${IMAGE_NAME}.sha512sum"
ROOTFS_URL="$NH_ROOTFS_BASE_URL/$IMAGE_NAME"
SHA_URL="$NH_ROOTFS_BASE_URL/${IMAGE_NAME}.sha512sum"
INSTALLER="$NH_CACHE_DIR/install-nethunter-termux"
LOG_FILE="$NH_LOG_DIR/install-$(safe_timestamp).log"

exec > >(tee -a "$LOG_FILE") 2>&1
trap 'warn "توقف التثبيت عند السطر $LINENO. السجل: $LOG_FILE"' ERR

info "المعمارية: $ARCH"
info "الصورة: $IMAGE"
info "سجل العملية: $LOG_FILE"

if ((WAKE_LOCK)) && command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock || true
fi

NEEDED_KB="$(required_free_kb "$IMAGE")"
AVAILABLE_KB="$(free_kb)"
if (( AVAILABLE_KB < NEEDED_KB )); then
  die "المساحة غير كافية. المتاح $(human_gib_from_kb "$AVAILABLE_KB") والمطلوب تقريبًا $(human_gib_from_kb "$NEEDED_KB")."
fi

if [[ -d "$CHROOT_DIR" ]]; then
  if ((REINSTALL)); then
    warn "سيتم حذف البيئة الحالية: $CHROOT_DIR"
    ((YES)) || read -r -p "اكتب DELETE للمتابعة: " confirm
    ((YES)) || [[ "${confirm:-}" == "DELETE" ]] || die "أُلغي الحذف."
    rm -rf -- "$CHROOT_DIR"
  else
    die "توجد بيئة Kali بالفعل في $CHROOT_DIR. استخدم --reinstall لإعادة التثبيت، أو شغّل doctor.sh للتشخيص."
  fi
fi

info "تثبيت متطلبات Termux الرسمية..."
pkg update -y
pkg install -y ca-certificates curl wget aria2 xz-utils proot tar coreutils openssl-tool dnsutils

info "فحص DNS والاتصال بالمصدر الرسمي..."
retry 5 5 nslookup kali.download >/dev/null || die "فشل DNS لـ kali.download. اجعل DNS الخاص تلقائيًا أو dns.google ثم أعد المحاولة."
retry 5 5 curl -fsSI --connect-timeout 20 "$NH_OFFICIAL_INSTALLER_URL" >/dev/null || die "تعذر الوصول إلى مثبت Kali الرسمي."

info "تنزيل مثبت NetHunter الرسمي..."
retry 5 5 curl -fL --retry 5 --retry-all-errors --connect-timeout 30 \
  -o "$INSTALLER.tmp" "$NH_OFFICIAL_INSTALLER_URL"
mv -f "$INSTALLER.tmp" "$INSTALLER"
chmod 700 "$INSTALLER"
grep -q 'BASE_URL=https://kali.download/nethunter-images/current/rootfs' "$INSTALLER" || \
  die "تعذر التحقق من بنية المثبت الرسمي؛ تم إيقاف العملية احترازيًا."

# اجعل خطأ فك الضغط قاتلًا بدل أن يخفيه المثبت الرسمي.
sed -i 's@proot --link2symlink tar -xf "\$IMAGE_NAME" 2> /dev/null || :@proot --link2symlink tar -xf "\$IMAGE_NAME"@' "$INSTALLER"

info "تنزيل rootfs مع الاستئناف التلقائي..."
aria2c \
  --continue=true \
  --auto-file-renaming=false \
  --allow-overwrite=true \
  --file-allocation=none \
  --check-certificate=true \
  --disable-ipv6=true \
  --max-tries=0 \
  --retry-wait=5 \
  --connect-timeout=30 \
  --timeout=60 \
  -x 4 -s 4 -k 1M \
  -d "$HOME" -o "$IMAGE_NAME" \
  "$ROOTFS_URL"

info "اختبار سلامة ضغط XZ..."
xz -t "$IMAGE_PATH" || {
  rm -f -- "$IMAGE_PATH" "$IMAGE_PATH.aria2"
  die "ملف rootfs تالف. حُذف الملف التالف؛ أعد تشغيل الأمر ليُنزّل نسخة سليمة."
}

info "محاولة التحقق ببصمة SHA-512 الرسمية..."
if curl -fL --retry 5 --retry-all-errors --connect-timeout 30 -o "$SHA_PATH.tmp" "$SHA_URL"; then
  mv -f "$SHA_PATH.tmp" "$SHA_PATH"
  (cd "$HOME" && sha512sum -c "$(basename "$SHA_PATH")") || {
    rm -f -- "$IMAGE_PATH" "$SHA_PATH"
    die "فشل تحقق SHA-512. حُذف الملف المشكوك فيه."
  }
  log "نجح تحقق SHA-512."
else
  rm -f -- "$SHA_PATH.tmp"
  warn "المصدر الرسمي لم ينشر ملف SHA لهذه الصورة؛ تم الاكتفاء باختبار XZ والتنزيل عبر TLS."
fi

if ((DOWNLOAD_ONLY)); then
  log "اكتمل التنزيل والتحقق: $IMAGE_PATH"
  exit 0
fi

CHOICE="$(image_choice "$IMAGE")"
DELETE_ANSWER="n"
((KEEP_ARCHIVE)) || DELETE_ANSWER="y"

info "تشغيل مثبت Kali الرسمي باستخدام الملف الذي تم التحقق منه..."
printf '%s\nn\n%s\n' "$CHOICE" "$DELETE_ANSWER" | "$INSTALLER"

info "التحقق من اكتمال rootfs..."
for required in usr/bin/env bin/bash etc/passwd; do
  [[ -e "$CHROOT_DIR/$required" ]] || {
    rm -rf -- "$CHROOT_DIR"
    die "التثبيت غير مكتمل: الملف $required مفقود. حُذفت البيئة الناقصة، وأُبقي ملف rootfs لإعادة المحاولة."
  }
done
chmod 755 "$CHROOT_DIR/usr/bin/env" "$CHROOT_DIR/bin/bash" 2>/dev/null || true

command -v nethunter >/dev/null 2>&1 || die "لم يُنشأ أمر nethunter."
if timeout 30 nethunter -r 'printf NH_BOOT_OK' 2>/dev/null | grep -q NH_BOOT_OK; then
  log "اختبار تشغيل NetHunter نجح."
else
  die "فشل اختبار التشغيل. شغّل: bash $SCRIPT_DIR/doctor.sh"
fi

if ((SKIP_TOOLS == 0)) && [[ "$PROFILE" != "none" ]]; then
  info "تثبيت ملف الأدوات: $PROFILE"
  bash "$SCRIPT_DIR/install-tools.sh" --profile "$PROFILE" --yes
fi

log "اكتمل NetHunter بنجاح. للدخول: nethunter -r"
((KEEP_ARCHIVE)) && info "احتُفظ بملف النسخة: $IMAGE_PATH"
