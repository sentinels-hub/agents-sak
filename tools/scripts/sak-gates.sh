#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# sak-gates.sh — Gate Validation
# ─────────────────────────────────────────────────────────────
# Dos modos: check-ready (pre-gate) y check-complete (post-gate)
#
# Usage:
#   sak gates check-ready <CTR> <GATE> --journal-path <PATH>
#   sak gates check-complete <CTR> <GATE> --journal-path <PATH>
#   sak gates status <CTR> --journal-path <PATH>
#   sak gates next <CTR> --journal-path <PATH>
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

# ─── Gate Prerequisites ──────────────────────────────────────
# Returns prerequisite checks required for a gate

gate_prerequisites() {
  local gate="$1"
  case "$gate" in
    G0) echo "contract_format" ;;
    G1) echo "contract_format previous_G0" ;;
    G2) echo "contract_format previous_G1" ;;
    G3) echo "contract_format previous_G2" ;;
    G4) echo "contract_format previous_G3 branch_exists" ;;
    G5) echo "contract_format previous_G4" ;;
    G6) echo "contract_format previous_G5" ;;
    G7) echo "contract_format previous_G6" ;;
    G8) echo "contract_format previous_G7 bundle_exists" ;;
    G9) echo "contract_format previous_G8 all_controls_pass" ;;
    *)  echo "" ;;
  esac
}

# ─── Prerequisite Check Functions ────────────────────────────

prereq_contract_format() {
  if contract_id_validate "$CONTRACT_ID" 2>/dev/null; then
    echo "PASS"
  else
    echo "FAIL"
  fi
}

prereq_previous_gate() {
  local required_gate="$1"

  if ! declare -f audit_trail_entries &>/dev/null; then
    echo "SKIP"
    return
  fi

  local trail_file
  trail_file="$(audit_trail_path "$JOURNAL_PATH" "$CONTRACT_ID")"

  if [ ! -f "$trail_file" ]; then
    echo "FAIL"
    return
  fi

  # Check if there's a PASS entry for the required gate
  local pass_count
  pass_count="$(jq -r "select(.gate == \"$required_gate\" and .result == \"PASS\") | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"

  if [ "$pass_count" -gt 0 ]; then
    echo "PASS"
  else
    echo "FAIL"
  fi
}

prereq_branch_exists() {
  if ! command -v git &>/dev/null || ! git rev-parse --git-dir &>/dev/null 2>&1; then
    echo "SKIP"
    return
  fi

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

  if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    echo "PASS"
  else
    echo "FAIL"
  fi
}

prereq_bundle_exists() {
  if [ ! -d "$JOURNAL_PATH/bundles" ]; then
    echo "FAIL"
    return
  fi

  local found=0
  while IFS= read -r manifest; do
    [ -z "$manifest" ] && continue
    if grep -q "\"$CONTRACT_ID\"" "$manifest" 2>/dev/null; then
      found=1
      break
    fi
  done < <(find "$JOURNAL_PATH/bundles" -name "bundle-manifest.json" -type f 2>/dev/null)

  if [ "$found" -eq 1 ]; then
    echo "PASS"
  else
    echo "FAIL"
  fi
}

prereq_all_controls_pass() {
  if ! declare -f compliance_score &>/dev/null; then
    echo "SKIP"
    return
  fi

  local score_json
  score_json="$(compliance_score "$JOURNAL_PATH" "$CONTRACT_ID" 2>/dev/null || echo "")"

  if [ -z "$score_json" ]; then
    echo "FAIL"
    return
  fi

  local fail_count pending_count
  fail_count="$(echo "$score_json" | jq -r '.total.fail')"
  pending_count="$(echo "$score_json" | jq -r '.total.pending')"

  if [ "$fail_count" -eq 0 ] && [ "$pending_count" -eq 0 ]; then
    echo "PASS"
  else
    echo "FAIL"
  fi
}

# ─── Check Gate Ready ────────────────────────────────────────

check_gate_ready() {
  local gate="$1"

  echo ""
  echo -e "${BOLD}Gate $gate — Pre-flight Check${NC}"
  echo ""

  local prereqs
  prereqs="$(gate_prerequisites "$gate")"

  if [ -z "$prereqs" ]; then
    echo -e "  ${RED}[FAIL]${NC} Gate desconocido: $gate"
    return 1
  fi

  local all_pass=true

  for prereq in $prereqs; do
    local result=""
    case "$prereq" in
      contract_format)
        result="$(prereq_contract_format)"
        echo -e "  $(result_badge "$result") Contract format: $CONTRACT_ID"
        ;;
      previous_G*)
        local prev_gate="${prereq#previous_}"
        result="$(prereq_previous_gate "$prev_gate")"
        echo -e "  $(result_badge "$result") Previous gate $prev_gate PASS"
        ;;
      branch_exists)
        result="$(prereq_branch_exists)"
        echo -e "  $(result_badge "$result") Git branch exists"
        ;;
      bundle_exists)
        result="$(prereq_bundle_exists)"
        echo -e "  $(result_badge "$result") Evidence bundle exists"
        ;;
      all_controls_pass)
        result="$(prereq_all_controls_pass)"
        echo -e "  $(result_badge "$result") All controls PASS"
        ;;
    esac

    if [ "$result" = "FAIL" ]; then
      all_pass=false
    fi
  done

  echo ""
  if [ "$all_pass" = true ]; then
    echo -e "  ${GREEN}${BOLD}READY${NC} — Gate $gate prerequisites satisfied"
  else
    echo -e "  ${RED}${BOLD}NOT READY${NC} — Gate $gate has unmet prerequisites"
  fi
  echo ""

  [ "$all_pass" = true ]
}

