#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# smoke-test.sh — Agents SAK Smoke Tests
# ─────────────────────────────────────────────────────────────
# Offline tests. Mock journal in tmpdir. ~40-50 assertions.
#
# Usage: tests/smoke-test.sh
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Test helpers ────────────────────────────────────────────

assert_eq() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" = "$actual" ]; then
    echo -e "  ${GREEN}[PASS]${NC} $desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "  ${RED}[FAIL]${NC} $desc"
    echo -e "         expected: ${CYAN}$expected${NC}"
    echo -e "         actual:   ${RED}$actual${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_ok() {
  local desc="$1"
  shift
  TESTS_RUN=$((TESTS_RUN + 1))

  if "$@" &>/dev/null; then
    echo -e "  ${GREEN}[PASS]${NC} $desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "  ${RED}[FAIL]${NC} $desc (exit code: $?)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_fail() {
  local desc="$1"
  shift
  TESTS_RUN=$((TESTS_RUN + 1))

  if "$@" &>/dev/null; then
    echo -e "  ${RED}[FAIL]${NC} $desc (expected failure, got success)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    echo -e "  ${GREEN}[PASS]${NC} $desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

assert_contains() {
  local desc="$1"
  local needle="$2"
  local haystack="$3"
  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -q "$needle"; then
    echo -e "  ${GREEN}[PASS]${NC} $desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "  ${RED}[FAIL]${NC} $desc"
    echo -e "         expected to contain: ${CYAN}$needle${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

section() {
  echo -e "\n${BOLD}═══ $* ═══${NC}"
}

# ─── Setup mock journal ─────────────────────────────────────

MOCK_JOURNAL=""

setup_mock_journal() {
  MOCK_JOURNAL="$(mktemp -d)"
  local ctr="CTR-test-project-20260304"

  # Create structure
  mkdir -p "$MOCK_JOURNAL/bundles/2026/03"
  mkdir -p "$MOCK_JOURNAL/ledger/2026/03"
  mkdir -p "$MOCK_JOURNAL/audit/$ctr"

  # Create a mock bundle manifest
  local bundle_dir="$MOCK_JOURNAL/bundles/2026/03/bundle-20260304T120000Z-ctr-test-project-20260304"
  mkdir -p "$bundle_dir"
  cat > "$bundle_dir/bundle-manifest.json" <<'MANIFEST'
{
  "protocol_version": "1.0",
  "bundle_id": "bundle-20260304T120000Z-ctr-test-project-20260304",
  "contract_id": "CTR-test-project-20260304",
  "generated_at": "2026-03-04T12:00:00Z",
  "format": "canonical",
  "artifacts": [
    {
      "path": "README.md",
      "sha256": "abc123def456789abc123def456789abc123def456789abc123def456789abcd",
      "size_bytes": 1024
    }
  ],
  "bundle_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "previous_bundle_sha256": null,
  "sources": {},
  "redaction": {}
}
MANIFEST

  # Create mock ledger entry
  cat > "$MOCK_JOURNAL/ledger/2026/03/entries.jsonl" <<'LEDGER'
{"protocol_version":"1.0","entry_id":"ledger-20260304120000-CTR-test-project-20260304","recorded_at":"2026-03-04T12:00:00Z","repository":"sentinels-hub/test-project","contract_id":"CTR-test-project-20260304","bundle_manifest_path":"bundles/2026/03/bundle-20260304T120000Z-ctr-test-project-20260304/bundle-manifest.json","bundle_sha256":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","previous_bundle_sha256":null}
LEDGER

  # Create mock audit trail with entries for G0, G1
  cat > "$MOCK_JOURNAL/audit/$ctr/audit-trail.jsonl" <<'AUDIT'
{"timestamp":"2026-03-04T10:00:00Z","contract_id":"CTR-test-project-20260304","gate":"G0","agent":"@jarvis","action":"control_verified","controls":["traceability","process_standardization"],"evidence_ref":"Contract CTR-test-project-20260304","result":"PASS"}
{"timestamp":"2026-03-04T10:30:00Z","contract_id":"CTR-test-project-20260304","gate":"G1","agent":"@jarvis","action":"control_verified","controls":["SEN-001","least_privilege","access_control","soc2_cc6"],"evidence_ref":"Identity mapping","result":"PASS"}
{"timestamp":"2026-03-04T11:00:00Z","contract_id":"CTR-test-project-20260304","gate":"G2","agent":"@inception","action":"control_verified","controls":["SEN-002","change_control","risk_management","evidence_based_decisions","soc2_cc8"],"evidence_ref":"WP planning","result":"PASS"}
AUDIT
}

cleanup_mock_journal() {
  if [ -n "$MOCK_JOURNAL" ] && [ -d "$MOCK_JOURNAL" ]; then
    rm -rf "$MOCK_JOURNAL"
  fi
}

trap cleanup_mock_journal EXIT

# ─── Test: sak-core.sh ──────────────────────────────────────

test_sak_core() {
  section "sak-core.sh"
  source "$SAK_ROOT/tools/scripts/sak-core.sh"

  # Timestamps
  local ts
  ts="$(iso_timestamp)"
  assert_contains "iso_timestamp format" "T" "$ts"
  assert_contains "iso_timestamp ends with Z" "Z" "$ts"

  ts="$(compact_timestamp)"
  assert_contains "compact_timestamp has T" "T" "$ts"

  ts="$(numeric_timestamp)"
  assert_eq "numeric_timestamp is 14 chars" "14" "${#ts}"

  # Contract ID validation
  assert_ok "valid contract ID" contract_id_validate "CTR-test-project-20260304"
  assert_fail "invalid contract ID (no CTR prefix)" contract_id_validate "XXX-test-20260304"
  assert_fail "invalid contract ID (no date)" contract_id_validate "CTR-test-project"
  assert_fail "invalid contract ID (short date)" contract_id_validate "CTR-test-2026"

  # Journal path resolution
  assert_ok "journal_path_resolve with valid dir" journal_path_resolve "$MOCK_JOURNAL"
  assert_fail "journal_path_resolve with missing dir" journal_path_resolve "/nonexistent/path"

  # sak_root detection
  local root
  root="$(sak_root "$SAK_ROOT/tools/scripts")"
  assert_eq "sak_root detects repo root" "$SAK_ROOT" "$root"
}

# ─── Test: gh-core.sh ───────────────────────────────────────

test_gh_core() {
  section "gh-core.sh"
  source "$SAK_ROOT/tools/github/scripts/gh-core.sh"

  # Branch validation
  assert_ok "valid branch name" validate_branch_name "feat/wp-1897-oauth2-provider"
  assert_ok "valid branch (fix)" validate_branch_name "fix/wp-42-login-bug"
  assert_ok "valid branch (chore)" validate_branch_name "chore/wp-100-cleanup"
  assert_fail "invalid branch (no wp)" validate_branch_name "feat/oauth-provider"
  assert_fail "invalid branch (uppercase)" validate_branch_name "feat/wp-1-UPPERCASE"

  # WP ID extraction
  local wp_id
  wp_id="$(wp_id_from_branch "feat/wp-1897-oauth2-provider")"
  assert_eq "wp_id_from_branch" "1897" "$wp_id"

  # Build branch name
  local branch
  branch="$(build_branch_name "feat" "1897" "OAuth2 Provider")"
  assert_eq "build_branch_name" "feat/wp-1897-oauth2-provider" "$branch"

  # Commit message validation
  assert_ok "valid commit message" validate_commit_message "feat(auth): add OAuth2 provider [WP#1897]"
  assert_ok "valid commit (no scope)" validate_commit_message "fix: resolve login bug [WP#42]"
  assert_fail "invalid commit (no WP)" validate_commit_message "feat: add feature"
  assert_fail "invalid commit (bad type)" validate_commit_message "feature: add something [WP#1]"
}

# ─── Test: ev-core.sh ───────────────────────────────────────

test_ev_core() {
  section "ev-core.sh"

  # Re-source to get ev functions fresh (unset guard first)
  unset _SAK_CORE_LOADED 2>/dev/null || true
  source "$SAK_ROOT/tools/evidence/scripts/ev-core.sh"

  # SHA-256 of string
  local hash
  hash="$(sha256_string "hello")"
  assert_eq "sha256_string('hello')" "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" "$hash"

  # Bundle ID generation
  local bundle_id
  bundle_id="$(generate_bundle_id "CTR-test-20260304")"
  assert_contains "bundle_id starts with bundle-" "bundle-" "$bundle_id"
  assert_contains "bundle_id contains contract" "ctr-test-20260304" "$bundle_id"

  # Ledger entry ID
  local entry_id
  entry_id="$(generate_ledger_entry_id "CTR-test-20260304")"
  assert_contains "ledger_entry_id starts with ledger-" "ledger-" "$entry_id"

  # Manifest validation
  assert_ok "validate_manifest with valid manifest" validate_manifest "$MOCK_JOURNAL/bundles/2026/03/bundle-20260304T120000Z-ctr-test-project-20260304/bundle-manifest.json"

  # Ledger operations
  local count
  count="$(ledger_count "$MOCK_JOURNAL")"
  assert_eq "ledger_count" "1" "$count"

  local last_hash
  last_hash="$(ledger_last_hash "$MOCK_JOURNAL")"
  assert_eq "ledger_last_hash" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "$last_hash"
}

# ─── Test: co-core.sh ───────────────────────────────────────

test_co_core() {
  section "co-core.sh"

  unset _SAK_CORE_LOADED 2>/dev/null || true
  source "$SAK_ROOT/tools/compliance/scripts/co-core.sh"

  local ctr="CTR-test-project-20260304"

  # Audit entry ID
  local entry_id
  entry_id="$(generate_audit_entry_id "$ctr")"
  assert_contains "audit_entry_id starts with audit-" "audit-" "$entry_id"

  # Audit trail path
  local trail_path
  trail_path="$(audit_trail_path "$MOCK_JOURNAL" "$ctr")"
  assert_contains "audit_trail_path contains contract" "$ctr" "$trail_path"

  # Audit trail count
  local count
  count="$(audit_trail_count "$MOCK_JOURNAL" "$ctr")"
  assert_eq "audit_trail_count" "3" "$count"

  # Validate audit entry
  local valid_entry='{"timestamp":"2026-03-04T10:00:00Z","contract_id":"CTR-test-20260304","gate":"G0","agent":"@jarvis","action":"control_verified","controls":["traceability"],"evidence_ref":"test","result":"PASS"}'
  assert_ok "validate_audit_entry valid" validate_audit_entry "$valid_entry"

  local invalid_entry='{"timestamp":"2026-03-04T10:00:00Z","contract_id":"CTR-test-20260304","gate":"G0","agent":"@jarvis","action":"invalid_action","controls":["traceability"],"evidence_ref":"test","result":"PASS"}'
  assert_fail "validate_audit_entry invalid action" validate_audit_entry "$invalid_entry"

  # Control registry
  local registry
  registry="$(control_registry)"
  local ctrl_count
  ctrl_count="$(echo "$registry" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"
  assert_eq "control_registry has 24 controls" "24" "$ctrl_count"

  # Control get
  local ctrl
  ctrl="$(control_get "SEN-001")"
  assert_contains "control_get SEN-001" "Identity verification" "$ctrl"

  # Controls by framework
  local sentinels
  sentinels="$(controls_by_framework "sentinels")"
  local sen_count
  sen_count="$(echo "$sentinels" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"
  assert_eq "controls_by_framework sentinels" "10" "$sen_count"

  # Compliance score
  local score
  score="$(compliance_score "$MOCK_JOURNAL" "$ctr")"
  assert_contains "compliance_score has contract_id" "$ctr" "$score"
  assert_contains "compliance_score has frameworks" "frameworks" "$score"
}

# ─── Test: sak-trace.sh ─────────────────────────────────────

test_sak_trace() {
  section "sak-trace.sh"
  local ctr="CTR-test-project-20260304"

  local output
  output="$(bash "$SAK_ROOT/tools/scripts/sak-trace.sh" "$ctr" --journal-path "$MOCK_JOURNAL" 2>&1 || true)"

  assert_contains "trace shows contract" "Contract Format" "$output"
  assert_contains "trace shows audit trail" "Audit Trail" "$output"
  assert_contains "trace shows bundles" "Evidence Bundles" "$output"
  assert_contains "trace shows ledger" "Ledger Chain" "$output"
  assert_contains "trace shows summary" "TRACEABILITY SUMMARY" "$output"
}

# ─── Test: sak-gates.sh ─────────────────────────────────────

test_sak_gates() {
  section "sak-gates.sh"
  local ctr="CTR-test-project-20260304"

  # Status command
  local output
  output="$(bash "$SAK_ROOT/tools/scripts/sak-gates.sh" status "$ctr" --journal-path "$MOCK_JOURNAL" 2>&1 || true)"

  assert_contains "gates status shows table" "Gate Status" "$output"
  assert_contains "gates status shows G0" "G0" "$output"
  assert_contains "gates status shows G9" "G9" "$output"
  assert_contains "gates status shows PASS" "PASS" "$output"

  # Next command
  output="$(bash "$SAK_ROOT/tools/scripts/sak-gates.sh" next "$ctr" --journal-path "$MOCK_JOURNAL" 2>&1 || true)"
  assert_contains "gates next suggests G3 (first without PASS)" "G3" "$output"

  # Check-ready for G3
  output="$(bash "$SAK_ROOT/tools/scripts/sak-gates.sh" check-ready "$ctr" G3 --journal-path "$MOCK_JOURNAL" 2>&1 || true)"
  assert_contains "check-ready G3 checks G2" "G2" "$output"
}

# ─── Test: sak-metrics.sh ───────────────────────────────────

test_sak_metrics() {
  section "sak-metrics.sh"
  local ctr="CTR-test-project-20260304"

  # Summary command
  local output
  output="$(bash "$SAK_ROOT/tools/scripts/sak-metrics.sh" summary "$ctr" --journal-path "$MOCK_JOURNAL" 2>&1 || true)"

  assert_contains "metrics shows title" "SAK Metrics" "$output"
  assert_contains "metrics shows control coverage" "Control coverage" "$output"
  assert_contains "metrics shows gate pass rate" "Gate pass rate" "$output"
  assert_contains "metrics shows chain" "Chain completeness" "$output"
  assert_contains "metrics shows JSON" "contract_id" "$output"

  # Gaps command
  output="$(bash "$SAK_ROOT/tools/scripts/sak-metrics.sh" gaps "$ctr" --journal-path "$MOCK_JOURNAL" 2>&1 || true)"
  assert_contains "gaps shows gate gaps" "Gate Gaps" "$output"
  assert_contains "gaps shows evidence" "Evidence Gaps" "$output"
}

# ─── Test: sak-cli.sh ───────────────────────────────────────

test_sak_cli() {
  section "sak-cli.sh"

  # Version command
  local output
  output="$(bash "$SAK_ROOT/tools/scripts/sak-cli.sh" version 2>&1)"

  assert_contains "version shows SAK" "Agents SAK" "$output"
  assert_contains "version shows tools" "openproject" "$output"
  assert_contains "version shows cross-tool" "trace" "$output"

  # Help
  output="$(bash "$SAK_ROOT/tools/scripts/sak-cli.sh" --help 2>&1)"
  assert_contains "help shows usage" "Usage" "$output"

  # Status command
  output="$(bash "$SAK_ROOT/tools/scripts/sak-cli.sh" status "CTR-test-project-20260304" --journal-path "$MOCK_JOURNAL" 2>&1 || true)"
  assert_contains "status shows contract" "Contract" "$output"
}

# ─── Syntax check all scripts ───────────────────────────────

test_syntax() {
  section "Syntax Check"

  local scripts=(
    "tools/scripts/sak-core.sh"
    "tools/scripts/sak-cli.sh"
    "tools/scripts/sak-trace.sh"
    "tools/scripts/sak-gates.sh"
    "tools/scripts/sak-metrics.sh"
    "tools/evidence/scripts/ev-core.sh"
    "tools/evidence/scripts/ev-cli.sh"
    "tools/evidence/scripts/ev-setup.sh"
    "tools/compliance/scripts/co-core.sh"
    "tools/compliance/scripts/co-cli.sh"
    "tools/compliance/scripts/co-setup.sh"
    "tools/github/scripts/gh-core.sh"
    "tools/github/scripts/gh-cli.sh"
  )

  for script in "${scripts[@]}"; do
    local full_path="$SAK_ROOT/$script"
    if [ -f "$full_path" ]; then
      assert_ok "syntax: $script" bash -n "$full_path"
    else
      TESTS_RUN=$((TESTS_RUN + 1))
      echo -e "  ${YELLOW}[SKIP]${NC} $script (not found)"
    fi
  done
}

# ─── Run all tests ───────────────────────────────────────────

main() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   Agents SAK — Smoke Tests                       ║${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"

  setup_mock_journal

  test_syntax
  test_sak_core
  test_gh_core
  test_ev_core
  test_co_core
  test_sak_trace
  test_sak_gates
  test_sak_metrics
  test_sak_cli

  echo ""
  echo -e "${BOLD}═══ RESULTS ═══${NC}"
  echo ""
  echo -e "  Tests run:    ${BOLD}$TESTS_RUN${NC}"
  echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
  echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
  echo ""

  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}ALL TESTS PASSED${NC}"
  else
    echo -e "  ${RED}${BOLD}$TESTS_FAILED TESTS FAILED${NC}"
  fi
  echo ""

  if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
