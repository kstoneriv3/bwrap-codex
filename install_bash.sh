#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/bcodex"
DEST_DIR="${HOME}/.local/bin"
DEST="${DEST_DIR}/bcodex"
RC_FILE="${HOME}/.bashrc"
APPEND_PROMPT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--append-prompt-to-default-agents-md)
      APPEND_PROMPT=1
      shift
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 2
      ;;
  esac
done

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

if [[ "${APPEND_PROMPT}" -eq 1 ]]; then
  CODEX_DIR="${HOME}/.codex"
  AGENTS_FILE="${CODEX_DIR}/AGENTS.md"
  mkdir -p "${CODEX_DIR}"
  touch "${AGENTS_FILE}"

  agents_tmp="$(mktemp)"
  awk '
    BEGIN { skip=0 }
    /^<!-- >>> bcodex-awareness >>> -->$/ { skip=1; next }
    /^<!-- <<< bcodex-awareness <<< -->$/ { skip=0; next }
    skip==0 { print }
  ' "${AGENTS_FILE}" > "${agents_tmp}"

  cat >> "${agents_tmp}" <<'EOF'
<!-- >>> bcodex-awareness >>> -->
When BWRAP_CODEX=1, this Codex session is running inside the bcodex bubblewrap sandbox.
Use BCODEX_SESSION_ID and BCODEX_TMPDIR to understand per-session temp context.
Do not assume host-private files are accessible.
<!-- <<< bcodex-awareness <<< -->
EOF

  mv "${agents_tmp}" "${AGENTS_FILE}"
  echo "Updated ${AGENTS_FILE} with bcodex awareness prompt"
fi

echo "Installed bcodex to ${DEST}"
echo "Updated ${RC_FILE} with PATH and alias codex=bcodex"
