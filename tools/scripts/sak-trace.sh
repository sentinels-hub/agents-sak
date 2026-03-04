#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# sak-trace.sh — E2E Traceability Verification
# ─────────────────────────────────────────────────────────────
# Verifica la cadena completa:
#   Contract → WP → Branch → Commits → PR → Bundle → Ledger → Audit
#
# Checks que necesitan API (OP, GitHub) → [SKIP] sin error.
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sak-core.sh"

# Source tool cores
EV_CORE="$SCRIPT_DIR/../evidence/scripts/ev-core.sh"
CO_CORE="$SCRIPT_DIR/../compliance/scripts/co-core.sh"
GH_CORE="$SCRIPT_DIR/../github/scripts/gh-core.sh"

[ -f "$EV_CORE" ] && source "$EV_CORE"
[ -f "$CO_CORE" ] && source "$CO_CORE"
[ -f "$GH_CORE" ] && source "$GH_CORE"

# Counters
TRACE_OK=0
TRACE_FAIL=0
TRACE_SKIP=0

trace_ok()   { echo -e "  ${GREEN}[OK]${NC}   $*"; TRACE_OK=$((TRACE_OK + 1)); }
trace_fail() { echo -e "  ${RED}[FAIL]${NC} $*"; TRACE_FAIL=$((TRACE_FAIL + 1)); }
trace_skip() { echo -e "  ${YELLOW}[SKIP]${NC} $*"; TRACE_SKIP=$((TRACE_SKIP + 1)); }

# ─── Check functions ──────────────────────────────────────────

check_contract_format() {
  section "1. Contract Format"
  if contract_id_validate "$CONTRACT_ID" 2>/dev/null; then
    trace_ok "Contract ID format: $CONTRACT_ID"
  else
    trace_fail "Contract ID format inválido: $CONTRACT_ID"
  fi
}

check_audit_trail_exists() {
  section "2. Audit Trail"
  if declare -f audit_trail_count &>/dev/null; then
    local count
    count="$(audit_trail_count "$JOURNAL_PATH" "$CONTRACT_ID")"
    if [ "$count" -gt 0 ]; then
      trace_ok "Audit trail: $count entries"
    else
      trace_fail "Audit trail: vacío (0 entries)"
    fi
  else
    trace_skip "co-core.sh no disponible"
  fi
}

check_audit_gates_coverage() {
  section "3. Gates Coverage"
  if ! declare -f audit_trail_entries &>/dev/null; then
    trace_skip "co-core.sh no disponible"
    return
  fi

  local trail_file
  trail_file="$(audit_trail_path "$JOURNAL_PATH" "$CONTRACT_ID")"

  if [ ! -f "$trail_file" ]; then
    trace_fail "Audit trail file no encontrado"
    return
  fi

  local gates_covered
  gates_covered="$(jq -r '.gate' "$trail_file" 2>/dev/null | sort -u)"
  local gate_count
  gate_count="$(echo "$gates_covered" | grep -c '^G' || true)"

  if [ "$gate_count" -ge 10 ]; then
    trace_ok "Gates cubiertos: 10/10 (G0-G9)"
  elif [ "$gate_count" -gt 0 ]; then
    local covered_list
    covered_list="$(echo "$gates_covered" | tr '\n' ' ')"
    trace_fail "Gates cubiertos: $gate_count/10 ($covered_list)"
  else
    trace_fail "Gates cubiertos: 0/10"
  fi

  # Check controls coverage per gate
  if declare -f controls_by_gate &>/dev/null; then
    local verified_controls
    verified_controls="$(jq -r 'select(.action == "control_verified" and .result == "PASS") | .controls[]' "$trail_file" 2>/dev/null | sort -u)"
    local verified_count
    verified_count="$(echo "$verified_controls" | grep -c '^' 2>/dev/null || true)"
    info "Controles verificados (PASS): $verified_count"
  fi
}

check_bundles_exist() {
  section "4. Evidence Bundles"
  if ! declare -f journal_bundle_dir &>/dev/null; then
    trace_skip "ev-core.sh no disponible"
    return
  fi

  if [ ! -d "$JOURNAL_PATH/bundles" ]; then
    trace_fail "Directorio bundles/ no encontrado"
    return
  fi

  local manifests
  manifests="$(find "$JOURNAL_PATH/bundles" -name "bundle-manifest.json" -type f 2>/dev/null)"

  local contract_manifests=""
  local bundle_count=0

  while IFS= read -r manifest; do
    [ -z "$manifest" ] && continue
    if grep -q "\"$CONTRACT_ID\"" "$manifest" 2>/dev/null; then
      contract_manifests="$contract_manifests $manifest"
      bundle_count=$((bundle_count + 1))
    fi
  done <<< "$manifests"

  if [ "$bundle_count" -gt 0 ]; then
    trace_ok "Bundles para $CONTRACT_ID: $bundle_count"
  else
    trace_fail "Bundles para $CONTRACT_ID: 0"
  fi
}

