#!/data/data/com.termux/files/usr/bin/bash
# AI Defensive Executor
# مدقق أمني دفاعي منخفض التأثير للأنظمة التي تملكها أو لديك تصريح مكتوب لفحصها.
# لا يتضمن استغلالًا، تخمين كلمات مرور، استخراج بيانات، أو إنشاء ملفات خبيثة.

set -Eeuo pipefail
IFS=$'\n\t'

export PATH="$HOME/go/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:/data/data/com.termux/files/usr/bin:$PATH"

PROGRAM_NAME="$(basename "$0")"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
OUTPUT_ROOT="${OUTPUT_ROOT:-$PWD/defensive-results}"
RUN_DIR="$OUTPUT_ROOT/$RUN_ID"
LOG_FILE="$RUN_DIR/execution.log"
MODE="all"
TARGET=""
AUTHORIZED=0
INSTALL_MISSING=0

mkdir -p "$RUN_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

usage() {
    cat <<USAGE
الاستخدام:
  $PROGRAM_NAME --target example.com --mode all --authorized

الخيارات:
  --target TARGET       نطاق أو عنوان IP مصرح بفحصه.
  --mode MODE           inventory | passive | web | network | all
  --authorized          تأكيد أن الهدف مملوك لك أو لديك تصريح مكتوب لفحصه.
  --install-missing     تثبيت الأدوات الدفاعية المفقودة فقط.
  --output DIR          مجلد حفظ النتائج.
  -h, --help            عرض المساعدة.

أمثلة:
  $PROGRAM_NAME --target example.com --mode passive --authorized
  $PROGRAM_NAME --target 192.0.2.10 --mode network --authorized
USAGE
}

while (($#)); do
    case "$1" in
        --target)
            TARGET="${2:-}"
            shift 2
            ;;
        --mode)
            MODE="${2:-}"
            shift 2
            ;;
        --authorized)
            AUTHORIZED=1
            shift
            ;;
        --install-missing)
            INSTALL_MISSING=1
            shift
            ;;
        --output)
            OUTPUT_ROOT="${2:-}"
            RUN_DIR="$OUTPUT_ROOT/$RUN_ID"
            LOG_FILE="$RUN_DIR/execution.log"
            mkdir -p "$RUN_DIR"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "خيار غير معروف: $1" >&2
            usage
            exit 2
            ;;
    esac
done

validate_target() {
    local value="$1"

    [[ -n "$value" ]] || return 1
    [[ "$value" != *"://"* ]] || return 1
    [[ "$value" != *"/"* ]] || return 1
    [[ "$value" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,63}$ ]] && return 0
    [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && return 0
    [[ "$value" =~ ^[0-9A-Fa-f:]+$ ]] && return 0

    return 1
}

if [[ "$AUTHORIZED" -ne 1 ]]; then
    echo "تم الإيقاف: يجب إضافة --authorized بعد التأكد من وجود تصريح قانوني." >&2
    exit 3
fi

if ! validate_target "$TARGET"; then
    echo "الهدف غير صالح. استخدم اسم نطاق أو عنوان IP فقط، بدون http:// أو مسار." >&2
    exit 4
fi

case "$MODE" in
    inventory|passive|web|network|all) ;;
    *)
        echo "وضع غير صالح: $MODE" >&2
        usage
        exit 5
        ;;
esac

is_termux() {
    [[ -n "${PREFIX:-}" && "$PREFIX" == *"com.termux"* ]]
}

install_packages() {
    local packages=(curl openssl-tool dnsutils whois nmap whatweb wafw00f sslscan jq coreutils)

    if is_termux; then
        log "تثبيت الأدوات الدفاعية المتاحة من Termux."
        pkg update -y
        for package in "${packages[@]}"; do
            pkg install -y "$package" || log "تحذير: تعذر تثبيت $package من Termux."
        done
    elif command -v apt-get >/dev/null 2>&1; then
        log "تثبيت الأدوات الدفاعية المتاحة من APT."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends \
            curl openssl dnsutils whois nmap whatweb wafw00f sslscan jq coreutils
    else
        log "لا يوجد مدير حزم مدعوم. ثبّت الأدوات يدويًا."
    fi
}

