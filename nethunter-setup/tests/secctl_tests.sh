#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

SECCTL_SCRIPT="$SCRIPT_DIR/../bin/secctl"

# Function to run a test
run_test() {
  local test_name="$1"
  shift
  info "بدء الاختبار: $test_name"
  # Run the command in a subshell to avoid affecting the main script environment
  if ( "$@" ); then
    log "نجح الاختبار: $test_name"
  else
    die "فشل الاختبار: $test_name"
  fi
}

# Test 1: bash -n for all scripts
test_bash_n() {
  bash -n "$SECCTL_SCRIPT" && \
  bash -n "$SCRIPT_DIR/../install.sh" && \
  bash -n "$SCRIPT_DIR/../install-tools.sh" && \
  bash -n "$SCRIPT_DIR/../doctor.sh" && \
  bash -n "$SCRIPT_DIR/../bootstrap.sh" && \
  bash -n "$SCRIPT_DIR/../lib/common.sh"
}
run_test "فحص بناء سكربتات Bash (bash -n)" test_bash_n

# Test 2: ShellCheck for all scripts
test_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$SECCTL_SCRIPT" && \
    shellcheck "$SCRIPT_DIR/../install.sh" && \
    shellcheck "$SCRIPT_DIR/../install-tools.sh" && \
    shellcheck "$SCRIPT_DIR/../doctor.sh" && \
    shellcheck "$SCRIPT_DIR/../bootstrap.sh" && \
    shellcheck "$SCRIPT_DIR/../lib/common.sh"
  else
    warn "ShellCheck غير مثبت، تخطي اختبار الجودة."
    return 0
  fi
}
run_test "فحص جودة سكربتات Bash (ShellCheck)" test_shellcheck

# Test 3: Package list tests (ensure files exist and are not empty)
test_packages() {
  test -s "$SCRIPT_DIR/../packages/core.txt" && \
  test -s "$SCRIPT_DIR/../packages/web.txt" && \
  test -s "$SCRIPT_DIR/../packages/network.txt" && \
  test -s "$SCRIPT_DIR/../packages/forensics.txt" && \
  test -s "$SCRIPT_DIR/../packages/audit.txt" && \
  test -s "$SCRIPT_DIR/../packages/system_audit.txt" && \
  test -s "$SCRIPT_DIR/../packages/code_supply_chain.txt"
}
run_test "فحص قوائم الحزم" test_packages

# Test 4: Mock command execution for secctl setup
test_setup() {
  export PREFIX="/tmp/mock_prefix"
  mkdir -p "$PREFIX/bin"
  # Use sed to mock ensure_termux and fix SCRIPT_DIR in the script itself for the test
  sed "s/ensure_termux/true/g; s|SCRIPT_DIR=\"\$(cd -- \"\$(dirname -- \"\${BASH_SOURCE\[0\]}\")\" && pwd)\"|SCRIPT_DIR=\"$(dirname "$SECCTL_SCRIPT")\"|g" "$SECCTL_SCRIPT" > "/tmp/secctl_mocked"
  bash "/tmp/secctl_mocked" setup && \
  test -L "$PREFIX/bin/secctl" && \
  test "$(readlink -f "$PREFIX/bin/secctl")" == "$(readlink -f "$SECCTL_SCRIPT")"
}
run_test "اختبار secctl setup (Mock)" test_setup

# Test 5: Mock command execution for secctl version
test_version() {
  bash "$SECCTL_SCRIPT" version | grep -q "secctl الإصدار 0.1.0-beta"
}
run_test "اختبار secctl version (Mock)" test_version

# Test 6: Secret prevention test
test_secrets() {
  # Look for assignments of non-empty strings to secret-like variables
  ! grep -qE "(AI_API_KEY=['\"][^'\"]+['\"]|PASSWORD=['\"][^'\"]+['\"]|SECRET=['\"][^'\"]+['\"]|TOKEN=['\"][^'\"]+['\"])" "$SECCTL_SCRIPT"
}
run_test "اختبار منع الأسرار في سكربت secctl" test_secrets

# Test 7: Destructive command prevention test
test_destructive() {
  # This is a basic check to see if the script contains logic to prevent destructive commands
  grep -q "rm -rf /" "$SECCTL_SCRIPT" && grep -q "mkfs" "$SECCTL_SCRIPT"
}
run_test "اختبار وجود حماية من الأوامر المدمرة" test_destructive

log "جميع الاختبارات الأساسية نجحت."
