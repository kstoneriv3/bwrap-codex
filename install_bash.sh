#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/bcodex"
DEST_DIR="${HOME}/.local/bin"
DEST="${DEST_DIR}/bcodex"
RC_FILE="${HOME}/.bashrc"

mkdir -p "${DEST_DIR}"
install -m 0755 "${SRC}" "${DEST}"
touch "${RC_FILE}"

tmp_file="$(mktemp)"
awk '
  BEGIN { skip=0 }
  /^# >>> bcodex >>>$/ { skip=1; next }
  /^# <<< bcodex <<<$/ { skip=0; next }
  skip==0 { print }
' "${RC_FILE}" > "${tmp_file}"

cat >> "${tmp_file}" <<'EOF'
# >>> bcodex >>>
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
alias codex=bcodex
# <<< bcodex <<<
EOF

mv "${tmp_file}" "${RC_FILE}"
echo "Installed bcodex to ${DEST}"
echo "Updated ${RC_FILE} with PATH and alias codex=bcodex"