if [[ "$INSTALL_MISSING" -eq 1 ]]; then
    install_packages
fi

TOOLS=(curl openssl dig whois nmap whatweb wafw00f sslscan jq timeout)

inventory() {
    local installed=0
    local missing=0
    local report="$RUN_DIR/tool-inventory.txt"

    : > "$report"
    log "جرد الأدوات."

    for tool in "${TOOLS[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf '%-12s OK      %s\n' "$tool" "$(command -v "$tool")" | tee -a "$report"
            installed=$((installed + 1))
        else
            printf '%-12s MISSING\n' "$tool" | tee -a "$report"
            missing=$((missing + 1))
        fi
    done

    printf '\nINSTALLED=%d\nMISSING=%d\n' "$installed" "$missing" | tee -a "$report"
}

run_command() {
    local name="$1"
    shift

    local output="$RUN_DIR/$name"
    log "تشغيل: $name"

    if "$@" > "$output" 2>&1; then
        log "نجح: $name"
    else
        local rc=$?
        log "تحذير: $name انتهى بالرمز $rc. راجع $output"
    fi
}

passive_checks() {
    log "بدء الفحوص العامة منخفضة التأثير."

    command -v dig >/dev/null 2>&1 && \
        run_command "dns-records.txt" timeout 60 dig "$TARGET" A AAAA MX NS TXT

    command -v whois >/dev/null 2>&1 && \
        run_command "whois.txt" timeout 90 whois "$TARGET"

    if command -v curl >/dev/null 2>&1; then
        run_command "http-headers.txt" timeout 60 curl \
            --silent --show-error --location --max-redirs 3 \
            --connect-timeout 15 --max-time 45 \
            --head "https://$TARGET/"
    fi

    if command -v openssl >/dev/null 2>&1; then
        run_command "tls-certificate.txt" bash -c \
            "timeout 45 openssl s_client -connect '$TARGET:443' -servername '$TARGET' -showcerts </dev/null"
    fi
}

web_checks() {
    log "بدء فحوص تعريف تقنيات الويب منخفضة الشدة."

    command -v whatweb >/dev/null 2>&1 && \
        run_command "whatweb.txt" timeout 120 whatweb \
            --aggression 1 --max-threads 2 "https://$TARGET/"

    command -v wafw00f >/dev/null 2>&1 && \
        run_command "wafw00f.txt" timeout 120 wafw00f "https://$TARGET/"

    command -v sslscan >/dev/null 2>&1 && \
        run_command "sslscan.txt" timeout 180 sslscan \
            --no-colour --show-certificate "$TARGET:443"
}

network_checks() {
    log "بدء فحص اتصال TCP محدود ومنخفض المعدل."

    if command -v nmap >/dev/null 2>&1; then
        run_command "nmap-top-ports.txt" timeout 900 nmap \
            -sT -Pn -T3 \
            --top-ports 100 \
            -sV --version-light \
            --max-retries 2 \
            --host-timeout 10m \
            "$TARGET"
    else
        log "nmap غير مثبت؛ تم تجاوز فحص الشبكة."
    fi
}

log "AI Defensive Executor"
log "الوضع: $MODE"
log "الهدف المصرح: $TARGET"
log "مجلد النتائج: $RUN_DIR"

inventory

case "$MODE" in
    inventory)
        ;;
    passive)
        passive_checks
        ;;
    web)
        passive_checks
        web_checks
        ;;
    network)
        network_checks
        ;;
    all)
        passive_checks
        web_checks
        network_checks
        ;;
esac

{
    echo "RUN_ID=$RUN_ID"
    echo "TARGET=$TARGET"
    echo "MODE=$MODE"
    echo "COMPLETED_AT=$(date --iso-8601=seconds 2>/dev/null || date)"
    echo "RESULT_DIRECTORY=$RUN_DIR"
} > "$RUN_DIR/summary.txt"

log "اكتملت الفحوص الدفاعية."
log "الملخص: $RUN_DIR/summary.txt"
log "السجل: $LOG_FILE"
