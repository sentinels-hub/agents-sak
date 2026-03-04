#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# sak-metrics.sh — Cross-tool Analytics & Metrics
# ─────────────────────────────────────────────────────────────
# Métricas cross-tool. Output JSON + tabla.
#
# Usage:
#   sak metrics summary <CTR> --journal-path <PATH>
#   sak metrics gaps <CTR> --journal-path <PATH>
#   sak metrics coverage <CTR> --journal-path <PATH>
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sak-core.sh"

# Source tool cores
CO_CORE="$SCRIPT_DIR/../compliance/scripts/co-core.sh"
EV_CORE="$SCRIPT_DIR/../evidence/scripts/ev-core.sh"
GH_CORE="$SCRIPT_DIR/../github/scripts/gh-core.sh"

[ -f "$CO_CORE" ] && source "$CO_CORE"
[ -f "$EV_CORE" ] && source "$EV_CORE"
[ -f "$GH_CORE" ] && source "$GH_CORE"

# ─── Metric Functions ────────────────────────────────────────

# Control coverage percentage
metric_control_coverage() {
  if ! declare -f compliance_score &>/dev/null; then
    echo "N/A"
    return
  fi

  local score_json
  score_json="$(compliance_score "$JOURNAL_PATH" "$CONTRACT_ID" 2>/dev/null || echo "")"

  if [ -z "$score_json" ]; then
    echo "0"
    return
  fi

  echo "$score_json" | jq -r '.total.coverage'
}

# Gate pass rate: gates with PASS / 10
metric_gate_pass_rate() {
  if ! declare -f audit_trail_entries &>/dev/null; then
    echo "0"
    return
  fi

  local trail_file
  trail_file="$(audit_trail_path "$JOURNAL_PATH" "$CONTRACT_ID")"

  if [ ! -f "$trail_file" ]; then
    echo "0"
    return
  fi

  local passed=0
  for i in $(seq 0 9); do
    local gate="G$i"
    local pass_count
    pass_count="$(jq -r "select(.gate == \"$gate\" and .result == \"PASS\") | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$pass_count" -gt 0 ]; then
      passed=$((passed + 1))
    fi
  done

  echo "$passed"
}

# Chain completeness: how many trace checks pass
metric_chain_completeness() {
  local checks=0
  local passed=0

  # 1. Contract format
  checks=$((checks + 1))
  if contract_id_validate "$CONTRACT_ID" 2>/dev/null; then
    passed=$((passed + 1))
  fi

  # 2. Audit trail exists
  if declare -f audit_trail_count &>/dev/null; then
    checks=$((checks + 1))
    local count
    count="$(audit_trail_count "$JOURNAL_PATH" "$CONTRACT_ID")"
    if [ "$count" -gt 0 ]; then
      passed=$((passed + 1))
    fi
  fi

  # 3. Bundles exist
  checks=$((checks + 1))
  if [ -d "$JOURNAL_PATH/bundles" ]; then
    local found
    found="$(find "$JOURNAL_PATH/bundles" -name "bundle-manifest.json" -type f 2>/dev/null | xargs grep -l "\"$CONTRACT_ID\"" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$found" -gt 0 ]; then
      passed=$((passed + 1))
    fi
  fi

  # 4. Ledger entries
  if declare -f ledger_all_entries &>/dev/null; then
    checks=$((checks + 1))
    local ledger_linked=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      if echo "$line" | jq -r '.contract_id' 2>/dev/null | grep -q "^${CONTRACT_ID}$"; then
        ledger_linked=1
        break
      fi
    done < <(ledger_all_entries "$JOURNAL_PATH")
    if [ "$ledger_linked" -eq 1 ]; then
      passed=$((passed + 1))
    fi
  fi

  echo "$passed/$checks"
}

# Bundle count for this contract
metric_bundle_count() {
  if [ ! -d "$JOURNAL_PATH/bundles" ]; then
    echo "0"
    return
  fi

  local count
  count="$(find "$JOURNAL_PATH/bundles" -name "bundle-manifest.json" -type f 2>/dev/null | xargs grep -l "\"$CONTRACT_ID\"" 2>/dev/null | wc -l | tr -d ' ')"
  echo "$count"
}

# Ledger health: chain check
metric_ledger_health() {
  if ! declare -f ledger_all_entries &>/dev/null; then
    echo "N/A"
    return
  fi

  local total_entries
  total_entries="$(ledger_count "$JOURNAL_PATH")"

  if [ "$total_entries" -eq 0 ]; then
    echo "EMPTY"
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
    echo "UNBROKEN"
  else
    echo "BROKEN($chain_errors)"
  fi
}

