#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# sak-core.sh — Funciones compartidas para Agents SAK
# ─────────────────────────────────────────────────────────────
# Capa cross-tool: timestamps, output helpers, validadores,
# require checks. Las tools individuales (ev, co, gh, op)
# pueden importar este módulo para eliminar duplicados.
#
# Importar con:
#   _SAK_CORE="$(cd "$SCRIPT_DIR/../../scripts" 2>/dev/null && pwd)/sak-core.sh"
#   if [ -f "$_SAK_CORE" ]; then source "$_SAK_CORE"; fi
# ─────────────────────────────────────────────────────────────

# Guard: solo cargar una vez
[ -n "${_SAK_CORE_LOADED:-}" ] && return 0
_SAK_CORE_LOADED=1

# ─── Timestamps ────────────────────────────────────────────

# ISO 8601 UTC timestamp
iso_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Compact timestamp for IDs: 20260304T143000Z
compact_timestamp() {
  date -u +"%Y%m%dT%H%M%SZ"
}

# Numeric timestamp for entry IDs: 20260304143000
numeric_timestamp() {
  date -u +"%Y%m%d%H%M%S"
}

# ─── Output helpers ────────────────────────────────────────

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

# ─── Require checks ───────────────────────────────────────

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd no está instalado" >&2
    return 1
  fi
}

require_jq()      { require_command jq; }
require_python3() { require_command python3; }
require_git()     { require_command git; }

# ─── Path utilities ───────────────────────────────────────

# Detect agents-sak root directory
sak_root() {
  local dir="$1"
  [ -z "$dir" ] && dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  # Walk up looking for CLAUDE.md or tools/ dir
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/CLAUDE.md" ] && [ -d "$dir/tools" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# ─── Validators ───────────────────────────────────────────

# Validate contract ID format: CTR-<project>-<YYYYMMDD>
contract_id_validate() {
  local cid="$1"
  if [[ "$cid" =~ ^CTR-[a-zA-Z0-9_-]+-[0-9]{8}$ ]]; then
    return 0
  else
    echo "ERROR: contract_id inválido: $cid" >&2
    echo "  Formato: CTR-<project>-<YYYYMMDD>" >&2
    echo "  Ejemplo: CTR-agents-sak-20260304" >&2
    return 1
  fi
}

# ─── Journal path resolution ─────────────────────────────

# Resolve journal path: env > param > default
journal_path_resolve() {
  local param_path="$1"
  local resolved=""

  # Priority 1: explicit parameter
  if [ -n "$param_path" ]; then
    resolved="$param_path"
  # Priority 2: environment variable
  elif [ -n "$JOURNAL_PATH" ]; then
    resolved="$JOURNAL_PATH"
  # Priority 3: default
  else
    echo "ERROR: journal path no especificado" >&2
    echo "  Usa --journal-path <PATH> o export JOURNAL_PATH=<PATH>" >&2
    return 1
  fi

  # Verify it exists
  if [ ! -d "$resolved" ]; then
    echo "ERROR: journal path no encontrado: $resolved" >&2
    return 1
  fi

  echo "$resolved"
}
