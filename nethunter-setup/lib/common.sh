#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

NH_OFFICIAL_INSTALLER_URL="https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-rootless/-/raw/main/install-nethunter-termux"
NH_ROOTFS_BASE_URL="https://kali.download/nethunter-images/current/rootfs"
NH_CACHE_DIR="${HOME}/.cache/nethunter-setup"
NH_LOG_DIR="${HOME}/.local/state/nethunter-setup"
NH_REPORT_DIR="${HOME}/security-reports"

C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[1;34m'
C_CYAN='\033[1;36m'

log() { printf "%b[+]%b %s\n" "$C_GREEN" "$C_RESET" "$*"; }
info() { printf "%b[*]%b %s\n" "$C_BLUE" "$C_RESET" "$*"; }
warn() { printf "%b[!]%b %s\n" "$C_YELLOW" "$C_RESET" "$*" >&2; }
die() { printf "%b[ERROR]%b %s\n" "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

ensure_termux() {
  [[ -n "${PREFIX:-}" && "$PREFIX" == */com.termux/files/usr ]] || \
    die "شغّل هذا السكربت من تطبيق Termux، وليس من داخل Kali أو Debian."
  command -v getprop >/dev/null 2>&1 || die "تعذر العثور على getprop؛ بيئة Termux غير مكتملة."
}

get_arch() {
  case "$(getprop ro.product.cpu.abi 2>/dev/null || true)" in
    arm64-v8a) printf 'arm64\n' ;;
    armeabi|armeabi-v7a) printf 'armhf\n' ;;
    *) die "معمارية الجهاز غير مدعومة: $(getprop ro.product.cpu.abi 2>/dev/null || echo unknown)" ;;
  esac
}

image_choice() {
  case "$1" in
    full) printf '1\n' ;;
    minimal) printf '2\n' ;;
    nano) printf '3\n' ;;
    *) die "نوع الصورة غير صحيح: $1 (المتاح: full|minimal|nano)" ;;
  esac
}

required_free_kb() {
  case "$1" in
    full) printf '%s\n' $((14 * 1024 * 1024)) ;;
    minimal) printf '%s\n' $((6 * 1024 * 1024)) ;;
    nano) printf '%s\n' $((4 * 1024 * 1024)) ;;
  esac
}

free_kb() { df -Pk "$HOME" | awk 'NR==2 {print $4}'; }

human_gib_from_kb() {
  awk -v kb="$1" 'BEGIN {printf "%.1f GiB", kb/1024/1024}'
}

retry() {
  local attempts="$1" delay="$2"; shift 2
  local n=1
  until "$@"; do
    (( n >= attempts )) && return 1
    warn "فشلت المحاولة $n/$attempts؛ إعادة المحاولة بعد ${delay}s..."
    sleep "$delay"
    ((n++))
  done
}

prepare_dirs() {
  mkdir -p "$NH_CACHE_DIR" "$NH_LOG_DIR" "$NH_REPORT_DIR"
}

safe_timestamp() { date '+%Y%m%d-%H%M%S'; }
