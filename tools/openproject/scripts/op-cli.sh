#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# op-cli.sh — CLI modular para OpenProject (Sentinels)
# ─────────────────────────────────────────────────────────────
# Complementa openproject-sync.sh con operaciones de
# orquestación: queries, relations, WP listing, batch ops.
#
# Requiere:
#   OPENPROJECT_URL="https://sentinels.openproject.com"
#   OPENPROJECT_API_TOKEN="xxxx"
#   jq, python3
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/op-core.sh"

# ═══════════════════════════════════════════════════════════════
# COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── query list ───────────────────────────────────────────────

cmd_query_list() {
  local project_ref="${1:-}"

  if [ -n "$project_ref" ]; then
    local project_json project_id
    project_json="$(api GET "/api/v3/projects/$project_ref")"
    project_id="$(echo "$project_json" | jq -r '.id')"
    local encoded_filter
    encoded_filter="$(urlencode "[{\"project\":{\"operator\":\"=\",\"values\":[\"$project_id\"]}}]")"
    api GET "/api/v3/queries?filters=$encoded_filter&pageSize=100" | jq -r '
      ._embedded.elements[] |
      "  \(.id)\t\(.name)\t\(if .public then "public" else "private" end)"
    '
  else
    api GET "/api/v3/queries?pageSize=100" | jq -r '
      ._embedded.elements[] |
      "  \(.id)\t\(.name)\t\(._links.project.title // "global")\t\(if .public then "public" else "private" end)"
    '
  fi
}

# ─── query exec ───────────────────────────────────────────────

cmd_query_exec() {
  local query_id="$1"
  local format="${2:-table}"

  local result
  result="$(api GET "/api/v3/queries/$query_id")"

  local wp_collection_href
  wp_collection_href="$(echo "$result" | jq -r '._links.results.href // empty')"

  local wps
  if [ -n "$wp_collection_href" ]; then
    wps="$(api GET "$wp_collection_href")"
  else
    wps="$result"
  fi

  local total
  total="$(echo "$wps" | jq -r '.total // 0')"

  case "$format" in
    json)
      echo "$wps" | jq '._embedded.elements'
      ;;
    ids)
      echo "$wps" | jq -r '._embedded.elements[].id'
      ;;
    table|*)
      echo "Total: $total"
      echo ""
      echo "$wps" | jq -r '
        ._embedded.elements[] |
        "  #\(.id)\t\(._links.status.title // "?")\t\(._links.priority.title // "?")\t\(.subject)"
      '
      ;;
  esac
}

# ─── query create ─────────────────────────────────────────────

cmd_query_create() {
  local project_ref="$1"
  local name="$2"
  local filters_json="$3"
  local sort_json="${4:-"[[\"priority\",\"desc\"]]"}"

  local payload
  payload="$(cat <<QEOF
{
  "name": "$name",
  "public": true,
  "filters": $filters_json,
  "sortBy": $sort_json,
  "columns": ["id", "subject", "status", "priority", "estimatedTime", "assignee"]
}
QEOF
)"

  local result
  result="$(api POST "/api/v3/projects/$project_ref/queries" "$payload")"
  local query_id
  query_id="$(echo "$result" | jq -r '.id')"
  echo "Query creada: #$query_id — $name"
}

# ─── query delete ─────────────────────────────────────────────

cmd_query_delete() {
  local query_id="$1"
  api DELETE "/api/v3/queries/$query_id" > /dev/null
  echo "Query #$query_id eliminada"
}

# ─── wp list ──────────────────────────────────────────────────

