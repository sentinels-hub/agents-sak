#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# sak-cli.sh — Agents SAK Unified CLI
# ─────────────────────────────────────────────────────────────
# Punto de entrada único para todas las herramientas SAK.
#
# Usage:
#   sak op ...        → OpenProject CLI
#   sak gh ...        → GitHub CLI
#   sak ev ...        → Evidence CLI
#   sak co ...        → Compliance CLI
#   sak trace ...     → E2E Traceability verification
#   sak gates ...     → Gate validation
#   sak metrics ...   → Analytics & metrics
#   sak version       → Version de cada tool
#   sak status <CTR>  → Resumen rápido cross-tool
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sak-core.sh"

SAK_VERSION="0.9.0"

# ─── Tool paths ──────────────────────────────────────────────

OP_CLI="$SCRIPT_DIR/../openproject/scripts/op-cli.sh"
GH_CLI="$SCRIPT_DIR/../github/scripts/gh-cli.sh"
EV_CLI="$SCRIPT_DIR/../evidence/scripts/ev-cli.sh"
CO_CLI="$SCRIPT_DIR/../compliance/scripts/co-cli.sh"
SAK_TRACE="$SCRIPT_DIR/sak-trace.sh"
SAK_GATES="$SCRIPT_DIR/sak-gates.sh"
SAK_METRICS="$SCRIPT_DIR/sak-metrics.sh"

# ─── Version ─────────────────────────────────────────────────

cmd_version() {
  echo ""
  echo -e "${BOLD}Agents SAK v${SAK_VERSION}${NC}"
  echo ""
  echo "  Tools:"

  if [ -f "$OP_CLI" ]; then
    echo -e "    ${GREEN}[OK]${NC} openproject  (op-cli.sh)"
  else
    echo -e "    ${RED}[--]${NC} openproject  (not found)"
  fi

  if [ -f "$GH_CLI" ]; then
    echo -e "    ${GREEN}[OK]${NC} github       (gh-cli.sh)"
  else
    echo -e "    ${RED}[--]${NC} github       (not found)"
  fi

  if [ -f "$EV_CLI" ]; then
    echo -e "    ${GREEN}[OK]${NC} evidence     (ev-cli.sh)"
  else
    echo -e "    ${RED}[--]${NC} evidence     (not found)"
  fi

  if [ -f "$CO_CLI" ]; then
    echo -e "    ${GREEN}[OK]${NC} compliance   (co-cli.sh)"
  else
    echo -e "    ${RED}[--]${NC} compliance   (not found)"
  fi

  echo ""
  echo "  Cross-tool:"

  if [ -f "$SAK_TRACE" ]; then
    echo -e "    ${GREEN}[OK]${NC} trace        (sak-trace.sh)"
  else
    echo -e "    ${RED}[--]${NC} trace        (not found)"
  fi

  if [ -f "$SAK_GATES" ]; then
    echo -e "    ${GREEN}[OK]${NC} gates        (sak-gates.sh)"
  else
    echo -e "    ${RED}[--]${NC} gates        (not found)"
  fi

  if [ -f "$SAK_METRICS" ]; then
    echo -e "    ${GREEN}[OK]${NC} metrics      (sak-metrics.sh)"
  else
    echo -e "    ${RED}[--]${NC} metrics      (not found)"
  fi

  echo ""
}

# ─── Status ──────────────────────────────────────────────────

cmd_status() {
  local contract_id="$1"
  local journal_path=""

  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --journal-path) journal_path="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  journal_path="$(journal_path_resolve "$journal_path")" || exit 1
  contract_id_validate "$contract_id" || exit 1

  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   SAK Status — ${contract_id}${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"

  # Contract format
  section "Contract"
  ok "Contract ID: $contract_id"

  # Evidence: bundles
  section "Evidence"
  local bundle_count=0
  if [ -d "$journal_path/bundles" ]; then
    bundle_count="$(find "$journal_path/bundles" -name "bundle-manifest.json" -type f 2>/dev/null | xargs grep -l "\"contract_id\":.*\"$contract_id\"" 2>/dev/null | wc -l | tr -d ' ')"
  fi
  if [ "$bundle_count" -gt 0 ]; then
    ok "Bundles: $bundle_count"
  else
    warn "Bundles: 0"
  fi

  # Evidence: ledger
  local ledger_count=0
  if [ -d "$journal_path/ledger" ]; then
    ledger_count="$(find "$journal_path/ledger" -name "entries.jsonl" -type f 2>/dev/null -exec grep -c "\"$contract_id\"" {} + 2>/dev/null | awk -F: '{s+=$NF}END{print s+0}')"
  fi
  if [ "$ledger_count" -gt 0 ]; then
    ok "Ledger entries: $ledger_count"
  else
    warn "Ledger entries: 0"
  fi

  # Compliance: audit trail
  section "Compliance"
  local audit_file="$journal_path/audit/$contract_id/audit-trail.jsonl"
  if [ -f "$audit_file" ]; then
    local audit_count
    audit_count="$(wc -l < "$audit_file" | tr -d ' ')"
    ok "Audit trail: $audit_count entries"

    local gates_covered
    gates_covered="$(jq -r '.gate' "$audit_file" 2>/dev/null | sort -u | tr '\n' ' ')"
    info "Gates cubiertos: $gates_covered"
  else
    warn "Audit trail: no encontrado"
  fi

  echo ""
}