check_bundle_integrity() {
  section "5. Bundle Integrity"
  if ! declare -f compute_bundle_sha256 &>/dev/null || ! declare -f validate_manifest &>/dev/null; then
    trace_skip "ev-core.sh no disponible"
    return
  fi

  if [ ! -d "$JOURNAL_PATH/bundles" ]; then
    trace_skip "No hay bundles"
    return
  fi

  local manifests
  manifests="$(find "$JOURNAL_PATH/bundles" -name "bundle-manifest.json" -type f 2>/dev/null)"

  local checked=0
  local valid=0
  local invalid=0

  while IFS= read -r manifest; do
    [ -z "$manifest" ] && continue
    if ! grep -q "\"$CONTRACT_ID\"" "$manifest" 2>/dev/null; then
      continue
    fi

    checked=$((checked + 1))

    # Validate manifest structure
    if validate_manifest "$manifest" &>/dev/null; then
      # Verify SHA-256
      local expected actual
      expected="$(jq -r '.bundle_sha256' "$manifest")"
      actual="$(compute_bundle_sha256 "$manifest" 2>/dev/null || echo "error")"

      if [ "$expected" = "$actual" ]; then
        valid=$((valid + 1))
      else
        invalid=$((invalid + 1))
      fi
    else
      invalid=$((invalid + 1))
    fi
  done <<< "$manifests"

  if [ "$checked" -eq 0 ]; then
    trace_skip "No hay bundles para este contrato"
  elif [ "$invalid" -eq 0 ]; then
    trace_ok "Bundle integrity: $valid/$checked OK"
  else
    trace_fail "Bundle integrity: $invalid/$checked FAILED"
  fi
}

check_ledger_chain() {
  section "6. Ledger Chain"
  if ! declare -f ledger_all_entries &>/dev/null; then
    trace_skip "ev-core.sh no disponible"
    return
  fi

  local total_entries
  total_entries="$(ledger_count "$JOURNAL_PATH")"

  if [ "$total_entries" -eq 0 ]; then
    trace_skip "Ledger vacío"
    return
  fi

  local line_num=0
  local previous_hash="null"
  local chain_errors=0

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    line_num=$((line_num + 1))

    local entry_prev entry_bundle
    entry_prev="$(echo "$line" | jq -r '.previous_bundle_sha256 // "null"')"
    entry_bundle="$(echo "$line" | jq -r '.bundle_sha256')"

    if [ "$entry_prev" != "$previous_hash" ]; then
      chain_errors=$((chain_errors + 1))
    fi
    previous_hash="$entry_bundle"
  done < <(ledger_all_entries "$JOURNAL_PATH")

  if [ "$chain_errors" -eq 0 ]; then
    trace_ok "Ledger chain: UNBROKEN ($line_num entries)"
  else
    trace_fail "Ledger chain: BROKEN ($chain_errors breaks in $line_num entries)"
  fi
}

check_ledger_links_contract() {
  section "7. Ledger ↔ Contract"
  if ! declare -f ledger_all_entries &>/dev/null; then
    trace_skip "ev-core.sh no disponible"
    return
  fi

  local contract_entries=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if echo "$line" | jq -r '.contract_id' 2>/dev/null | grep -q "^${CONTRACT_ID}$"; then
      contract_entries=$((contract_entries + 1))
    fi
  done < <(ledger_all_entries "$JOURNAL_PATH")

  if [ "$contract_entries" -gt 0 ]; then
    trace_ok "Ledger entries linked to $CONTRACT_ID: $contract_entries"
  else
    trace_fail "No ledger entries linked to $CONTRACT_ID"
  fi
}