cmd_wp_list() {
  local project_ref="$1"
  shift

  local page_size=50
  local offset=1
  local filters="[]"
  local sort='[["priority","desc"]]'
  local format="table"

  while [ $# -gt 0 ]; do
    case "$1" in
      --status)     shift; filters="$(add_filter "$filters" "status" "=" "$1")"; shift ;;
      --type)       shift; filters="$(add_filter "$filters" "type" "=" "$1")"; shift ;;
      --assignee)   shift; filters="$(add_filter "$filters" "assignee" "=" "$1")"; shift ;;
      --version)    shift; filters="$(add_filter "$filters" "version" "=" "$1")"; shift ;;
      --parent)     shift; filters="$(add_filter "$filters" "parent" "=" "$1")"; shift ;;
      --updated-since) shift; filters="$(add_filter "$filters" "updatedAt" ">t-" "$1")"; shift ;;
      --sort)       shift; sort="$1"; shift ;;
      --page-size)  shift; page_size="$1"; shift ;;
      --offset)     shift; offset="$1"; shift ;;
      --format)     shift; format="$1"; shift ;;
      *)            echo "ERROR: opción desconocida: $1" >&2; return 1 ;;
    esac
  done

  local encoded_filters encoded_sort
  encoded_filters="$(urlencode "$filters")"
  encoded_sort="$(urlencode "$sort")"

  local result
  result="$(api GET "/api/v3/projects/$project_ref/work_packages?filters=$encoded_filters&sortBy=$encoded_sort&pageSize=$page_size&offset=$offset")"

  local total
  total="$(echo "$result" | jq -r '.total // 0')"

  case "$format" in
    json)
      echo "$result" | jq '._embedded.elements'
      ;;
    ids)
      echo "$result" | jq -r '._embedded.elements[].id'
      ;;
    compact)
      echo "[$total WPs — page $offset, size $page_size]"
      echo "$result" | jq -r '
        ._embedded.elements[] |
        "#\(.id) [\(._links.type.title // "?")]\t\(._links.status.title // "?")\t\(.subject)"
      '
      ;;
    table|*)
      echo "Total: $total (page $offset, size $page_size)"
      echo ""
      printf "  %-6s %-14s %-18s %-10s %s\n" "ID" "TYPE" "STATUS" "PRIORITY" "SUBJECT"
      printf "  %-6s %-14s %-18s %-10s %s\n" "──────" "──────────────" "──────────────────" "──────────" "──────────────────────────────"
      echo "$result" | jq -r '
        ._embedded.elements[] |
        "  \(.id|tostring|.[0:6])\t\(._links.type.title // "?"|.[0:14])\t\(._links.status.title // "?"|.[0:18])\t\(._links.priority.title // "?"|.[0:10])\t\(.subject)"
      '
      ;;
  esac
}

# Filter builder helper — uses cached status resolution from op-core.sh
add_filter() {
  local current="$1"
  local field="$2"
  local operator="$3"
  local value="$4"

  local resolved_value="$value"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    case "$field" in
      status)
        resolved_value="$(resolve_status_id "$value")"
        if [ -z "$resolved_value" ]; then
          echo "ERROR: status no encontrado: $value" >&2
          resolved_value="$value"
        fi
        ;;
    esac
  fi

  python3 -c "
import json,sys
filters = json.loads(sys.argv[1])
filters.append({sys.argv[2]: {'operator': sys.argv[3], 'values': [sys.argv[4]]}})
print(json.dumps(filters))
" "$current" "$field" "$operator" "$resolved_value"
}

# ─── wp get ───────────────────────────────────────────────────

