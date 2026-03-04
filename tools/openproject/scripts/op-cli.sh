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
#   jq (para parsing JSON)
# ─────────────────────────────────────────────────────────────

OPENPROJECT_URL="${OPENPROJECT_URL:-}"
OPENPROJECT_API_TOKEN="${OPENPROJECT_API_TOKEN:-}"
OPENPROJECT_API_CONNECT_TIMEOUT="${OPENPROJECT_API_CONNECT_TIMEOUT:-10}"
OPENPROJECT_API_MAX_TIME="${OPENPROJECT_API_MAX_TIME:-60}"
OPENPROJECT_API_MAX_RETRIES="${OPENPROJECT_API_MAX_RETRIES:-5}"
OPENPROJECT_API_RETRY_BASE_SECONDS="${OPENPROJECT_API_RETRY_BASE_SECONDS:-1}"

# ─── Core ─────────────────────────────────────────────────────

require_env() {
  if [ -z "$OPENPROJECT_URL" ] || [ -z "$OPENPROJECT_API_TOKEN" ]; then
    echo "ERROR: OPENPROJECT_URL y OPENPROJECT_API_TOKEN son requeridos." >&2
    exit 1
  fi
}

api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local body_file http_code
  local attempt=1
  local sleep_seconds="$OPENPROJECT_API_RETRY_BASE_SECONDS"

  body_file="$(mktemp)"

  while true; do
    if [ -n "$data" ]; then
      http_code="$(curl -sS --connect-timeout "$OPENPROJECT_API_CONNECT_TIMEOUT" \
        --max-time "$OPENPROJECT_API_MAX_TIME" \
        -o "$body_file" -w "%{http_code}" \
        -X "$method" \
        -u "apikey:$OPENPROJECT_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$OPENPROJECT_URL$path" 2>/dev/null || echo "000")"
    else
      http_code="$(curl -sS --connect-timeout "$OPENPROJECT_API_CONNECT_TIMEOUT" \
        --max-time "$OPENPROJECT_API_MAX_TIME" \
        -o "$body_file" -w "%{http_code}" \
        -X "$method" \
        -u "apikey:$OPENPROJECT_API_TOKEN" \
        -H "Content-Type: application/json" \
        "$OPENPROJECT_URL$path" 2>/dev/null || echo "000")"
    fi

    if [[ "$http_code" =~ ^2 ]]; then
      cat "$body_file"
      rm -f "$body_file"
      return 0
    fi

    if { [ "$http_code" = "429" ] || [ "$http_code" = "000" ] || [[ "$http_code" =~ ^5 ]]; } && [ "$attempt" -lt "$OPENPROJECT_API_MAX_RETRIES" ]; then
      echo "WARN: API $method $path → HTTP $http_code, retry $attempt/$OPENPROJECT_API_MAX_RETRIES in ${sleep_seconds}s" >&2
      sleep "$sleep_seconds"
      sleep_seconds=$((sleep_seconds * 2))
      attempt=$((attempt + 1))
      continue
    fi

    echo "ERROR: API $method $path → HTTP $http_code" >&2
    cat "$body_file" >&2
    rm -f "$body_file"
    return 1
  done
}

# URL-encode a string
urlencode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# ─── Field resolution (cache-backed) ─────────────────────────

FIELD_CACHE_TTL="${FIELD_CACHE_TTL:-86400}"

_field_cache_path() {
  if [ -n "${SENTINELS_DIR:-}" ]; then
    echo "$SENTINELS_DIR/field-mapping.json"
    return 0
  fi
  local git_root
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
  if [ -n "$git_root" ]; then
    echo "$git_root/.sentinels/field-mapping.json"
  else
    echo "${HOME}/.sentinels/field-mapping.json"
  fi
}

