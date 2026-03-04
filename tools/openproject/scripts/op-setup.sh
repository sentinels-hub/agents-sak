#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# op-setup.sh — OpenProject Setup & Verification for Sentinels
# ─────────────────────────────────────────────────────────────
# Verifica que OP esté configurado para orquestación de agentes:
#   1. Conectividad y autenticación
#   2. Custom fields de orquestación (solo verifica, no crea)
#   3. Status & types (21 statuses, 7 types)
#   4. Saved queries por agente (crea si no existen)
#   5. Project-level custom fields (7 campos de proyecto)
#   6. Permisos de proyecto
#   7. Genera reporte de estado
#
# Idempotente: ejecutar N veces no rompe nada.
#
# Requiere:
#   OPENPROJECT_URL="https://sentinels.openproject.com"
#   OPENPROJECT_API_TOKEN="xxxx"
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/op-core.sh"

# ─── Output helpers ───────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}[OK]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "  ${CYAN}[INFO]${NC} $*"; }
section() { echo -e "\n${BOLD}═══ $* ═══${NC}"; }

# Counters for final report
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0
QUERIES_CREATED=0
QUERIES_EXISTED=0

# Dry-run mode
DRY_RUN=false

# ─── 1. Connection & Auth ─────────────────────────────────────

check_connection() {
  section "1. Conectividad y Autenticación"

  # Network
  local host
  host="$(echo "$OPENPROJECT_URL" | sed -E 's|^https?://||; s|[:/].*||' 2>/dev/null)"
  if curl -sS --connect-timeout 5 --max-time 10 -o /dev/null "$OPENPROJECT_URL" 2>/dev/null; then
    ok "Red: $host accesible"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    fail "Red: no se puede alcanzar $host"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    return 1
  fi

  # Auth
  local me_json
  if me_json="$(api_try GET "/api/v3/users/me")"; then
    local user_name user_admin
    user_name="$(echo "$me_json" | jq -r '.name // "?"')"
    user_admin="$(echo "$me_json" | jq -r '.admin // false')"
    ok "Auth: $user_name (admin: $user_admin)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))

    if [ "$user_admin" != "true" ]; then
      warn "El usuario no es admin — no podrá crear custom fields desde la UI"
      CHECKS_WARNED=$((CHECKS_WARNED + 1))
    fi
  else
    fail "Auth: token inválido o sin permisos"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    return 1
  fi
}

# ─── 2. Custom Fields Verification ────────────────────────────

ORCHESTRATION_FIELDS=(
  "Difficulty:list:Trivial,Easy,Medium,Hard,Expert"
  "Specialization:list:Frontend,Backend,Full-stack,Security,QA,DevOps,Compliance,Documentation"
  "Agent Assigned:list:@jarvis,@inception,@gtd,@morpheus,@agent-smith,@oracle,@pepper,@ariadne"
  "Tech Stack:text:"
  "Automation Level:list:Full,Supervised,Human-required"
  "Gate Current:list:G0,G1,G2,G3,G4,G5,G6,G7,G8,G9"
)

TRACEABILITY_FIELDS=(
  "Contract ID:text:"
  "Github:text:"
  "Github Commit:text:"
  "Evidence URL:text:"
  "Evidence SHA256:text:"
  "Ledger Entry:text:"
)

