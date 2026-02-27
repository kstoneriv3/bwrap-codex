#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "${needle}" <<<"${haystack}"; then
    pass "${label}"
  else
    fail "${label} (missing: ${needle})"
  fi
}

for f in "${SCRIPT_DIR}/bcodex" "${SCRIPT_DIR}/install_bash.sh" "${SCRIPT_DIR}/install_zsh.sh" "${SCRIPT_DIR}/install_fish.sh" "${SCRIPT_DIR}/run_test.sh"; do
  bash -n "${f}" || fail "Syntax check failed for ${f}"
done
pass "Shell syntax checks"

command -v bwrap >/dev/null 2>&1 || fail "bwrap not found in PATH"
pass "bwrap is available"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

TEST_HOME="${TMP_ROOT}/home"
TEST_WORK="${TMP_ROOT}/work"
mkdir -p "${TEST_HOME}/.codex" "${TEST_HOME}/.ssh" "${TEST_HOME}/.docker" "${TEST_HOME}/.config/gcloud" "${TEST_WORK}"
touch "${TEST_HOME}/.netrc" "${TEST_HOME}/.docker/config.json"
TEST_SESSION_ID="test-session-123"

cmd_output="$(
  cd "${TEST_WORK}" && \
  HOME="${TEST_HOME}" BCODEX_SESSION_ID="${TEST_SESSION_ID}" "${SCRIPT_DIR}/bcodex" --print-cmd -- --help
)"

assert_contains "${cmd_output}" "--ro-bind / /" "Root mounted read-only"
assert_contains "${cmd_output}" "--bind ${TEST_WORK} ${TEST_WORK}" "PWD mounted writable"
assert_contains "${cmd_output}" "--bind ${TEST_HOME}/.codex ${TEST_HOME}/.codex" ".codex mounted writable"
assert_contains "${cmd_output}" "--bind /tmp/bcodex/${TEST_SESSION_ID} /tmp/bcodex/${TEST_SESSION_ID}" "Session tmpdir mounted writable"
assert_contains "${cmd_output}" "--tmpfs ${TEST_HOME}/.ssh" ".ssh masked"
assert_contains "${cmd_output}" "--tmpfs ${TEST_HOME}/.config/gcloud" "gcloud config masked"
assert_contains "${cmd_output}" "--ro-bind /dev/null ${TEST_HOME}/.netrc" ".netrc masked"
assert_contains "${cmd_output}" "--ro-bind /dev/null ${TEST_HOME}/.docker/config.json" "docker config masked"
assert_contains "${cmd_output}" "--setenv BWRAP_CODEX 1" "BWRAP_CODEX marker set"
assert_contains "${cmd_output}" "--setenv BCODEX_SESSION_ID ${TEST_SESSION_ID}" "BCODEX_SESSION_ID set"
assert_contains "${cmd_output}" "--setenv BCODEX_TMPDIR /tmp/bcodex/${TEST_SESSION_ID}" "BCODEX_TMPDIR set"
assert_contains "${cmd_output}" "--setenv TMPDIR /tmp/bcodex/${TEST_SESSION_ID}" "TMPDIR set to session tmpdir"
assert_contains "${cmd_output}" "codex --yolo --help" "codex is invoked with --yolo"

if command -v codex >/dev/null 2>&1; then
  pass "codex is available (runtime smoke skipped to avoid interactive launch)"
else
  echo "INFO: codex not found; runtime smoke skipped"
fi

INSTALL_HOME="${TMP_ROOT}/install-home"
mkdir -p "${INSTALL_HOME}"
for installer in "install_bash.sh" "install_zsh.sh" "install_fish.sh"; do
  HOME="${INSTALL_HOME}" "${SCRIPT_DIR}/${installer}" >/dev/null
done
if [[ -e "${INSTALL_HOME}/.codex/AGENTS.md" ]]; then
  fail "AGENTS.md should not be created without -a"
else
  pass "Installers do not modify AGENTS.md by default"
fi

for installer in "install_bash.sh" "install_zsh.sh" "install_fish.sh"; do
  HOME="${INSTALL_HOME}" "${SCRIPT_DIR}/${installer}" -a >/dev/null
done
AGENTS_FILE="${INSTALL_HOME}/.codex/AGENTS.md"
if [[ ! -f "${AGENTS_FILE}" ]]; then
  fail "AGENTS.md should exist after installer -a"
fi

start_count="$(grep -Fc "<!-- >>> bcodex-awareness >>> -->" "${AGENTS_FILE}")"
end_count="$(grep -Fc "<!-- <<< bcodex-awareness <<< -->" "${AGENTS_FILE}")"
if [[ "${start_count}" -ne 1 || "${end_count}" -ne 1 ]]; then
  fail "AGENTS.md should contain exactly one managed awareness block after -a"
fi
pass "Installers add awareness block with -a"

for installer in "install_bash.sh" "install_zsh.sh" "install_fish.sh"; do
  HOME="${INSTALL_HOME}" "${SCRIPT_DIR}/${installer}" -a >/dev/null
done
start_count="$(grep -Fc "<!-- >>> bcodex-awareness >>> -->" "${AGENTS_FILE}")"
end_count="$(grep -Fc "<!-- <<< bcodex-awareness <<< -->" "${AGENTS_FILE}")"
if [[ "${start_count}" -ne 1 || "${end_count}" -ne 1 ]]; then
  fail "AGENTS.md block should remain idempotent across repeated -a runs"
fi
pass "Installer awareness block is idempotent"

echo "All smoke tests passed."
