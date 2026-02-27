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

cmd_output="$(
  cd "${TEST_WORK}" && \
  HOME="${TEST_HOME}" "${SCRIPT_DIR}/bcodex" --print-cmd -- --help
)"

assert_contains "${cmd_output}" "--ro-bind / /" "Root mounted read-only"
assert_contains "${cmd_output}" "--bind ${TEST_WORK} ${TEST_WORK}" "PWD mounted writable"
assert_contains "${cmd_output}" "--bind ${TEST_HOME}/.codex ${TEST_HOME}/.codex" ".codex mounted writable"
assert_contains "${cmd_output}" "--tmpfs ${TEST_HOME}/.ssh" ".ssh masked"
assert_contains "${cmd_output}" "--tmpfs ${TEST_HOME}/.config/gcloud" "gcloud config masked"
assert_contains "${cmd_output}" "--ro-bind /dev/null ${TEST_HOME}/.netrc" ".netrc masked"
assert_contains "${cmd_output}" "--ro-bind /dev/null ${TEST_HOME}/.docker/config.json" "docker config masked"
assert_contains "${cmd_output}" "--setenv TMPDIR ${TEST_WORK}/.bcodex/tmp" "TMPDIR constrained to workspace"
assert_contains "${cmd_output}" "codex --yolo --help" "codex is invoked with --yolo"

if command -v codex >/dev/null 2>&1; then
  pass "codex is available (runtime smoke skipped to avoid interactive launch)"
else
  echo "INFO: codex not found; runtime smoke skipped"
fi

echo "All smoke tests passed."