# ─── Check Gate Complete ─────────────────────────────────────

check_gate_complete() {
  local gate="$1"

  echo ""
  echo -e "${BOLD}Gate $gate — Completion Check${NC}"
  echo ""

  if ! declare -f audit_trail_entries &>/dev/null; then
    echo -e "  ${RED}[FAIL]${NC} co-core.sh no disponible"
    return 1
  fi

  local trail_file
  trail_file="$(audit_trail_path "$JOURNAL_PATH" "$CONTRACT_ID")"

  if [ ! -f "$trail_file" ]; then
    echo -e "  ${RED}[FAIL]${NC} Audit trail no encontrado"
    return 1
  fi

  # Check if gate has PASS entries
  local pass_entries
  pass_entries="$(jq -r "select(.gate == \"$gate\" and .result == \"PASS\") | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"

  if [ "$pass_entries" -gt 0 ]; then
    echo -e "  ${GREEN}[OK]${NC} Gate $gate tiene $pass_entries entries con PASS"
  else
    echo -e "  ${RED}[FAIL]${NC} Gate $gate no tiene entries con PASS"
  fi

  # Check for open non-conformities in this gate
  local nc_count
  nc_count="$(jq -r "select(.gate == \"$gate\" and .action == \"non_conformity\") | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"
  local ca_count
  ca_count="$(jq -r "select(.gate == \"$gate\" and (.action == \"corrective_action\" or .action == \"risk_accepted\")) | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"

  if [ "$nc_count" -gt 0 ] && [ "$ca_count" -lt "$nc_count" ]; then
    echo -e "  ${RED}[FAIL]${NC} Non-conformities abiertas: $((nc_count - ca_count))"
  elif [ "$nc_count" -gt 0 ]; then
    echo -e "  ${GREEN}[OK]${NC} Non-conformities resueltas: $nc_count"
  else
    echo -e "  ${GREEN}[OK]${NC} Sin non-conformities"
  fi

  # Check controls verified for this gate
  if declare -f controls_by_gate &>/dev/null; then
    local expected_controls
    expected_controls="$(controls_by_gate "$gate" | jq -r '.[].control_id' 2>/dev/null)"
    local expected_count
    expected_count="$(echo "$expected_controls" | grep -c '^' 2>/dev/null || true)"

    local verified=0
    while IFS= read -r ctrl; do
      [ -z "$ctrl" ] && continue
      local ctrl_pass
      ctrl_pass="$(jq -r "select(.gate == \"$gate\" and .action == \"control_verified\" and .result == \"PASS\" and (.controls[] == \"$ctrl\")) | .gate" "$trail_file" 2>/dev/null | head -1)"
      if [ -n "$ctrl_pass" ]; then
        verified=$((verified + 1))
      fi
    done <<< "$expected_controls"

    echo -e "  ${CYAN}[INFO]${NC} Controls verificados: $verified/$expected_count"
  fi

  echo ""
  if [ "$pass_entries" -gt 0 ]; then
    echo -e "  ${GREEN}${BOLD}COMPLETE${NC} — Gate $gate has been passed"
  else
    echo -e "  ${RED}${BOLD}INCOMPLETE${NC} — Gate $gate is not yet passed"
  fi
  echo ""

  [ "$pass_entries" -gt 0 ]
}

# ─── Check Previous Gates ───────────────────────────────────

check_previous_gates() {
  local target_gate="$1"
  local gate_num="${target_gate#G}"
  local all_pass=true

  for ((i=0; i<gate_num; i++)); do
    local g="G$i"
    local result
    result="$(prereq_previous_gate "$g")"
    if [ "$result" != "PASS" ]; then
      all_pass=false
    fi
  done

  echo "$all_pass"
}

# ─── Suggest Next Gate ───────────────────────────────────────

suggest_next_gate() {
  if ! declare -f audit_trail_entries &>/dev/null; then
    echo "G0"
    return
  fi

  local trail_file
  trail_file="$(audit_trail_path "$JOURNAL_PATH" "$CONTRACT_ID")"

  for i in $(seq 0 9); do
    local gate="G$i"
    local pass_count=0

    if [ -f "$trail_file" ]; then
      pass_count="$(jq -r "select(.gate == \"$gate\" and .result == \"PASS\") | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"
    fi

    if [ "$pass_count" -eq 0 ]; then
      echo "$gate"
      return
    fi
  done

  echo "ALL_DONE"
}

# ─── Gate Status Report ─────────────────────────────────────

gate_status_report() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   Gate Status — ${CONTRACT_ID}${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""

  local gate_descriptions=(
    "G0:Contract initialized"
    "G1:Identity verified"
    "G2:Plan approved"
    "G3:Implementation tracked"
    "G4:Security analysis"
    "G5:Code review"
    "G6:QA verification"
    "G7:Deployment"
    "G8:Evidence export"
    "G9:Closure"
  )

  local passed=0
  local total=10

  printf "  %-6s %-8s %-6s %-5s %s\n" "GATE" "STATUS" "PASS" "NCs" "DESCRIPTION"
  printf "  %-6s %-8s %-6s %-5s %s\n" "────" "──────" "────" "───" "───────────"

  for desc_entry in "${gate_descriptions[@]}"; do
    local gate="${desc_entry%%:*}"
    local desc="${desc_entry#*:}"
    local status="--"
    local pass_count=0
    local nc_count=0

    if declare -f audit_trail_entries &>/dev/null; then
      local trail_file
      trail_file="$(audit_trail_path "$JOURNAL_PATH" "$CONTRACT_ID")"

      if [ -f "$trail_file" ]; then
        pass_count="$(jq -r "select(.gate == \"$gate\" and .result == \"PASS\") | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"
        nc_count="$(jq -r "select(.gate == \"$gate\" and .action == \"non_conformity\") | .gate" "$trail_file" 2>/dev/null | wc -l | tr -d ' ')"
      fi
    fi

    if [ "$pass_count" -gt 0 ]; then
      status="PASS"
      passed=$((passed + 1))
    elif [ "$nc_count" -gt 0 ]; then
      status="NC"
    fi

    local color="$NC"
    case "$status" in
      PASS) color="$GREEN" ;;
      NC)   color="$RED" ;;
      --)   color="$DIM" ;;
    esac

    printf "  %-6s ${color}%-8s${NC} %-6s %-5s %s\n" "$gate" "$status" "$pass_count" "$nc_count" "$desc"
  done

  echo ""
  echo -e "  Gates passed: ${BOLD}$passed/$total${NC}"

  local next
  next="$(suggest_next_gate)"
  if [ "$next" = "ALL_DONE" ]; then
    echo -e "  Next gate: ${GREEN}${BOLD}ALL GATES PASSED${NC}"
  else
    echo -e "  Next gate: ${CYAN}${BOLD}$next${NC}"
  fi
  echo ""
}

# ─── Result badge helper ────────────────────────────────────

result_badge() {
  local result="$1"
  case "$result" in
    PASS) echo "${GREEN}[OK]${NC}" ;;
    FAIL) echo "${RED}[FAIL]${NC}" ;;
    SKIP) echo "${YELLOW}[SKIP]${NC}" ;;
    *)    echo "${DIM}[??]${NC}" ;;
  esac
}