check_custom_fields() {
  local project_ref="$1"
  section "2. Custom Fields — Proyecto: $project_ref"

  local types_json type_id
  types_json="$(api_try GET "/api/v3/projects/$project_ref/types" 2>/dev/null)" || {
    fail "No se pueden obtener los tipos del proyecto $project_ref"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    return 1
  }

  type_id="$(echo "$types_json" | jq -r '._embedded.elements[0].id // empty')"
  if [ -z "$type_id" ]; then
    fail "No se encontraron tipos en el proyecto"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    return 1
  fi

  # Populate field cache (from op-core.sh) — this also caches allowedValues
  _populate_field_cache "$project_ref" "$type_id"

  local cache_path
  cache_path="$(_field_cache_path)"

  info "Verificando campos de orquestación..."
  local missing_fields=()
  for field_spec in "${ORCHESTRATION_FIELDS[@]}"; do
    local field_name field_type field_values
    field_name="$(echo "$field_spec" | cut -d: -f1)"
    field_type="$(echo "$field_spec" | cut -d: -f2)"
    field_values="$(echo "$field_spec" | cut -d: -f3)"

    local found_key
    found_key="$(resolve_field "$project_ref" "$type_id" "$field_name")"

    if [ -n "$found_key" ]; then
      ok "$field_name → $found_key ($field_type)"
      CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
      fail "$field_name → NO ENCONTRADO"
      missing_fields+=("$field_name|$field_type|$field_values")
      CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
  done

  info "Verificando campos de trazabilidad..."
  for field_spec in "${TRACEABILITY_FIELDS[@]}"; do
    local field_name
    field_name="$(echo "$field_spec" | cut -d: -f1)"

    local found_key
    found_key="$(resolve_field "$project_ref" "$type_id" "$field_name")"

    if [ -n "$found_key" ]; then
      ok "$field_name → $found_key"
      CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
      warn "$field_name → no encontrado (puede no estar habilitado en este proyecto)"
      CHECKS_WARNED=$((CHECKS_WARNED + 1))
    fi
  done

  # Print manual setup instructions for missing fields
  if [ ${#missing_fields[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}────────────────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}ACCIÓN REQUERIDA: Crear custom fields en Admin UI${NC}"
    echo -e "  ${YELLOW}────────────────────────────────────────────────${NC}"
    echo ""
    echo "  La API de OpenProject NO permite crear custom fields."
    echo "  Ir a: Administration → Custom fields → Work packages → + Custom field"
    echo ""

    for mf in "${missing_fields[@]}"; do
      local mf_name mf_type mf_values
      mf_name="$(echo "$mf" | cut -d'|' -f1)"
      mf_type="$(echo "$mf" | cut -d'|' -f2)"
      mf_values="$(echo "$mf" | cut -d'|' -f3)"

      echo -e "  ${BOLD}$mf_name${NC}"
      echo "    Format: $mf_type"
      if [ -n "$mf_values" ]; then
        echo "    Possible values: $mf_values"
      fi
      echo "    Enabled for types: Task, User story, Feature, Epic, Bug"
      echo "    Projects: All (o seleccionar proyectos Sentinels)"
      echo ""
    done
  fi

  # Export field mappings for query creation
  FIELD_MAPPINGS_JSON="$(python3 -c "
import json
try:
    cache = json.load(open('$cache_path'))
    entry = cache.get('${project_ref}-${type_id}', {})
    mappings = {name: info['key'] for name, info in entry.get('fields', {}).items()}
    print(json.dumps(mappings))
except:
    print('{}')
" 2>/dev/null || echo "{}")"
}

# ─── 3. Status & Types Verification ──────────────────────────

# Full list of 21 Sentinels statuses (from status-workflow.md)
EXPECTED_STATUSES=(
  "New"
  "Ready"
  "In specification"
  "Specified"
  "Confirmed"
  "To be scheduled"
  "Scheduled"
  "In progress"
  "Developed"
  "In security analysis"
  "In review"
  "Verification"
  "In testing"
  "Tested"
  "In deployment"
  "Deployed"
  "On hold"
  "Test failed"
  "Rejected"
  "Done"
  "Closed"
)

# Full list of 7 Sentinels WP types (from work-packages.md)
EXPECTED_TYPES=(
  "Epic"
  "Feature"
  "User story"
  "Task"
  "Bug"
  "Incident Story"
  "Milestone"
)

check_statuses_and_types() {
  local project_ref="$1"
  section "3. Status & Types — Proyecto: $project_ref"

  # ── Verify statuses ──
  info "Verificando statuses (${#EXPECTED_STATUSES[@]} esperados)..."

  # Fetch all statuses from OP (cached by op-core.sh)
  _populate_status_cache 2>/dev/null || true

  local missing_statuses=()
  for status_name in "${EXPECTED_STATUSES[@]}"; do
    local sid
    sid="$(resolve_status_id "$status_name" 2>/dev/null)"
    if [ -n "$sid" ]; then
      CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
      missing_statuses+=("$status_name")
      CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
  done

  if [ ${#missing_statuses[@]} -eq 0 ]; then
    ok "Todos los ${#EXPECTED_STATUSES[@]} statuses encontrados"
  else
    local found_count=$((${#EXPECTED_STATUSES[@]} - ${#missing_statuses[@]}))
    warn "Statuses: $found_count/${#EXPECTED_STATUSES[@]} encontrados"
    for ms in "${missing_statuses[@]}"; do
      fail "Status faltante: $ms"
    done
    echo ""
    echo -e "  ${YELLOW}Crear statuses en: Administration → Work packages → Status${NC}"
  fi

  # ── Verify types ──
  info "Verificando tipos (${#EXPECTED_TYPES[@]} esperados)..."

  local types_json
  types_json="$(api_try GET "/api/v3/projects/$project_ref/types" 2>/dev/null)" || {
    fail "No se pueden obtener los tipos del proyecto"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    return 1
  }

  local available_types
  available_types="$(echo "$types_json" | jq -r '._embedded.elements[].name' 2>/dev/null || echo "")"

  local missing_types=()
  for type_name in "${EXPECTED_TYPES[@]}"; do
    if echo "$available_types" | grep -qxF "$type_name"; then
      CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
      missing_types+=("$type_name")
      CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
  done

  if [ ${#missing_types[@]} -eq 0 ]; then
    ok "Todos los ${#EXPECTED_TYPES[@]} tipos encontrados"
  else
    local found_count=$((${#EXPECTED_TYPES[@]} - ${#missing_types[@]}))
    warn "Tipos: $found_count/${#EXPECTED_TYPES[@]} encontrados"
    for mt in "${missing_types[@]}"; do
      fail "Tipo faltante: $mt"
    done
    echo ""
    echo -e "  ${YELLOW}Crear tipos en: Administration → Work packages → Types${NC}"
    echo -e "  ${YELLOW}Luego habilitar en: Project settings → Modules → Work packages → Types${NC}"
  fi
}

# ─── 4. Saved Queries ─────────────────────────────────────────

create_agent_queries() {
  local project_ref="$1"
  section "4. Saved Queries — Proyecto: $project_ref"

  local project_json project_id
  project_json="$(api_try GET "/api/v3/projects/$project_ref" 2>/dev/null)" || {
    fail "No se puede acceder al proyecto $project_ref"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    return 1
  }
  project_id="$(echo "$project_json" | jq -r '.id')"

  # Get existing queries
  local existing_queries
  existing_queries="$(api_try GET "/api/v3/projects/$project_ref/queries" 2>/dev/null)" || {
    existing_queries="$(api_try GET "/api/v3/queries?filters=%5B%7B%22project%22%3A%7B%22operator%22%3A%22%3D%22%2C%22values%22%3A%5B%22$project_id%22%5D%7D%7D%5D" 2>/dev/null)" || {
      warn "No se pueden listar queries existentes — se intentará crear todas"
      existing_queries='{"_embedded":{"elements":[]}}'
      CHECKS_WARNED=$((CHECKS_WARNED + 1))
    }
  }

  local existing_names
  existing_names="$(echo "$existing_queries" | jq -r '._embedded.elements[]?.name // empty' 2>/dev/null || echo "")"

  # Resolve IDs using cached functions from op-core.sh
  info "Resolviendo IDs de estados y tipos..."

  local status_new status_in_spec status_in_progress status_developed
  local status_in_review status_in_security status_on_hold status_deployed
  local status_verification status_test_failed status_scheduled
  local type_task type_user_story type_feature

  status_new="$(resolve_status_id "New")"
  status_in_spec="$(resolve_status_id "In specification")"
  status_in_progress="$(resolve_status_id "In progress")"
  status_developed="$(resolve_status_id "Developed")"
  status_in_review="$(resolve_status_id "In review")"
  status_in_security="$(resolve_status_id "In security analysis")"
  status_on_hold="$(resolve_status_id "On hold")"
  status_deployed="$(resolve_status_id "Deployed")"
  status_verification="$(resolve_status_id "Verification")"
  status_test_failed="$(resolve_status_id "Test failed")"
  status_scheduled="$(resolve_status_id "Scheduled")"

  type_task="$(resolve_type_id "$project_ref" "Task")"
  type_user_story="$(resolve_type_id "$project_ref" "User story")"
  type_feature="$(resolve_type_id "$project_ref" "Feature")"

  # Helper to create a query if it doesn't exist
  create_query() {
    local query_name="$1"
    local query_json="$2"

    if echo "$existing_names" | grep -qF "$query_name"; then
      info "Ya existe: $query_name"
      QUERIES_EXISTED=$((QUERIES_EXISTED + 1))
      return 0
    fi

    if [ "$DRY_RUN" = true ]; then
      info "[DRY-RUN] Crearía: $query_name"
      QUERIES_CREATED=$((QUERIES_CREATED + 1))
      return 0
    fi

    if api_try POST "/api/v3/projects/$project_ref/queries" "$query_json" > /dev/null 2>&1; then
      ok "Creada: $query_name"
      QUERIES_CREATED=$((QUERIES_CREATED + 1))
    else
      fail "Error creando: $query_name"
      CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
  }

  # ── @jarvis queries ──

  if [ -n "$status_new" ] && [ -n "$type_user_story" ]; then
    create_query "@jarvis — Contratos por inicializar" "$(cat <<QEOF
{
  "name": "@jarvis — Contratos por inicializar",
  "public": true,
  "filters": [
    { "type": { "operator": "=", "values": ["$type_user_story"] } },
    { "status": { "operator": "=", "values": ["$status_new"] } }
  ],
  "sortBy": [["createdAt", "asc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi

  if [ -n "$status_deployed" ]; then
    create_query "@jarvis — Pendiente de cierre" "$(cat <<QEOF
{
  "name": "@jarvis — Pendiente de cierre",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["$status_deployed"] } }
  ],
  "sortBy": [["priority", "desc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi

  # ── @inception queries ──

  if [ -n "$status_new" ] && [ -n "$type_user_story" ]; then
    create_query "@inception — Backlog sin planificar" "$(cat <<QEOF
{
  "name": "@inception — Backlog sin planificar",
  "public": true,
  "filters": [
    { "type": { "operator": "=", "values": ["$type_user_story"] } },
    { "status": { "operator": "=", "values": ["$status_new"] } }
  ],
  "sortBy": [["priority", "desc"]],
  "columns": ["id", "subject", "status", "priority", "estimatedTime", "assignee"]
}
QEOF
)"
  fi

  create_query "@inception — Sin estimación" "$(cat <<QEOF
{
  "name": "@inception — Sin estimación",
  "public": true,
  "filters": [
    { "estimatedTime": { "operator": "!*", "values": [] } },
    { "status": { "operator": "o", "values": [] } }
  ],
  "sortBy": [["type", "asc"]],
  "columns": ["id", "subject", "type", "status", "priority"]
}
QEOF
)"

  # ── @gtd queries ──

  local gtd_status_values="[]"
  if [ -n "$status_in_spec" ] && [ -n "$status_scheduled" ]; then
    gtd_status_values="[\"$status_in_spec\", \"$status_scheduled\"]"
  elif [ -n "$status_in_spec" ]; then
    gtd_status_values="[\"$status_in_spec\"]"
  fi

  if [ -n "$type_task" ]; then
    create_query "@gtd — Tareas pendientes" "$(cat <<QEOF
{
  "name": "@gtd — Tareas pendientes",
  "public": true,
  "filters": [
    { "type": { "operator": "=", "values": ["$type_task"] } },
    { "status": { "operator": "=", "values": $gtd_status_values } }
  ],
  "sortBy": [["priority", "desc"], ["estimatedTime", "asc"]],
  "columns": ["id", "subject", "status", "priority", "estimatedTime", "assignee"]
}
QEOF
)"
  fi

  if [ -n "$status_in_progress" ]; then
    create_query "@gtd — En progreso" "$(cat <<QEOF
{
  "name": "@gtd — En progreso",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["$status_in_progress"] } }
  ],
  "sortBy": [["updatedAt", "asc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi

  if [ -n "$status_on_hold" ]; then
    create_query "@gtd — Bloqueados" "$(cat <<QEOF
{
  "name": "@gtd — Bloqueados",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["$status_on_hold"] } }
  ],
  "sortBy": [["priority", "desc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi

  # ── @morpheus queries ──

  if [ -n "$status_developed" ]; then
    local morpheus_types="[]"
    if [ -n "$type_user_story" ] && [ -n "$type_feature" ]; then
      morpheus_types="[\"$type_user_story\", \"$type_feature\"]"
    elif [ -n "$type_user_story" ]; then
      morpheus_types="[\"$type_user_story\"]"
    fi

    create_query "@morpheus — Pendiente de security analysis" "$(cat <<QEOF
{
  "name": "@morpheus — Pendiente de security analysis",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["$status_developed"] } },
    { "type": { "operator": "=", "values": $morpheus_types } }
  ],
  "sortBy": [["priority", "desc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi

  # ── @agent-smith queries ──

  if [ -n "$status_in_security" ]; then
    create_query "@agent-smith — Pendiente de review" "$(cat <<QEOF
{
  "name": "@agent-smith — Pendiente de review",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["$status_in_security"] } }
  ],
  "sortBy": [["priority", "desc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi

  # ── @oracle queries ──

  if [ -n "$status_in_review" ]; then
    create_query "@oracle — Pendiente de QA" "$(cat <<QEOF
{
  "name": "@oracle — Pendiente de QA",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["$status_in_review"] } }
  ],
  "sortBy": [["priority", "desc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi

  if [ -n "$status_test_failed" ]; then
    create_query "@oracle — Test failures" "$(cat <<QEOF
{
  "name": "@oracle — Test failures",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["$status_test_failed"] } }
  ],
  "sortBy": [["updatedAt", "desc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi

  # ── @pepper queries ──

  if [ -n "$status_verification" ]; then
    create_query "@pepper — Pendiente de deploy" "$(cat <<QEOF
{
  "name": "@pepper — Pendiente de deploy",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["$status_verification"] } }
  ],
  "sortBy": [["priority", "desc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi

  # ── @ariadne queries ──

  if [ -n "$status_deployed" ]; then
    create_query "@ariadne — Pendiente de evidence" "$(cat <<QEOF
{
  "name": "@ariadne — Pendiente de evidence",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["$status_deployed"] } }
  ],
  "sortBy": [["updatedAt", "asc"]],
  "columns": ["id", "subject", "status", "priority", "assignee"]
}
QEOF
)"
  fi
}

# ─── 5. Project-Level Custom Fields ──────────────────────────

PROJECT_CUSTOM_FIELDS=(
  "Tech Stack:list:HTML/CSS,JS,Python,Bash,Docker,Terraform,Go,Rust"
  "Project Type:list:Product,Library,Governance,Infrastructure,Research"
  "Lead Agent:list:@jarvis,@inception,@gtd,@morpheus,@agent-smith,@oracle,@pepper,@ariadne"
  "Automation Tier:list:Full-auto,Semi-auto,Human-heavy"
  "Compliance Scope:list:ISO 27001,ISO 9001,ISO 42001,SOC2,ENS Alta"
  "Repository URL:text:"
  "Lighthouse Version:text:"
)

check_project_fields() {
  local project_ref="$1"
  section "5. Project Custom Fields — $project_ref"

  # Fetch project schema to see available custom fields
  local schema_json
  schema_json="$(api_try GET "/api/v3/projects/$project_ref/schema" 2>/dev/null)" || {
    warn "No se puede obtener el schema del proyecto (puede requerir admin)"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
    return 0
  }

  # Extract available custom field names from schema
  local cf_names
  cf_names="$(echo "$schema_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for key, val in data.items():
    if key.startswith('customField'):
        name = val.get('name', '')
        if name:
            print(name)
" 2>/dev/null || echo "")"

  local missing_pf=()
  for field_spec in "${PROJECT_CUSTOM_FIELDS[@]}"; do
    local field_name field_type field_values
    field_name="$(echo "$field_spec" | cut -d: -f1)"
    field_type="$(echo "$field_spec" | cut -d: -f2)"
    field_values="$(echo "$field_spec" | cut -d: -f3)"

    if echo "$cf_names" | grep -qxF "$field_name"; then
      ok "Proyecto CF: $field_name ($field_type)"
      CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
      fail "Proyecto CF: $field_name → NO ENCONTRADO"
      missing_pf+=("$field_name|$field_type|$field_values")
      CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
  done

  if [ ${#missing_pf[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}────────────────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}ACCIÓN REQUERIDA: Crear custom fields de proyecto${NC}"
    echo -e "  ${YELLOW}────────────────────────────────────────────────${NC}"
    echo ""
    echo "  Ir a: Administration → Custom fields → Projects → + Custom field"
    echo ""

    for mf in "${missing_pf[@]}"; do
      local mf_name mf_type mf_values
      mf_name="$(echo "$mf" | cut -d'|' -f1)"
      mf_type="$(echo "$mf" | cut -d'|' -f2)"
      mf_values="$(echo "$mf" | cut -d'|' -f3)"

      echo -e "  ${BOLD}$mf_name${NC}"
      echo "    Format: $mf_type"
      if [ -n "$mf_values" ]; then
        echo "    Possible values: $mf_values"
      fi
      echo ""
    done
  fi
}

# ─── 6. Project Permissions ───────────────────────────────────

check_project_permissions() {
  local project_ref="$1"
  section "6. Permisos — Proyecto: $project_ref"

  if form_json="$(api_try POST "/api/v3/projects/$project_ref/work_packages/form" '{}' 2>/dev/null)"; then
    ok "Crear Work Packages: permitido"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    fail "Crear Work Packages: sin permiso"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
  fi

  if api_try GET "/api/v3/projects/$project_ref/versions" > /dev/null 2>&1; then
    ok "Listar Versiones: permitido"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "Listar Versiones: sin acceso"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
  fi

  if api_try POST "/api/v3/queries/form" '{"name":"_test_permission_check"}' > /dev/null 2>&1; then
    ok "Crear Queries: permitido"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "Crear Queries: puede requerir permisos adicionales"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
  fi
}

# ─── 7. Final Report ─────────────────────────────────────────

print_report() {
  section "REPORTE FINAL"

  if [ "$DRY_RUN" = true ]; then
    echo -e "\n  ${CYAN}${BOLD}MODO DRY-RUN — no se han realizado cambios${NC}\n"
  fi

  echo ""
  echo -e "  ${GREEN}Checks OK:${NC}       $CHECKS_PASSED"
  echo -e "  ${RED}Checks FAIL:${NC}     $CHECKS_FAILED"
  echo -e "  ${YELLOW}Checks WARN:${NC}     $CHECKS_WARNED"
  echo -e "  ${CYAN}Queries creadas:${NC} $QUERIES_CREATED"
  echo -e "  ${DIM}Queries existían:${NC} $QUERIES_EXISTED"
  echo ""

  if [ "$CHECKS_FAILED" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}Estado: SETUP INCOMPLETO${NC}"
    echo "  Revisa los items marcados con [FAIL] arriba."
  elif [ "$CHECKS_WARNED" -gt 0 ]; then
    echo -e "  ${YELLOW}${BOLD}Estado: SETUP PARCIAL${NC}"
    echo "  Funcional pero con advertencias. Revisa items [WARN]."
  else
    echo -e "  ${GREEN}${BOLD}Estado: SETUP COMPLETO${NC}"
    echo "  OpenProject está listo para orquestación de agentes."
  fi
  echo ""
}

# ─── Usage ────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
op-setup.sh — Setup y verificación de OpenProject para Sentinels

Usage:
  op-setup.sh <PROJECT_IDENTIFIER> [PROJECT_2] [PROJECT_N]
  op-setup.sh --check-only <PROJECT_IDENTIFIER>
  op-setup.sh --queries-only <PROJECT_IDENTIFIER>
  op-setup.sh --dry-run <PROJECT_IDENTIFIER>

Options:
  --check-only     Solo verificar, no crear nada
  --queries-only   Solo crear/verificar queries
  --dry-run        Mostrar qué haría sin ejecutar cambios

Examples:
  op-setup.sh sentinels-hub
  op-setup.sh sentinels-hub agents-sak sentinels-lighthouse
  op-setup.sh --dry-run sentinels-hub
  op-setup.sh --check-only sentinels-hub

Env vars:
  OPENPROJECT_URL           URL de OpenProject (requerido)
  OPENPROJECT_API_TOKEN     Token API (requerido)
EOF
}

# ─── Main ─────────────────────────────────────────────────────

main() {
  local check_only=false
  local queries_only=false
  local projects=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --check-only)   check_only=true; shift ;;
      --queries-only) queries_only=true; shift ;;
      --dry-run)      DRY_RUN=true; shift ;;
      -h|--help)      usage; exit 0 ;;
      *)              projects+=("$1"); shift ;;
    esac
  done

  if [ ${#projects[@]} -eq 0 ]; then
    usage
    exit 1
  fi

  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${BOLD}║   OpenProject Setup — DRY RUN                    ║${NC}"
  else
    echo -e "${BOLD}║   OpenProject Setup — Sentinels Orchestration    ║${NC}"
  fi
  echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"

  require_env
  check_connection || exit 1

  FIELD_MAPPINGS_JSON="{}"

  for project in "${projects[@]}"; do
    check_custom_fields "$project"
    check_statuses_and_types "$project"

    if [ "$check_only" = false ]; then
      create_agent_queries "$project"
    fi

    check_project_fields "$project"

    if [ "$queries_only" = false ] && [ "$check_only" = false ]; then
      check_project_permissions "$project"
    fi
  done

  print_report
}

main "$@"
