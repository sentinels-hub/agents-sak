#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# co-setup.sh — Compliance Audit Setup & Verification
# ─────────────────────────────────────────────────────────────
# Verifica y/o inicializa un journal repo para audit trails:
#   1. Verificar dependencias (jq, git, python3)
#   2. Verificar/crear estructura audit (audit/)
#   3. Verificar estado audit trail (entries, gates cubiertos)
#   4. Verificar conectividad git del journal repo
#   5. Reporte final con colores
#
# Idempotente: ejecutar N veces no rompe nada.
#
# Requiere: jq, python3, git
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/co-core.sh"

# ─── Output helpers ───────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

ok()      { echo -e "  ${GREEN}[OK]${NC} $*"; }
fail()    { echo -e "  ${RED}[FAIL]${NC} $*"; }
warn()    { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
info()    { echo -e "  ${CYAN}[INFO]${NC} $*"; }
section() { echo -e "\n${BOLD}═══ $* ═══${NC}"; }

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

# Modes
CHECK_ONLY=false
INIT_MODE=false

# ─── 1. Dependencies ────────────────────────────────────────

check_dependencies() {
  section "1. Dependencias"

  # jq
  if command -v jq &>/dev/null; then
    ok "jq $(jq --version 2>/dev/null || echo '?')"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    fail "jq no encontrado"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
  fi

  # git
  if command -v git &>/dev/null; then
    ok "git $(git --version 2>/dev/null | head -1 | sed 's/git version //')"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    fail "git no encontrado"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
  fi

  # python3
  if command -v python3 &>/dev/null; then
    ok "python3 $(python3 --version 2>/dev/null | sed 's/Python //')"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    fail "python3 no encontrado"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
  fi
}

# ─── 2. Audit Structure ─────────────────────────────────────

check_audit_structure() {
  local journal_path="$1"
  section "2. Estructura Audit — $journal_path"

  if [ ! -d "$journal_path" ]; then
    if [ "$INIT_MODE" = true ]; then
      mkdir -p "$journal_path"
      info "Creado: $journal_path"
    else
      fail "Journal no encontrado: $journal_path"
      CHECKS_FAILED=$((CHECKS_FAILED + 1))
      return 1
    fi
  fi

  # audit/ directory
  if [ -d "$journal_path/audit" ]; then
    local contract_count
    contract_count="$(find "$journal_path/audit" -name "audit-trail.jsonl" -type f 2>/dev/null | wc -l | tr -d ' ')"
    ok "audit/ existe ($contract_count contratos con audit trail)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))

    # List contract subdirectories
    if [ "$contract_count" -gt 0 ]; then
      find "$journal_path/audit" -name "audit-trail.jsonl" -type f 2>/dev/null | sort | while read -r f; do
        local dir_name count
        dir_name="$(basename "$(dirname "$f")")"
        count="$(wc -l < "$f" | tr -d ' ')"
        info "  $dir_name ($count entries)"
      done
    fi
  elif [ "$INIT_MODE" = true ]; then
    mkdir -p "$journal_path/audit"
    info "Creado: audit/"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "audit/ no encontrado"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
  fi
}

# ─── 3. Audit Trail State ───────────────────────────────────

check_audit_state() {
  local journal_path="$1"
  section "3. Estado Audit Trail"

  if [ ! -d "$journal_path/audit" ]; then
    info "No hay audit trails (directorio audit/ no existe)"
    return 0
  fi

  local total_entries=0
  local total_contracts=0

  while IFS= read -r trail_file; do
    [ -z "$trail_file" ] && continue
    total_contracts=$((total_contracts + 1))

    local contract_dir count
    contract_dir="$(basename "$(dirname "$trail_file")")"
    count="$(wc -l < "$trail_file" | tr -d ' ')"
    total_entries=$((total_entries + count))

    # Check gates coverage for this contract
    local gates_covered
    gates_covered="$(jq -r 'select(.action == "control_verified") | .gate' "$trail_file" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')"

    if [ -n "$gates_covered" ]; then
      info "  $contract_dir: $count entries, gates: $gates_covered"
    else
      info "  $contract_dir: $count entries, no gates verified"
    fi
  done < <(find "$journal_path/audit" -name "audit-trail.jsonl" -type f 2>/dev/null | sort)

  if [ "$total_contracts" -eq 0 ]; then
    info "No audit trails encontrados"
  else
    ok "Total: $total_contracts contratos, $total_entries entries"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  fi
}

# ─── 4. Git Connectivity ────────────────────────────────────

check_git() {
  local journal_path="$1"
  section "4. Git — Journal Repo"

  if [ ! -d "$journal_path/.git" ]; then
    if [ "$INIT_MODE" = true ]; then
      (cd "$journal_path" && git init --quiet)
      info "Inicializado git repo"
      CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
      warn "No es un repositorio git"
      CHECKS_WARNED=$((CHECKS_WARNED + 1))
    fi
    return 0
  fi

  ok "Repositorio git detectado"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))

  # Branch
  local branch
  branch="$(cd "$journal_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
  info "Branch: $branch"

  # Remote
  local remote
  remote="$(cd "$journal_path" && git remote get-url origin 2>/dev/null || echo "")"
  if [ -n "$remote" ]; then
    ok "Remote: $remote"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "No remote 'origin' configurado"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
  fi

  # Status
  local dirty
  dirty="$(cd "$journal_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$dirty" -eq 0 ]; then
    ok "Working tree limpio"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "Working tree con $dirty cambios sin commit"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
  fi
}