# ─── Usage ───────────────────────────────────────────────────

usage() {
  cat <<EOF
sak-cli.sh — Agents SAK Unified CLI v${SAK_VERSION}

Usage:
  sak-cli.sh <tool> <command> [args...]

Tools:
  op <args...>              OpenProject CLI (op-cli.sh)
  gh <args...>              GitHub CLI (gh-cli.sh)
  ev <args...>              Evidence CLI (ev-cli.sh)
  co <args...>              Compliance CLI (co-cli.sh)

Cross-tool:
  trace <args...>           E2E traceability verification (sak-trace.sh)
  gates <args...>           Gate validation (sak-gates.sh)
  metrics <args...>         Analytics & metrics (sak-metrics.sh)

Commands:
  version                   Show version and tool status
  status <CTR> [--journal-path PATH]
                            Quick cross-tool status for a contract

Examples:
  sak-cli.sh version
  sak-cli.sh op wp list sentinels-hub
  sak-cli.sh gh branch validate
  sak-cli.sh ev bundle list /path/to/journal
  sak-cli.sh co audit list --contract CTR-agents-sak-20260304 --journal-path /path
  sak-cli.sh trace CTR-agents-sak-20260304 --journal-path /path
  sak-cli.sh gates status CTR-agents-sak-20260304 --journal-path /path
  sak-cli.sh metrics summary CTR-agents-sak-20260304 --journal-path /path
  sak-cli.sh status CTR-agents-sak-20260304 --journal-path /path
EOF
}

# ─── Main router ─────────────────────────────────────────────

main() {
  if [ $# -eq 0 ]; then
    usage
    exit 0
  fi

  local tool="$1"
  shift

  case "$tool" in
    op)
      if [ ! -f "$OP_CLI" ]; then
        echo "ERROR: op-cli.sh no encontrado en $OP_CLI" >&2
        exit 1
      fi
      exec bash "$OP_CLI" "$@"
      ;;
    gh)
      if [ ! -f "$GH_CLI" ]; then
        echo "ERROR: gh-cli.sh no encontrado en $GH_CLI" >&2
        exit 1
      fi
      exec bash "$GH_CLI" "$@"
      ;;
    ev)
      if [ ! -f "$EV_CLI" ]; then
        echo "ERROR: ev-cli.sh no encontrado en $EV_CLI" >&2
        exit 1
      fi
      exec bash "$EV_CLI" "$@"
      ;;
    co)
      if [ ! -f "$CO_CLI" ]; then
        echo "ERROR: co-cli.sh no encontrado en $CO_CLI" >&2
        exit 1
      fi
      exec bash "$CO_CLI" "$@"
      ;;
    trace)
      if [ ! -f "$SAK_TRACE" ]; then
        echo "ERROR: sak-trace.sh no encontrado en $SAK_TRACE" >&2
        exit 1
      fi
      exec bash "$SAK_TRACE" "$@"
      ;;
    gates)
      if [ ! -f "$SAK_GATES" ]; then
        echo "ERROR: sak-gates.sh no encontrado en $SAK_GATES" >&2
        exit 1
      fi
      exec bash "$SAK_GATES" "$@"
      ;;
    metrics)
      if [ ! -f "$SAK_METRICS" ]; then
        echo "ERROR: sak-metrics.sh no encontrado en $SAK_METRICS" >&2
        exit 1
      fi
      exec bash "$SAK_METRICS" "$@"
      ;;
    version)
      cmd_version
      ;;
    status)
      if [ $# -eq 0 ]; then
        echo "ERROR: se requiere contract_id" >&2
        echo "Usage: sak-cli.sh status <CTR> [--journal-path PATH]" >&2
        exit 1
      fi
      cmd_status "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "ERROR: tool desconocida: $tool" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