check_branch_naming() {
  section "8. Branch Naming"
  if ! declare -f validate_branch_name &>/dev/null; then
    trace_skip "gh-core.sh no disponible"
    return
  fi

  if ! command -v git &>/dev/null || ! git rev-parse --git-dir &>/dev/null 2>&1; then
    trace_skip "No git repo"
    return
  fi

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

  if [ -z "$branch" ] || [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    trace_skip "En branch principal ($branch)"
    return
  fi

  if validate_branch_name "$branch" 2>/dev/null; then
    trace_ok "Branch naming: $branch"
  else
    trace_fail "Branch naming inválido: $branch"
  fi
}

check_commit_format() {
  section "9. Commit Format"
  if ! declare -f validate_commit_message &>/dev/null; then
    trace_skip "gh-core.sh no disponible"
    return
  fi

  if ! command -v git &>/dev/null || ! git rev-parse --git-dir &>/dev/null 2>&1; then
    trace_skip "No git repo"
    return
  fi

  local commits_total=0
  local commits_valid=0

  while IFS= read -r msg; do
    [ -z "$msg" ] && continue
    commits_total=$((commits_total + 1))
    if validate_commit_message "$msg" 2>/dev/null; then
      commits_valid=$((commits_valid + 1))
    fi
  done < <(git log main..HEAD --format="%s" 2>/dev/null || true)

  if [ "$commits_total" -eq 0 ]; then
    trace_skip "No hay commits (branch = main?)"
  elif [ "$commits_valid" -eq "$commits_total" ]; then
    trace_ok "Commit format: $commits_valid/$commits_total válidos"
  else
    trace_fail "Commit format: $commits_valid/$commits_total válidos"
  fi
}

check_compliance_score() {
  section "10. Compliance Score"
  if ! declare -f compliance_score &>/dev/null; then
    trace_skip "co-core.sh no disponible"
    return
  fi

  local score_json
  score_json="$(compliance_score "$JOURNAL_PATH" "$CONTRACT_ID" 2>/dev/null || echo "")"

  if [ -z "$score_json" ]; then
    trace_fail "No se pudo calcular compliance score"
    return
  fi

  local coverage
  coverage="$(echo "$score_json" | jq -r '.total.coverage')"
  local pass total
  pass="$(echo "$score_json" | jq -r '.total.pass')"
  total="$(echo "$score_json" | jq -r '.total.total')"

  if [ "$(echo "$coverage" | cut -d. -f1)" -ge 80 ]; then
    trace_ok "Compliance: ${coverage}% ($pass/$total controls PASS)"
  elif [ "$(echo "$coverage" | cut -d. -f1)" -gt 0 ]; then
    trace_fail "Compliance: ${coverage}% ($pass/$total controls PASS) — target ≥80%"
  else
    trace_fail "Compliance: 0% — no controls verified"
  fi
}

# ─── Summary ─────────────────────────────────────────────────

trace_summary() {
  echo ""
  echo -e "${BOLD}═══ TRACEABILITY SUMMARY ═══${NC}"
  echo ""

  # Visual chain
  local chain_items=("Contract" "Audit" "Gates" "Bundles" "Integrity" "Ledger" "Link" "Branch" "Commits" "Score")
  echo -n "  "
  for item in "${chain_items[@]}"; do
    echo -n "$item → "
  done
  echo "DONE"
  echo ""

  echo -e "  ${GREEN}OK:${NC}     $TRACE_OK"
  echo -e "  ${RED}FAIL:${NC}   $TRACE_FAIL"
  echo -e "  ${YELLOW}SKIP:${NC}   $TRACE_SKIP"
  echo ""

  local total=$((TRACE_OK + TRACE_FAIL + TRACE_SKIP))
  local checked=$((TRACE_OK + TRACE_FAIL))

  if [ "$TRACE_FAIL" -eq 0 ] && [ "$checked" -gt 0 ]; then
    echo -e "  ${GREEN}${BOLD}Result: PASS${NC} — all $checked checks passed ($TRACE_SKIP skipped)"
  elif [ "$TRACE_FAIL" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}Result: FAIL${NC} — $TRACE_FAIL failures in $checked checks"
  else
    echo -e "  ${YELLOW}${BOLD}Result: INCONCLUSIVE${NC} — all checks skipped"
  fi
  echo ""
}

# ─── Usage ───────────────────────────────────────────────────

usage() {
  cat <<'EOF'
sak-trace.sh — E2E Traceability Verification

Usage:
  sak-trace.sh <CONTRACT_ID> --journal-path <PATH>

Checks:
   1. Contract ID format
   2. Audit trail exists
   3. Gates coverage (G0-G9)
   4. Evidence bundles exist
   5. Bundle integrity (SHA-256)
   6. Ledger chain integrity
   7. Ledger ↔ Contract linkage
   8. Branch naming convention
   9. Commit message format
  10. Compliance score

API-dependent checks (OP, GitHub) show [SKIP] when not available.

Examples:
  sak-trace.sh CTR-agents-sak-20260304 --journal-path ~/journal
EOF
}

# ─── Main ────────────────────────────────────────────────────

main() {
  CONTRACT_ID=""
  JOURNAL_PATH=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --journal-path) JOURNAL_PATH="$2"; shift 2 ;;
      -h|--help)      usage; exit 0 ;;
      *)
        if [ -z "$CONTRACT_ID" ]; then
          CONTRACT_ID="$1"
        fi
        shift
        ;;
    esac
  done

  if [ -z "$CONTRACT_ID" ]; then
    usage
    exit 1
  fi

  JOURNAL_PATH="$(journal_path_resolve "$JOURNAL_PATH")" || exit 1

  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   SAK Trace — E2E Traceability Verification      ║${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  Contract: ${CYAN}$CONTRACT_ID${NC}"
  echo -e "  Journal:  ${CYAN}$JOURNAL_PATH${NC}"

  check_contract_format
  check_audit_trail_exists
  check_audit_gates_coverage
  check_bundles_exist
  check_bundle_integrity
  check_ledger_chain
  check_ledger_links_contract
  check_branch_naming
  check_commit_format
  check_compliance_score

  trace_summary

  if [ "$TRACE_FAIL" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
