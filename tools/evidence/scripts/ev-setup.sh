#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# ev-setup.sh — Evidence Journal Setup & Verification
# ─────────────────────────────────────────────────────────────
# Verifica y/o inicializa un journal repo para evidence:
#   1. Verificar dependencias (sha256sum/shasum, jq, git, python3)
#   2. Verificar/crear estructura journal (bundles/, ledger/)
#   3. Verificar estado del ledger (entries, chain integrity)
#   4. Verificar conectividad git del journal repo
#   5. Reporte final con colores
#
# Idempotente: ejecutar N veces no rompe nada.
#
# Requiere: sha256sum/shasum, jq, python3, git
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ev-core.sh"

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

  # SHA-256
  if command -v sha256sum &>/dev/null; then
    ok "sha256sum disponible"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  elif command -v shasum &>/dev/null; then
    ok "shasum disponible (fallback)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    fail "sha256sum/shasum no encontrado"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
  fi

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

# ─── 2. Journal Structure ───────────────────────────────────

check_journal_structure() {
  local journal_path="$1"
  section "2. Estructura del Journal — $journal_path"

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

  # bundles/ directory
  if [ -d "$journal_path/bundles" ]; then
    local bundle_count
    bundle_count="$(find "$journal_path/bundles" -name "bundle-manifest.json" -type f 2>/dev/null | wc -l | tr -d ' ')"
    ok "bundles/ existe ($bundle_count manifests)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  elif [ "$INIT_MODE" = true ]; then
    mkdir -p "$journal_path/bundles"
    info "Creado: bundles/"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "bundles/ no encontrado"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
  fi

  # ledger/ directory
  if [ -d "$journal_path/ledger" ]; then
    ok "ledger/ existe"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  elif [ "$INIT_MODE" = true ]; then
    mkdir -p "$journal_path/ledger"
    info "Creado: ledger/"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "ledger/ no encontrado"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
  fi

  # Legacy structure check
  if [ -d "$journal_path/evidence" ]; then
    local legacy_count
    legacy_count="$(find "$journal_path/evidence" -name "bundle-manifest*.json" -type f 2>/dev/null | wc -l | tr -d ' ')"
    info "evidence/ legacy detectado ($legacy_count manifests)"
  fi

  if [ -f "$journal_path/ledger/ledger.jsonl" ]; then
    local legacy_entries
    legacy_entries="$(wc -l < "$journal_path/ledger/ledger.jsonl" | tr -d ' ')"
    info "ledger/ledger.jsonl legacy detectado ($legacy_entries entries)"
  fi
}

# ─── 3. Ledger State ────────────────────────────────────────

check_ledger_state() {
  local journal_path="$1"
  section "3. Estado del Ledger"

  local total_entries
  total_entries="$(ledger_count "$journal_path")"

  if [ "$total_entries" -eq 0 ]; then
    info "Ledger vacío (0 entries)"
    return 0
  fi

  ok "Entries totales: $total_entries"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))

  # List partition files
  if [ -d "$journal_path/ledger" ]; then
    find "$journal_path/ledger" -name "entries.jsonl" -type f 2>/dev/null | sort | while read -r f; do
      local count
      count="$(wc -l < "$f" | tr -d ' ')"
      local rel_path
      rel_path="${f#"$journal_path/"}"
      info "  $rel_path ($count entries)"
    done
  fi

  # Verify chain integrity
  info "Verificando integridad de la cadena..."

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
  done < <(ledger_all_entries "$journal_path")

  if [ "$chain_errors" -eq 0 ]; then
    ok "Chain integrity: UNBROKEN ($line_num entries)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    fail "Chain integrity: BROKEN ($chain_errors breaks in $line_num entries)"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
  fi

  # Show last entry
  local last_line
  last_line="$(ledger_all_entries "$journal_path" | tail -1)"
  if [ -n "$last_line" ]; then
    local last_id last_contract last_date
    last_id="$(echo "$last_line" | jq -r '.entry_id')"
    last_contract="$(echo "$last_line" | jq -r '.contract_id')"
    last_date="$(echo "$last_line" | jq -r '.recorded_at')"
    info "Último entry: $last_id ($last_contract) @ $last_date"
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
    echo "  Journal listo para bundles y ledger."
  fi
  echo ""
}

# ─── Usage ───────────────────────────────────────────────────

usage() {
  cat <<'EOF'
ev-setup.sh — Evidence Journal Setup & Verification

Usage:
  ev-setup.sh <JOURNAL_PATH>
  ev-setup.sh --check-only <JOURNAL_PATH>
  ev-setup.sh --init <JOURNAL_PATH>

Options:
  --check-only   Solo verificar, no crear nada
  --init         Crear estructura faltante (bundles/, ledger/, git init)

Examples:
  ev-setup.sh ~/GitHub/sentinels-hub/sentinels-agents-journal
  ev-setup.sh --check-only ~/journals/my-journal
  ev-setup.sh --init ~/journals/new-journal

Checks:
  1. Dependencias: sha256sum/shasum, jq, git, python3
  2. Estructura: bundles/, ledger/
  3. Ledger: entries, chain integrity
  4. Git: repo, remote, working tree

Requires:
  sha256sum or shasum, jq, python3, git
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
    echo -e "${BOLD}║   Evidence Journal Setup — CHECK ONLY             ║${NC}"
  elif [ "$INIT_MODE" = true ]; then
    echo -e "${BOLD}║   Evidence Journal Setup — INIT                   ║${NC}"
  else
    echo -e "${BOLD}║   Evidence Journal Setup — Sentinels Protocol     ║${NC}"
  fi
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"

  check_dependencies

  for journal_path in "${journal_paths[@]}"; do
    check_journal_structure "$journal_path"
    check_ledger_state "$journal_path"
    check_git "$journal_path"
  done

  print_report

  if [ "$CHECKS_FAILED" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
