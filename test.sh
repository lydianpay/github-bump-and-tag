#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENTRYPOINT="${SCRIPT_DIR}/entrypoint.sh"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

setup_repo() {
  local test_dir="$1"
  local bare_repo="${test_dir}/origin.git"
  local work_repo="${test_dir}/workspace"

  # Isolated HOME so global git config doesn't leak
  export HOME="${test_dir}/fakehome"
  mkdir -p "$HOME"

  git init --bare "$bare_repo" > /dev/null 2>&1
  git clone "$bare_repo" "$work_repo" > /dev/null 2>&1

  cd "$work_repo"
  git config user.email "test@test.com"
  git config user.name "Test"
  git commit --allow-empty -m "initial" > /dev/null 2>&1
  git push origin main > /dev/null 2>&1

  export GITHUB_OUTPUT="${test_dir}/output"
  touch "$GITHUB_OUTPUT"
  export INPUT_TOKEN="fake-token"
}

get_output() {
  local key="$1"
  grep "^${key}=" "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2-
}

run_test() {
  local name="$1"
  local expected_current="$2"
  local expected_new="$3"
  local expected_exit="${4:-0}"

  local actual_exit=0
  bash "$ENTRYPOINT" > /dev/null 2>&1 || actual_exit=$?

  if [[ "$expected_exit" -ne 0 ]]; then
    if [[ "$actual_exit" -ne 0 ]]; then
      echo -e "  ${GREEN}PASS${NC}: ${name}"
      PASS=$((PASS + 1))
    else
      echo -e "  ${RED}FAIL${NC}: ${name} — expected non-zero exit, got 0"
      FAIL=$((FAIL + 1))
    fi
    return
  fi

  if [[ "$actual_exit" -ne 0 ]]; then
    echo -e "  ${RED}FAIL${NC}: ${name} — script exited with ${actual_exit}"
    FAIL=$((FAIL + 1))
    return
  fi

  local actual_current actual_new
  actual_current="$(get_output currentVersion)"
  actual_new="$(get_output newVersion)"

  local failed=0
  if [[ "$actual_current" != "$expected_current" ]]; then
    echo -e "  ${RED}FAIL${NC}: ${name} — currentVersion: expected '${expected_current}', got '${actual_current}'"
    failed=1
  fi
  if [[ "$actual_new" != "$expected_new" ]]; then
    echo -e "  ${RED}FAIL${NC}: ${name} — newVersion: expected '${expected_new}', got '${actual_new}'"
    failed=1
  fi

  if [[ "$failed" -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${NC}: ${name}"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
}

# ─── Tests ───

echo "Running tests..."

# Test 1: No existing tags — defaults to v0.0.1, bumps to v0.0.2
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
run_test "no existing tags" "v0.0.1" "v0.0.2"
rm -rf "$TEST_DIR"

# Test 2: Patch bump (default)
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
git tag v1.2.3
git push origin v1.2.3 > /dev/null 2>&1
unset INPUT_BUMP
run_test "patch bump (default)" "v1.2.3" "v1.2.4"
rm -rf "$TEST_DIR"

# Test 3: Minor bump
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
git tag v1.2.3
git push origin v1.2.3 > /dev/null 2>&1
export INPUT_BUMP=minor
run_test "minor bump" "v1.2.3" "v1.3.0"
rm -rf "$TEST_DIR"

# Test 4: Major bump
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
git tag v1.2.3
git push origin v1.2.3 > /dev/null 2>&1
export INPUT_BUMP=major
run_test "major bump" "v1.2.3" "v2.0.0"
rm -rf "$TEST_DIR"

# Test 5: No v prefix preserved
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
git tag 1.2.3
git push origin 1.2.3 > /dev/null 2>&1
unset INPUT_BUMP
run_test "no v prefix preserved" "1.2.3" "1.2.4"
rm -rf "$TEST_DIR"

# Test 6: Major bump preserves v prefix
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
git tag v3.5.9
git push origin v3.5.9 > /dev/null 2>&1
export INPUT_BUMP=major
run_test "major bump preserves v prefix" "v3.5.9" "v4.0.0"
rm -rf "$TEST_DIR"

# Test 7: Major bump without v prefix
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
git tag 3.5.9
git push origin 3.5.9 > /dev/null 2>&1
export INPUT_BUMP=major
run_test "major bump without v prefix" "3.5.9" "4.0.0"
rm -rf "$TEST_DIR"

# Test 8: Multiple tags picks highest
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
git tag v1.0.0 && git push origin v1.0.0 > /dev/null 2>&1
git tag v2.0.0 && git push origin v2.0.0 > /dev/null 2>&1
git tag v1.5.0 && git push origin v1.5.0 > /dev/null 2>&1
unset INPUT_BUMP
run_test "multiple tags picks highest" "v2.0.0" "v2.0.1"
rm -rf "$TEST_DIR"

# Test 9: Invalid bump type
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
git tag v1.0.0 && git push origin v1.0.0 > /dev/null 2>&1
export INPUT_BUMP=foo
run_test "invalid bump type exits non-zero" "" "" 1
rm -rf "$TEST_DIR"

# Test 10: Missing token (unset)
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
unset INPUT_TOKEN
unset INPUT_BUMP
run_test "missing token exits non-zero" "" "" 1
rm -rf "$TEST_DIR"

# Test 11: Empty token
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
export INPUT_TOKEN=""
unset INPUT_BUMP
run_test "empty token exits non-zero" "" "" 1
rm -rf "$TEST_DIR"

# Test 12: Pre-release tags ignored
TEST_DIR="$(mktemp -d)"
setup_repo "$TEST_DIR"
git tag v1.0.0 && git push origin v1.0.0 > /dev/null 2>&1
git tag v2.0.0-beta.1 && git push origin v2.0.0-beta.1 > /dev/null 2>&1
unset INPUT_BUMP
export INPUT_TOKEN="fake-token"
run_test "pre-release tags ignored" "v1.0.0" "v1.0.1"
rm -rf "$TEST_DIR"

# ─── Summary ───

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