# Resolve a custom field name → customFieldN key
# Uses WP schema + cache for performance
resolve_field() {
  local project_ref="$1"
  local type_id="$2"
  local field_name="$3"

  local cache_path cache_key
  cache_path="$(_field_cache_path)"
  cache_key="${project_ref}-${type_id}"

  # Check cache
  if [ -f "$cache_path" ]; then
    local cached
    cached="$(python3 -c "
import json,sys,time
try:
    cache = json.load(open('$cache_path'))
    entry = cache.get('$cache_key', {})
    if entry and time.time() - entry.get('ts', 0) < $FIELD_CACHE_TTL:
        target = '$field_name'.strip().lower()
        for name, info in entry.get('fields', {}).items():
            if name == target:
                print(info['key'])
                sys.exit(0)
except: pass
print('')
" 2>/dev/null || echo "")"
    if [ -n "$cached" ]; then
      echo "$cached"
      return 0
    fi
  fi

  # Fetch schema and resolve
  local schema_json
  schema_json="$(api GET "/api/v3/work_packages/schemas/${project_ref}-${type_id}")"

  local result
  result="$(echo "$schema_json" | python3 -c "
import json,sys,re,time,os

schema = json.load(sys.stdin)
target = '$field_name'.strip().lower()
result = ''
fields = {}

for key, val in schema.items():
    if re.match(r'customField\d+$', key):
        name = str(val.get('name', '')).strip().lower()
        if name:
            fields[name] = {'key': key, 'type': val.get('type', 'unknown')}
            if name == target:
                result = key

# Update cache
cache_path = '$cache_path'
try:
    cache = json.load(open(cache_path)) if os.path.exists(cache_path) else {}
except: cache = {}

cache['$cache_key'] = {'fields': fields, 'ts': int(time.time())}
os.makedirs(os.path.dirname(cache_path), exist_ok=True)
with open(cache_path, 'w') as f:
    json.dump(cache, f, indent=2)

print(result)
" 2>/dev/null || echo "")"

  echo "$result"
}

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

  # Execute the query — returns WPs
  local result
  result="$(api GET "/api/v3/queries/$query_id")"

  local wp_collection_href
  wp_collection_href="$(echo "$result" | jq -r '._links.results.href // empty')"

  local wps
  if [ -n "$wp_collection_href" ]; then
    wps="$(api GET "$wp_collection_href")"
  else
    # Fallback: the query response itself may contain embedded results
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

# Filter builder helper
add_filter() {
  local current="$1"
  local field="$2"
  local operator="$3"
  local value="$4"

  # For status/type/assignee, resolve name → ID if not numeric
  local resolved_value="$value"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    case "$field" in
      status)
        resolved_value="$(api GET "/api/v3/statuses" | jq -r "._embedded.elements[] | select(.name == \"$value\") | .id | tostring" | head -1)"
        ;;
      type)
        # Type resolution needs project context — skip for now, use numeric
        resolved_value="$value"
        ;;
    esac
  fi

  # Append filter to array
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

  # Validate type
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

# ─── wp set-orchestration ────────────────────────────────────

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

  local lock_version project_href type_href
  lock_version="$(echo "$wp_json" | jq -r '.lockVersion')"
  project_href="$(echo "$wp_json" | jq -r '._links.project.href')"
  type_href="$(echo "$wp_json" | jq -r '._links.type.href')"

  local project_id type_id
  project_id="$(echo "$project_href" | sed 's|.*/||')"
  type_id="$(echo "$type_href" | sed 's|.*/||')"

  # Build PATCH payload with resolved custom field keys
  local patch_fields=""

  if [ -n "$difficulty" ]; then
    local key; key="$(resolve_field "$project_id" "$type_id" "difficulty")"
    if [ -n "$key" ]; then patch_fields="$patch_fields, \"$key\": \"$difficulty\""; fi
  fi
  if [ -n "$specialization" ]; then
    local key; key="$(resolve_field "$project_id" "$type_id" "specialization")"
    if [ -n "$key" ]; then patch_fields="$patch_fields, \"$key\": \"$specialization\""; fi
  fi
  if [ -n "$agent" ]; then
    local key; key="$(resolve_field "$project_id" "$type_id" "agent assigned")"
    if [ -n "$key" ]; then patch_fields="$patch_fields, \"$key\": \"$agent\""; fi
  fi
  if [ -n "$tech_stack" ]; then
    local key; key="$(resolve_field "$project_id" "$type_id" "tech stack")"
    if [ -n "$key" ]; then patch_fields="$patch_fields, \"$key\": \"$tech_stack\""; fi
  fi
  if [ -n "$automation" ]; then
    local key; key="$(resolve_field "$project_id" "$type_id" "automation level")"
    if [ -n "$key" ]; then patch_fields="$patch_fields, \"$key\": \"$automation\""; fi
  fi
  if [ -n "$gate" ]; then
    local key; key="$(resolve_field "$project_id" "$type_id" "gate current")"
    if [ -n "$key" ]; then patch_fields="$patch_fields, \"$key\": \"$gate\""; fi
  fi

  if [ -z "$patch_fields" ]; then
    echo "ERROR: ningún campo de orquestación especificado o resuelto" >&2
    return 1
  fi

  # Remove leading comma+space
  patch_fields="${patch_fields:2}"

  local payload="{\"lockVersion\": $lock_version, $patch_fields}"

  local result
  result="$(api PATCH "/api/v3/work_packages/$wp_id" "$payload")"
  echo "WP#$wp_id actualizado con campos de orquestación"
}

# ─── wp set-orchestration-batch ──────────────────────────────

cmd_wp_set_orchestration_batch() {
  local input_file="$1"

  if [ ! -f "$input_file" ]; then
    echo "ERROR: archivo no encontrado: $input_file" >&2
    return 1
  fi

  # Expected format: TSV with columns: wp_id difficulty specialization agent tech_stack automation gate
  # Lines starting with # are comments
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

    -h|--help|help)
      usage
      ;;

    *)
      echo "ERROR: dominio desconocido: $domain" >&2
      echo "  Dominios válidos: query, wp, relation" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
