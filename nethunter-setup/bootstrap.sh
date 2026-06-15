#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

ensure_termux
prepare_dirs

pattern='raw.githubusercontent.com/ly5851575-oss/termux-apt-repo'
mapfile -t source_files < <(grep -RIl "$pattern" "$PREFIX/etc/apt" 2>/dev/null || true)
if ((${#source_files[@]})); then
  stamp="$(safe_timestamp)"
  warn "تم العثور على مصدر APT قديم يعيد خطأ 404؛ سيتم تعطيله."
  for source_file in "${source_files[@]}"; do
    mv -- "$source_file" "$source_file.disabled.$stamp"
    log "عُطّل: $source_file"
  done
fi

exec bash "$SCRIPT_DIR/install.sh" "$@"