# Audit density: entries per gate
metric_audit_density() {
  if ! declare -f audit_trail_entries &>/dev/null; then
    echo "N/A"
    return
  fi

  local trail_file
  trail_file="$(audit_trail_path "$JOURNAL_PATH" "$CONTRACT_ID")"

  if [ ! -f "$trail_file" ]; then
    echo "0"
    return
  fi

  local total
  total="$(wc -l < "$trail_file" | tr -d ' ')"

  local gates_with_entries=0
  for i in $(seq 0 9); do
    local gate="G$i"
    local count
    count="$(jq -r "select(.gate == \"$gate\") | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$count" -gt 0 ]; then
      gates_with_entries=$((gates_with_entries + 1))
    fi
  done

  if [ "$gates_with_entries" -gt 0 ]; then
    echo "$total entries across $gates_with_entries gates"
  else
    echo "0"
  fi
}

# ─── Commands ─────────────────────────────────────────────────

cmd_summary() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   SAK Metrics — ${CONTRACT_ID}${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""

  local control_cov gate_pass chain_comp bundle_cnt ledger_hp audit_den

  control_cov="$(metric_control_coverage)"
  gate_pass="$(metric_gate_pass_rate)"
  chain_comp="$(metric_chain_completeness)"
  bundle_cnt="$(metric_bundle_count)"
  ledger_hp="$(metric_ledger_health)"
  audit_den="$(metric_audit_density)"

  printf "  %-30s %s\n" "METRIC" "VALUE"
  printf "  %-30s %s\n" "──────────────────────────────" "─────────────"
  printf "  %-30s %s%%\n" "Control coverage" "$control_cov"
  printf "  %-30s %s/10\n" "Gate pass rate" "$gate_pass"
  printf "  %-30s %s\n" "Chain completeness" "$chain_comp"
  printf "  %-30s %s\n" "Evidence bundles" "$bundle_cnt"
  printf "  %-30s %s\n" "Ledger health" "$ledger_hp"
  printf "  %-30s %s\n" "Audit density" "$audit_den"
  echo ""

  # JSON output
  local json
  json="$(python3 -c "
import json
print(json.dumps({
    'contract_id': '$CONTRACT_ID',
    'metrics': {
        'control_coverage': '$control_cov',
        'gate_pass_rate': '$gate_pass',
        'chain_completeness': '$chain_comp',
        'bundle_count': '$bundle_cnt',
        'ledger_health': '$ledger_hp',
        'audit_density': '$audit_den'
    }
}, indent=2))
")"

  echo -e "  ${DIM}JSON:${NC}"
  echo "$json" | sed 's/^/  /'
  echo ""
}