# ─── 5. Final Report ────────────────────────────────────────

print_report() {
  section "REPORTE FINAL"

  if [ "$CHECK_ONLY" = true ]; then
    echo -e "\n  ${CYAN}${BOLD}MODO CHECK-ONLY — no se han realizado cambios${NC}\n"
  fi
  if [ "$INIT_MODE" = true ]; then
    echo -e "\n  ${CYAN}${BOLD}MODO INIT — se crearon directorios faltantes${NC}\n"
  fi

  echo ""
  echo -e "  ${GREEN}Checks OK:${NC}     $CHECKS_PASSED"
  echo -e "  ${RED}Checks FAIL:${NC}   $CHECKS_FAILED"
  echo -e "  ${YELLOW}Checks WARN:${NC}   $CHECKS_WARNED"
  echo ""

  if [ "$CHECKS_FAILED" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}Estado: SETUP INCOMPLETO${NC}"
    echo "  Revisa los items marcados con [FAIL] arriba."
  elif [ "$CHECKS_WARNED" -gt 0 ]; then
    echo -e "  ${YELLOW}${BOLD}Estado: SETUP PARCIAL${NC}"
    echo "  Funcional pero con advertencias. Revisa items [WARN]."
  else
    echo -e "  ${GREEN}${BOLD}Estado: SETUP COMPLETO${NC}"
    echo "  Journal listo para audit trails de compliance."
  fi
  echo ""
}

# ─── Usage ───────────────────────────────────────────────────

usage() {
  cat <<'EOF'
co-setup.sh — Compliance Audit Setup & Verification

Usage:
  co-setup.sh <JOURNAL_PATH>
  co-setup.sh --check-only <JOURNAL_PATH>
  co-setup.sh --init <JOURNAL_PATH>

Options:
  --check-only   Solo verificar, no crear nada
  --init         Crear estructura faltante (audit/, git init)

Examples:
  co-setup.sh ~/GitHub/sentinels-hub/sentinels-agents-journal
  co-setup.sh --check-only ~/journals/my-journal
  co-setup.sh --init ~/journals/new-journal

Checks:
  1. Dependencias: jq, git, python3
  2. Estructura: audit/ directory, contract subdirs
  3. Estado: entries por contrato, gates cubiertos
  4. Git: repo, remote, working tree

Requires:
  jq, python3, git
EOF
}

# ─── Main ────────────────────────────────────────────────────

main() {
  local journal_paths=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --check-only)  CHECK_ONLY=true; shift ;;
      --init)        INIT_MODE=true; shift ;;
      -h|--help)     usage; exit 0 ;;
      *)             journal_paths+=("$1"); shift ;;
    esac
  done

  if [ ${#journal_paths[@]} -eq 0 ]; then
    usage
    exit 1
  fi

  # In check-only mode, disable init
  if [ "$CHECK_ONLY" = true ]; then
    INIT_MODE=false
  fi

  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  if [ "$CHECK_ONLY" = true ]; then
    echo -e "${BOLD}║   Compliance Audit Setup — CHECK ONLY             ║${NC}"
  elif [ "$INIT_MODE" = true ]; then
    echo -e "${BOLD}║   Compliance Audit Setup — INIT                   ║${NC}"
  else
    echo -e "${BOLD}║   Compliance Audit Setup — Sentinels Protocol     ║${NC}"
  fi
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"

  check_dependencies

  for journal_path in "${journal_paths[@]}"; do
    check_audit_structure "$journal_path"
    check_audit_state "$journal_path"
    check_git "$journal_path"
  done

  print_report

  if [ "$CHECKS_FAILED" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