# ─── Usage ───────────────────────────────────────────────────

usage() {
  cat <<'EOF'
sak-gates.sh — Gate Validation

Usage:
  sak-gates.sh check-ready <CTR> <GATE> --journal-path <PATH>
  sak-gates.sh check-complete <CTR> <GATE> --journal-path <PATH>
  sak-gates.sh status <CTR> --journal-path <PATH>
  sak-gates.sh next <CTR> --journal-path <PATH>

Commands:
  check-ready      Check if prerequisites for a gate are met (pre-gate)
  check-complete   Check if a gate has been successfully passed (post-gate)
  status           Show status of all gates for a contract
  next             Show the next gate to complete

Examples:
  sak-gates.sh status CTR-agents-sak-20260304 --journal-path ~/journal
  sak-gates.sh check-ready CTR-agents-sak-20260304 G5 --journal-path ~/journal
  sak-gates.sh next CTR-agents-sak-20260304 --journal-path ~/journal
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
  local gate=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --journal-path) JOURNAL_PATH="$2"; shift 2 ;;
      -h|--help)      usage; exit 0 ;;
      G[0-9])         gate="$1"; shift ;;
      *)
        if [ -z "$CONTRACT_ID" ]; then
          CONTRACT_ID="$1"
        elif [ -z "$gate" ]; then
          gate="$1"
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
    check-ready)
      if [ -z "$gate" ]; then
        echo "ERROR: se requiere gate (G0-G9)" >&2
        exit 1
      fi
      check_gate_ready "$gate"
      ;;
    check-complete)
      if [ -z "$gate" ]; then
        echo "ERROR: se requiere gate (G0-G9)" >&2
        exit 1
      fi
      check_gate_complete "$gate"
      ;;
    status)
      gate_status_report
      ;;
    next)
      local next
      next="$(suggest_next_gate)"
      if [ "$next" = "ALL_DONE" ]; then
        echo -e "${GREEN}${BOLD}All gates passed for $CONTRACT_ID${NC}"
      else
        echo -e "Next gate: ${CYAN}${BOLD}$next${NC}"
        echo ""
        check_gate_ready "$next"
      fi
      ;;
    *)
      echo "ERROR: comando desconocido: $command" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