cmd_gaps() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   SAK Gaps — ${CONTRACT_ID}${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""

  local gaps_found=0

  # Gate gaps
  section "Gate Gaps"
  if declare -f audit_trail_entries &>/dev/null; then
    local trail_file
    trail_file="$(audit_trail_path "$JOURNAL_PATH" "$CONTRACT_ID")"

    for i in $(seq 0 9); do
      local gate="G$i"
      local pass_count=0
      if [ -f "$trail_file" ]; then
        pass_count="$(jq -r "select(.gate == \"$gate\" and .result == \"PASS\") | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"
      fi

      if [ "$pass_count" -eq 0 ]; then
        echo -e "  ${RED}[GAP]${NC} $gate — no PASS entry"
        gaps_found=$((gaps_found + 1))
      fi
    done
  else
    echo -e "  ${YELLOW}[SKIP]${NC} co-core.sh no disponible"
  fi

  # Evidence gaps
  section "Evidence Gaps"
  local bundle_cnt
  bundle_cnt="$(metric_bundle_count)"
  if [ "$bundle_cnt" -eq 0 ]; then
    echo -e "  ${RED}[GAP]${NC} No evidence bundles for this contract"
    gaps_found=$((gaps_found + 1))
  else
    echo -e "  ${GREEN}[OK]${NC} $bundle_cnt bundles found"
  fi

  local ledger_hp
  ledger_hp="$(metric_ledger_health)"
  if [ "$ledger_hp" = "EMPTY" ]; then
    echo -e "  ${RED}[GAP]${NC} Ledger is empty"
    gaps_found=$((gaps_found + 1))
  elif [[ "$ledger_hp" == BROKEN* ]]; then
    echo -e "  ${RED}[GAP]${NC} Ledger chain is broken: $ledger_hp"
    gaps_found=$((gaps_found + 1))
  else
    echo -e "  ${GREEN}[OK]${NC} Ledger chain: $ledger_hp"
  fi

  # Control gaps
  section "Control Gaps"
  if declare -f compliance_score &>/dev/null; then
    local score_json
    score_json="$(compliance_score "$JOURNAL_PATH" "$CONTRACT_ID" 2>/dev/null || echo "")"

    if [ -n "$score_json" ]; then
      local pending
      pending="$(echo "$score_json" | jq -r '.total.pending')"
      local fail
      fail="$(echo "$score_json" | jq -r '.total.fail')"

      if [ "$pending" -gt 0 ]; then
        echo -e "  ${RED}[GAP]${NC} $pending controls pending verification"
        gaps_found=$((gaps_found + 1))
      fi
      if [ "$fail" -gt 0 ]; then
        echo -e "  ${RED}[GAP]${NC} $fail controls FAILED"
        gaps_found=$((gaps_found + 1))
      fi
      if [ "$pending" -eq 0 ] && [ "$fail" -eq 0 ]; then
        echo -e "  ${GREEN}[OK]${NC} All controls verified and passing"
      fi
    fi
  else
    echo -e "  ${YELLOW}[SKIP]${NC} co-core.sh no disponible"
  fi

  echo ""
  if [ "$gaps_found" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}No gaps found${NC}"
  else
    echo -e "  ${RED}${BOLD}$gaps_found gaps found${NC}"
  fi
  echo ""
}

cmd_coverage() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   SAK Coverage — ${CONTRACT_ID}${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""

  if ! declare -f compliance_score &>/dev/null; then
    echo -e "  ${YELLOW}[SKIP]${NC} co-core.sh no disponible para scoring"
    return
  fi

  local score_json
  score_json="$(compliance_score "$JOURNAL_PATH" "$CONTRACT_ID" 2>/dev/null || echo "")"

  if [ -z "$score_json" ]; then
    echo -e "  ${RED}[FAIL]${NC} No se pudo calcular coverage"
    return
  fi

  printf "  %-25s %6s %6s %6s %6s %8s\n" "FRAMEWORK" "TOTAL" "PASS" "FAIL" "PEND" "COVERAGE"
  printf "  %-25s %6s %6s %6s %6s %8s\n" "─────────────────────────" "─────" "─────" "─────" "─────" "────────"

  echo "$score_json" | jq -r '.frameworks | to_entries[] | "\(.key) \(.value.total) \(.value.pass) \(.value.fail) \(.value.pending) \(.value.coverage)"' 2>/dev/null | while read -r fw total pass fail pending coverage; do
    local color="$NC"
    local cov_int="${coverage%%.*}"
    if [ "$cov_int" -ge 80 ]; then
      color="$GREEN"
    elif [ "$cov_int" -ge 50 ]; then
      color="$YELLOW"
    elif [ "$cov_int" -gt 0 ]; then
      color="$RED"
    fi
    printf "  %-25s %6s %6s %6s %6s ${color}%7s%%${NC}\n" "$fw" "$total" "$pass" "$fail" "$pending" "$coverage"
  done

  local total_cov
  total_cov="$(echo "$score_json" | jq -r '.total.coverage')"
  local total_total total_pass total_fail total_pend
  total_total="$(echo "$score_json" | jq -r '.total.total')"
  total_pass="$(echo "$score_json" | jq -r '.total.pass')"
  total_fail="$(echo "$score_json" | jq -r '.total.fail')"
  total_pend="$(echo "$score_json" | jq -r '.total.pending')"

  printf "  %-25s %6s %6s %6s %6s ${BOLD}%7s%%${NC}\n" "TOTAL" "$total_total" "$total_pass" "$total_fail" "$total_pend" "$total_cov"
  echo ""
}

# ─── Usage ───────────────────────────────────────────────────

usage() {
  cat <<'EOF'
sak-metrics.sh — Cross-tool Analytics & Metrics

Usage:
  sak-metrics.sh summary <CTR> --journal-path <PATH>
  sak-metrics.sh gaps <CTR> --journal-path <PATH>
  sak-metrics.sh coverage <CTR> --journal-path <PATH>

Commands:
  summary     Full metrics summary (table + JSON)
  gaps        Identify gaps in gates, evidence, and controls
  coverage    Compliance coverage by framework

Examples:
  sak-metrics.sh summary CTR-agents-sak-20260304 --journal-path ~/journal
  sak-metrics.sh gaps CTR-agents-sak-20260304 --journal-path ~/journal
  sak-metrics.sh coverage CTR-agents-sak-20260304 --journal-path ~/journal
EOF
}

# ─── Main ────────────────────────────────────────────────────

main() {
  if [ $# -eq 0 ]; then
    usage
    exit 0
  fi

  local command="$1"
  shift

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
    echo "ERROR: se requiere contract_id" >&2
    usage
    exit 1
  fi

  JOURNAL_PATH="$(journal_path_resolve "$JOURNAL_PATH")" || exit 1
  contract_id_validate "$CONTRACT_ID" || exit 1

  case "$command" in
    summary)  cmd_summary ;;
    gaps)     cmd_gaps ;;
    coverage) cmd_coverage ;;
    *)
      echo "ERROR: comando desconocido: $command" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