cmd_wp_get() {
  local wp_id="$1"
  local format="${2:-summary}"

  local result
  result="$(api GET "/api/v3/work_packages/$wp_id")"

  case "$format" in
    json)
      echo "$result" | jq .
      ;;
    summary|*)
      echo "$result" | jq -r '"
  WP #\(.id) — \(.subject)
  Type:       \(._links.type.title // "?")
  Status:     \(._links.status.title // "?")
  Priority:   \(._links.priority.title // "?")
  Assignee:   \(._links.assignee.title // "sin asignar")
  Version:    \(._links.version.title // "sin versión")
  Parent:     \(._links.parent.title // "sin padre") (#\(._links.parent.href // "" | split("/") | last))
  Estimated:  \(.estimatedTime // "—")
  Spent:      \(.spentTime // "—")
  Progress:   \(.percentageDone // 0)%
  Created:    \(.createdAt // "?")
  Updated:    \(.updatedAt // "?")
"'
      ;;
  esac
}

# ─── relation create ─────────────────────────────────────────

cmd_relation_create() {
  local from_id="$1"
  local relation_type="$2"
  local to_id="$3"
  local description="${4:-}"
  local lag="${5:-}"

  case "$relation_type" in
    relates|blocks|blocked|precedes|follows|requires|required|duplicates|duplicated|includes|partof) ;;
    *) echo "ERROR: tipo de relación inválido: $relation_type" >&2
       echo "  Tipos válidos: relates, blocks, blocked, precedes, follows, requires, required, duplicates, duplicated, includes, partof" >&2
       return 1 ;;
  esac

  local payload
  payload="$(python3 -c "
import json,sys
data = {
    '_links': {
        'from': {'href': '/api/v3/work_packages/$from_id'},
        'to': {'href': '/api/v3/work_packages/$to_id'}
    },
    'type': '$relation_type'
}
if '$description':
    data['description'] = '$description'
if '$lag':
    data['lag'] = int('$lag')
print(json.dumps(data))
")"

  local result
  result="$(api POST "/api/v3/work_packages/$from_id/relations" "$payload")"

  local rel_id
  rel_id="$(echo "$result" | jq -r '.id')"
  echo "Relación creada: #$rel_id — WP#$from_id $relation_type WP#$to_id"
}

# ─── relation list ────────────────────────────────────────────

cmd_relation_list() {
  local wp_id="$1"
  local filter_type="${2:-}"

  local path="/api/v3/work_packages/$wp_id/relations"
  if [ -n "$filter_type" ]; then
    local encoded
    encoded="$(urlencode "[{\"type\":{\"operator\":\"=\",\"values\":[\"$filter_type\"]}}]")"
    path="$path?filters=$encoded"
  fi

  local result
  result="$(api GET "$path")"

  local total
  total="$(echo "$result" | jq -r '.total // 0')"

  echo "Relaciones de WP#$wp_id: $total"
  echo ""
  echo "$result" | jq -r '
    ._embedded.elements[] |
    "  #\(.id)\t\(.type)\t\(._links.from.title // "?") → \(._links.to.title // "?")\t\(.description // "")"
  '
}

# ─── relation check-blocked ──────────────────────────────────

cmd_relation_check_blocked() {
  local wp_id="$1"

  local result
  result="$(api GET "/api/v3/work_packages/$wp_id/relations")"

  local blocked_by
  blocked_by="$(echo "$result" | jq -r "
    ._embedded.elements[] |
    select(.type == \"blocks\" and (._links.to.href | test(\"/$wp_id$\"))) |
    ._links.from.href | split(\"/\") | last
  " 2>/dev/null || echo "")"

  if [ -z "$blocked_by" ]; then
    echo "FREE"
    return 0
  else
    echo "BLOCKED"
    echo "Bloqueado por: $blocked_by"
    return 1
  fi
}

# ─── wp set-orchestration (fixed: List fields use _links) ────

cmd_wp_set_orchestration() {
  local wp_id="$1"
  shift

  local difficulty="" specialization="" agent="" tech_stack="" automation="" gate=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --difficulty)      shift; difficulty="$1"; shift ;;
      --specialization)  shift; specialization="$1"; shift ;;
      --agent)           shift; agent="$1"; shift ;;
      --tech-stack)      shift; tech_stack="$1"; shift ;;
      --automation)      shift; automation="$1"; shift ;;
      --gate)            shift; gate="$1"; shift ;;
      *)                 echo "ERROR: opción desconocida: $1" >&2; return 1 ;;
    esac
  done

  # Get WP to find project+type for field resolution
  local wp_json
  wp_json="$(api GET "/api/v3/work_packages/$wp_id")"

  local lock_version project_id type_id
  lock_version="$(echo "$wp_json" | jq -r '.lockVersion')"
  project_id="$(echo "$wp_json" | jq -r '._links.project.href' | sed 's|.*/||')"
  type_id="$(echo "$wp_json" | jq -r '._links.type.href' | sed 's|.*/||')"

  # Resolve each field value — handles List vs Text automatically
  local fragments=()
  local errors=()

  _resolve_and_add() {
    local fname="$1"
    local fvalue="$2"
    if [ -z "$fvalue" ]; then return; fi

    local resolved
    resolved="$(resolve_field_value "$project_id" "$type_id" "$fname" "$fvalue")"

    if [[ "$resolved" == ERROR:* ]]; then
      errors+=("$fname: $resolved")
    else
      fragments+=("$resolved")
    fi
  }

  _resolve_and_add "difficulty" "$difficulty"
  _resolve_and_add "specialization" "$specialization"
  _resolve_and_add "agent assigned" "$agent"
  _resolve_and_add "tech stack" "$tech_stack"
  _resolve_and_add "automation level" "$automation"
  _resolve_and_add "gate current" "$gate"

  # Report errors
  if [ ${#errors[@]} -gt 0 ]; then
    echo "ERRORES de resolución:" >&2
    for err in "${errors[@]}"; do
      echo "  $err" >&2
    done
  fi

  if [ ${#fragments[@]} -eq 0 ]; then
    echo "ERROR: ningún campo de orquestación especificado o resuelto" >&2
    return 1
  fi

  # Build PATCH payload using build_patch_payload from op-core.sh
  local payload
  payload="$(build_patch_payload "$lock_version" "${fragments[@]}")"

  api PATCH "/api/v3/work_packages/$wp_id" "$payload" > /dev/null
  echo "WP#$wp_id actualizado con campos de orquestación"
}

# ─── wp set-orchestration-batch ──────────────────────────────

cmd_wp_set_orchestration_batch() {
  local input_file="$1"

  if [ ! -f "$input_file" ]; then
    echo "ERROR: archivo no encontrado: $input_file" >&2
    return 1
  fi

  local count=0
  local errors=0

  while IFS=$'\t' read -r wp_id difficulty specialization agent tech_stack automation gate; do
    [[ "$wp_id" =~ ^#.*$ ]] && continue
    [[ -z "$wp_id" ]] && continue

    local args=("$wp_id")
    [ -n "$difficulty" ] && [ "$difficulty" != "-" ] && args+=(--difficulty "$difficulty")
    [ -n "$specialization" ] && [ "$specialization" != "-" ] && args+=(--specialization "$specialization")
    [ -n "$agent" ] && [ "$agent" != "-" ] && args+=(--agent "$agent")
    [ -n "$tech_stack" ] && [ "$tech_stack" != "-" ] && args+=(--tech-stack "$tech_stack")
    [ -n "$automation" ] && [ "$automation" != "-" ] && args+=(--automation "$automation")
    [ -n "$gate" ] && [ "$gate" != "-" ] && args+=(--gate "$gate")

    if cmd_wp_set_orchestration "${args[@]}" 2>/dev/null; then
      count=$((count + 1))
    else
      echo "ERROR en WP#$wp_id" >&2
      errors=$((errors + 1))
    fi
  done < "$input_file"

  echo ""
  echo "Batch completado: $count actualizados, $errors errores"
}

# ─── wp list-all (with pagination) ───────────────────────────

cmd_wp_list_all() {
  local project_ref="$1"
  shift

  local page_size=100
  local offset=1
  local filters="[]"
  local total_fetched=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --status)   shift; filters="$(add_filter "$filters" "status" "=" "$1")"; shift ;;
      --type)     shift; filters="$(add_filter "$filters" "type" "=" "$1")"; shift ;;
      *)          shift ;;
    esac
  done

  local encoded_filters
  encoded_filters="$(urlencode "$filters")"

  while true; do
    local result
    result="$(api GET "/api/v3/projects/$project_ref/work_packages?filters=$encoded_filters&pageSize=$page_size&offset=$offset")"

    local total count
    total="$(echo "$result" | jq -r '.total // 0')"
    count="$(echo "$result" | jq -r '._embedded.elements | length')"

    echo "$result" | jq -r '._embedded.elements[] | "#\(.id)\t\(._links.type.title // "?")\t\(._links.status.title // "?")\t\(.subject)"'

    total_fetched=$((total_fetched + count))

    if [ "$total_fetched" -ge "$total" ] || [ "$count" -eq 0 ]; then
      break
    fi

    offset=$((offset + 1))
  done

  echo "" >&2
  echo "Total: $total_fetched WPs" >&2
}

# ─── project list ─────────────────────────────────────────────

cmd_project_list() {
  local format="${1:-table}"

  local result
  result="$(api GET "/api/v3/projects?filters=%5B%7B%22active%22%3A%7B%22operator%22%3A%22%3D%22%2C%22values%22%3A%5B%22t%22%5D%7D%7D%5D&sortBy=%5B%5B%22name%22%2C%22asc%22%5D%5D&pageSize=100")"

  local total
  total="$(echo "$result" | jq -r '.total // 0')"

  case "$format" in
    json)
      echo "$result" | jq '._embedded.elements'
      ;;
    ids)
      echo "$result" | jq -r '._embedded.elements[].identifier'
      ;;
    table|*)
      echo "Proyectos activos: $total"
      echo ""
      printf "  %-6s %-25s %-12s %s\n" "ID" "IDENTIFIER" "STATUS" "NAME"
      printf "  %-6s %-25s %-12s %s\n" "──────" "─────────────────────────" "────────────" "──────────────────────────────"
      echo "$result" | jq -r '
        ._embedded.elements[] |
        "  \(.id|tostring|.[0:6])\t\(.identifier|.[0:25])\t\(._links.status.title // "—"|.[0:12])\t\(.name)"
      '
      ;;
  esac
}

# ─── project get ──────────────────────────────────────────────

cmd_project_get() {
  local project_ref="$1"
  local format="${2:-summary}"

  local result
  result="$(api GET "/api/v3/projects/$project_ref")"

  case "$format" in
    json)
      echo "$result" | jq .
      ;;
    summary|*)
      echo "$result" | jq -r '"
  Project #\(.id) — \(.name)
  Identifier:  \(.identifier)
  Status:      \(._links.status.title // "—")
  Active:      \(.active)
  Public:      \(.public)
  Parent:      \(._links.parent.title // "sin padre")
  Created:     \(.createdAt // "?")
  Updated:     \(.updatedAt // "?")
"'
      # Show statusExplanation if present
      local explanation
      explanation="$(echo "$result" | jq -r '.statusExplanation.raw // empty')"
      if [ -n "$explanation" ]; then
        echo "  Status Explanation:"
        echo "$explanation" | sed 's/^/    /'
        echo ""
      fi

      # Show custom fields
      echo "  Custom Fields:"
      echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for key, val in sorted(data.items()):
    if key.startswith('customField') and val:
        print(f'    {key}: {val}')
" 2>/dev/null || true
      ;;
  esac
}

# ─── project set ──────────────────────────────────────────────

cmd_project_set() {
  local project_ref="$1"
  shift

  local status="" explanation=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --status)       shift; status="$1"; shift ;;
      --explanation)  shift; explanation="$1"; shift ;;
      *)              echo "ERROR: opción desconocida: $1" >&2; return 1 ;;
    esac
  done

  local payload
  payload="$(python3 -c "
import json
data = {}
links = {}
status = '$status'
explanation = '''$explanation'''

if status:
    valid = ['on_track', 'at_risk', 'in_trouble']
    if status not in valid:
        raise ValueError(f'Status inválido: {status}. Válidos: {valid}')
    links['status'] = {'href': f'/api/v3/project_statuses/{status}'}

if explanation:
    data['statusExplanation'] = {'raw': explanation, 'format': 'markdown'}

if links:
    data['_links'] = links

print(json.dumps(data))
")"

  if [ "$payload" = "{}" ]; then
    echo "ERROR: especifica al menos --status o --explanation" >&2
    return 1
  fi

  api PATCH "/api/v3/projects/$project_ref" "$payload" > /dev/null
  echo "Proyecto $project_ref actualizado"
}

# ─── project versions ────────────────────────────────────────

cmd_project_versions() {
  local project_ref="$1"
  local format="${2:-table}"

  local result
  result="$(api GET "/api/v3/projects/$project_ref/versions")"

  local total
  total="$(echo "$result" | jq -r '.total // 0')"

  case "$format" in
    json)
      echo "$result" | jq '._embedded.elements'
      ;;
    table|*)
      echo "Versiones: $total"
      echo ""
      printf "  %-6s %-20s %-12s %s\n" "ID" "NAME" "STATUS" "START DATE"
      printf "  %-6s %-20s %-12s %s\n" "──────" "────────────────────" "────────────" "──────────"
      echo "$result" | jq -r '
        ._embedded.elements[] |
        "  \(.id|tostring|.[0:6])\t\(.name|.[0:20])\t\(.status // "—"|.[0:12])\t\(.startDate // "—")"
      '
      ;;
  esac
}

# ─── project members ─────────────────────────────────────────

cmd_project_members() {
  local project_ref="$1"

  # Get project ID
  local project_json project_id
  project_json="$(api GET "/api/v3/projects/$project_ref")"
  project_id="$(echo "$project_json" | jq -r '.id')"

  local encoded_filter
  encoded_filter="$(urlencode "[{\"project\":{\"operator\":\"=\",\"values\":[\"$project_id\"]}}]")"

  local result
  result="$(api GET "/api/v3/memberships?filters=$encoded_filter&pageSize=100")"

  local total
  total="$(echo "$result" | jq -r '.total // 0')"

  echo "Miembros de $project_ref: $total"
  echo ""
  echo "$result" | jq -r '
    ._embedded.elements[] |
    "  \(._links.principal.title // "?")\t\([._links.roles[]?.title] | join(", "))"
  '
}

# ═══════════════════════════════════════════════════════════════
# USAGE & ROUTER
# ═══════════════════════════════════════════════════════════════

usage() {
  cat <<'EOF'
op-cli.sh — CLI modular para OpenProject (Sentinels)

Queries:
  op-cli.sh query list [PROJECT_REF]
  op-cli.sh query exec <QUERY_ID> [table|json|ids]
  op-cli.sh query create <PROJECT_REF> <NAME> <FILTERS_JSON> [SORT_JSON]
  op-cli.sh query delete <QUERY_ID>

Work Packages:
  op-cli.sh wp list <PROJECT_REF> [--status NAME] [--type NAME] [--assignee ID]
                                   [--version ID] [--parent ID]
                                   [--updated-since DAYS] [--sort JSON]
                                   [--page-size N] [--offset N]
                                   [--format table|json|ids|compact]
  op-cli.sh wp list-all <PROJECT_REF> [--status NAME] [--type NAME]
  op-cli.sh wp get <WP_ID> [summary|json]
  op-cli.sh wp set-orchestration <WP_ID> [--difficulty VAL] [--specialization VAL]
                                          [--agent VAL] [--tech-stack VAL]
                                          [--automation VAL] [--gate VAL]
  op-cli.sh wp set-orchestration-batch <TSV_FILE>

Relations:
  op-cli.sh relation create <FROM_ID> <TYPE> <TO_ID> [DESCRIPTION] [LAG]
  op-cli.sh relation list <WP_ID> [TYPE_FILTER]
  op-cli.sh relation check-blocked <WP_ID>

Projects:
  op-cli.sh project list [table|json|ids]
  op-cli.sh project get <PROJECT_REF> [summary|json]
  op-cli.sh project set <PROJECT_REF> [--status on_track|at_risk|in_trouble]
                                       [--explanation "MARKDOWN"]
  op-cli.sh project versions <PROJECT_REF> [table|json]
  op-cli.sh project members <PROJECT_REF>

Relation types:
  relates, blocks, blocked, precedes, follows, requires, required,
  duplicates, duplicated, includes, partof

Examples:
  op-cli.sh query list sentinels-hub
  op-cli.sh query exec 42 table
  op-cli.sh wp list sentinels-hub --status "In progress" --type Task
  op-cli.sh wp list-all sentinels-hub --status "New"
  op-cli.sh wp get 1897
  op-cli.sh wp set-orchestration 1897 --difficulty Medium --agent @gtd --gate G3
  op-cli.sh relation create 1897 blocks 1899
  op-cli.sh relation check-blocked 1899
  op-cli.sh project list
  op-cli.sh project get sentinels-hub
  op-cli.sh project set sentinels-hub --status at_risk --explanation "2 WPs blocked"
  op-cli.sh project versions sentinels-hub
  op-cli.sh project members sentinels-hub

Env vars:
  OPENPROJECT_URL           URL de OpenProject (requerido)
  OPENPROJECT_API_TOKEN     Token API (requerido)
  FIELD_CACHE_TTL           TTL del cache de campos en segundos (default: 86400)
EOF
}

main() {
  if [ $# -lt 1 ]; then
    usage
    exit 1
  fi

  require_env

  local domain="$1"
  shift

  case "$domain" in
    query)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        list)     cmd_query_list "$@" ;;
        exec)     cmd_query_exec "$@" ;;
        create)   cmd_query_create "$@" ;;
        delete)   cmd_query_delete "$@" ;;
        *)        echo "ERROR: subcomando desconocido: query $subcmd" >&2; usage; exit 1 ;;
      esac
      ;;

    wp)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        list)                   cmd_wp_list "$@" ;;
        list-all)               cmd_wp_list_all "$@" ;;
        get)                    cmd_wp_get "$@" ;;
        set-orchestration)      cmd_wp_set_orchestration "$@" ;;
        set-orchestration-batch) cmd_wp_set_orchestration_batch "$@" ;;
        *)                      echo "ERROR: subcomando desconocido: wp $subcmd" >&2; usage; exit 1 ;;
      esac
      ;;

    relation)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        create)         cmd_relation_create "$@" ;;
        list)           cmd_relation_list "$@" ;;
        check-blocked)  cmd_relation_check_blocked "$@" ;;
        *)              echo "ERROR: subcomando desconocido: relation $subcmd" >&2; usage; exit 1 ;;
      esac
      ;;

    project)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        list)      cmd_project_list "$@" ;;
        get)       cmd_project_get "$@" ;;
        set)       cmd_project_set "$@" ;;
        versions)  cmd_project_versions "$@" ;;
        members)   cmd_project_members "$@" ;;
        *)         echo "ERROR: subcomando desconocido: project $subcmd" >&2; usage; exit 1 ;;
      esac
      ;;

    -h|--help|help)
      usage
      ;;

    *)
      echo "ERROR: dominio desconocido: $domain" >&2
      echo "  Dominios válidos: query, wp, relation, project" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
