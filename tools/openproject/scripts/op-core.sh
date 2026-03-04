#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# op-core.sh — Funciones compartidas para OpenProject CLI
# ─────────────────────────────────────────────────────────────
# No se ejecuta directamente. Se importa con:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/op-core.sh"
# ─────────────────────────────────────────────────────────────

# ─── Env vars ─────────────────────────────────────────────────

OPENPROJECT_URL="${OPENPROJECT_URL:-}"
OPENPROJECT_API_TOKEN="${OPENPROJECT_API_TOKEN:-}"
OPENPROJECT_API_CONNECT_TIMEOUT="${OPENPROJECT_API_CONNECT_TIMEOUT:-10}"
OPENPROJECT_API_MAX_TIME="${OPENPROJECT_API_MAX_TIME:-60}"
OPENPROJECT_API_MAX_RETRIES="${OPENPROJECT_API_MAX_RETRIES:-5}"
OPENPROJECT_API_RETRY_BASE_SECONDS="${OPENPROJECT_API_RETRY_BASE_SECONDS:-1}"
FIELD_CACHE_TTL="${FIELD_CACHE_TTL:-86400}"

# ─── Require env ──────────────────────────────────────────────

require_env() {
  if [ -z "$OPENPROJECT_URL" ] || [ -z "$OPENPROJECT_API_TOKEN" ]; then
    echo "ERROR: OPENPROJECT_URL y OPENPROJECT_API_TOKEN son requeridos." >&2
    exit 1
  fi
}

# ─── API function ─────────────────────────────────────────────
# Retry con exponential backoff para 429, 5xx, network errors.
# API_NOEXIT=1 → return 1 en vez de exit 1 en error.

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

    if [ "${API_NOEXIT:-}" = "1" ]; then
      cat "$body_file" >&2
      rm -f "$body_file"
      return 1
    fi

    echo "ERROR: API $method $path → HTTP $http_code" >&2
    cat "$body_file" >&2
    rm -f "$body_file"
    exit 1
  done
}

# Non-fatal API call wrapper
api_try() {
  API_NOEXIT=1 api "$@"
}

# ─── Utilities ────────────────────────────────────────────────

urlencode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# ─── Field cache ──────────────────────────────────────────────
# Cache structure:
# {
#   "<project_ref>-<type_id>": {
#     "fields": {
#       "<name_lower>": {
#         "key": "customFieldN",
#         "type": "String|List|...",
#         "allowed_values": { "value_text_lower": "/api/v3/custom_field/N/options/M", ... }
#       }
#     },
#     "ts": <epoch>
#   }
# }

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

# Populate the field cache for a given project+type from schema
_populate_field_cache() {
  local project_ref="$1"
  local type_id="$2"

  local cache_path cache_key
  cache_path="$(_field_cache_path)"
  cache_key="${project_ref}-${type_id}"

  # Check if cache is still valid
  if [ -f "$cache_path" ]; then
    local is_valid
    is_valid="$(python3 -c "
import json,sys,time
try:
    cache = json.load(open('$cache_path'))
    entry = cache.get('$cache_key', {})
    if entry and time.time() - entry.get('ts', 0) < $FIELD_CACHE_TTL:
        print('valid')
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo "")"
    if [ "$is_valid" = "valid" ]; then
      return 0
    fi
  fi

  # Fetch schema and build cache with allowedValues for List fields
  local schema_json
  schema_json="$(api GET "/api/v3/work_packages/schemas/${project_ref}-${type_id}")"

  echo "$schema_json" | python3 -c "
import json,sys,re,time,os

schema = json.load(sys.stdin)
fields = {}

for key, val in schema.items():
    if re.match(r'customField\d+$', key):
        name = str(val.get('name', '')).strip().lower()
        if not name:
            continue

        field_info = {
            'key': key,
            'type': val.get('type', 'unknown'),
            'allowed_values': {}
        }

        # For List fields, extract allowedValues → { 'value_lower': 'href' }
        embedded = val.get('_embedded', {})
        allowed = embedded.get('allowedValues', [])
        if allowed:
            for av in allowed:
                av_value = str(av.get('value', '')).strip()
                av_href = av.get('_links', {}).get('self', {}).get('href', '')
                if av_value and av_href:
                    field_info['allowed_values'][av_value.lower()] = av_href

        # Also check _links.allowedValues for lazy-loaded lists
        links = val.get('_links', {})
        if 'allowedValues' in links and not allowed:
            av_href = links['allowedValues'].get('href', '')
            if av_href:
                field_info['allowed_values_href'] = av_href

        fields[name] = field_info

# Read existing cache
cache_path = '$cache_path'
try:
    cache = json.load(open(cache_path)) if os.path.exists(cache_path) else {}
except:
    cache = {}

cache['$cache_key'] = {'fields': fields, 'ts': int(time.time())}
os.makedirs(os.path.dirname(cache_path), exist_ok=True)
with open(cache_path, 'w') as f:
    json.dump(cache, f, indent=2)
" 2>/dev/null
}

# Resolve lazy-loaded allowedValues for a field (fetches from API if needed)
_resolve_lazy_allowed_values() {
  local project_ref="$1"
  local type_id="$2"
  local field_name_lower="$3"

  local cache_path cache_key
  cache_path="$(_field_cache_path)"
  cache_key="${project_ref}-${type_id}"

  python3 -c "
import json,sys,os,time
cache_path = '$cache_path'
cache_key = '$cache_key'
field_name = '$field_name_lower'

try:
    cache = json.load(open(cache_path))
    entry = cache.get(cache_key, {})
    field = entry.get('fields', {}).get(field_name, {})
    href = field.get('allowed_values_href', '')
    if href:
        print(href)
    else:
        print('')
except:
    print('')
" 2>/dev/null
}

# Resolve a custom field name → customFieldN key
resolve_field() {
  local project_ref="$1"
  local type_id="$2"
  local field_name="$3"

  _populate_field_cache "$project_ref" "$type_id"

  local cache_path
  cache_path="$(_field_cache_path)"

  python3 -c "
import json,sys
try:
    cache = json.load(open('$cache_path'))
    entry = cache.get('${project_ref}-${type_id}', {})
    target = '$field_name'.strip().lower()
    field = entry.get('fields', {}).get(target, {})
    print(field.get('key', ''))
except:
    print('')
" 2>/dev/null
}

# Resolve a custom field value → href for List fields, or plain value for text
# Returns JSON fragment ready for PATCH payload:
#   List field:  "_links": { "customFieldN": { "href": "/api/v3/..." } }
#   Text field:  "customFieldN": "value"
resolve_field_value() {
  local project_ref="$1"
  local type_id="$2"
  local field_name="$3"
  local value="$4"

  _populate_field_cache "$project_ref" "$type_id"

  local cache_path
  cache_path="$(_field_cache_path)"

  local result
  result="$(python3 -c "
import json,sys

cache_path = '$cache_path'
project_ref = '$project_ref'
type_id = '$type_id'
field_name = '${field_name}'.strip().lower()
value = '${value}'
value_lower = value.strip().lower()

try:
    cache = json.load(open(cache_path))
except:
    cache = {}

entry = cache.get(f'{project_ref}-{type_id}', {})
field = entry.get('fields', {}).get(field_name, {})

if not field:
    # Field not found
    print('ERROR:field_not_found')
    sys.exit(0)

key = field['key']
field_type = field.get('type', '')
allowed = field.get('allowed_values', {})

if allowed:
    # List field — resolve value to href
    href = allowed.get(value_lower, '')
    if href:
        print(f'LINK:{key}:{href}')
    else:
        available = ', '.join(sorted(set(k for k in allowed.keys())))
        print(f'ERROR:value_not_found:{value}:available=[{available}]')
elif field.get('allowed_values_href'):
    # Lazy-loaded list — signal caller to fetch
    print(f'LAZY:{key}:{field[\"allowed_values_href\"]}')
else:
    # Text/String field — plain value
    print(f'TEXT:{key}:{value}')
" 2>/dev/null || echo "ERROR:python_failed")"

  # Handle lazy-loaded allowedValues
  if [[ "$result" == LAZY:* ]]; then
    local key lazy_href
    key="$(echo "$result" | cut -d: -f2)"
    lazy_href="$(echo "$result" | cut -d: -f3-)"

    # Fetch allowed values from API
    local av_json
    av_json="$(api GET "$lazy_href")"

    # Find the matching value
    local href
    href="$(echo "$av_json" | python3 -c "
import json,sys
data = json.load(sys.stdin)
target = '${value}'.strip().lower()
elements = data.get('_embedded', {}).get('elements', [])
if not elements:
    elements = data if isinstance(data, list) else []
for el in elements:
    if str(el.get('value','')).strip().lower() == target:
        print(el.get('_links',{}).get('self',{}).get('href',''))
        sys.exit(0)
print('')
" 2>/dev/null || echo "")"

    if [ -n "$href" ]; then
      # Update cache with fetched values
      echo "$av_json" | python3 -c "
import json,sys,os
cache_path = '$cache_path'
cache_key = '${project_ref}-${type_id}'
field_name = '${field_name}'.strip().lower()
try:
    cache = json.load(open(cache_path))
    data = json.load(sys.stdin)
    elements = data.get('_embedded', {}).get('elements', [])
    if not elements:
        elements = data if isinstance(data, list) else []
    avs = {}
    for el in elements:
        v = str(el.get('value','')).strip()
        h = el.get('_links',{}).get('self',{}).get('href','')
        if v and h:
            avs[v.lower()] = h
    cache[cache_key]['fields'][field_name]['allowed_values'] = avs
    del cache[cache_key]['fields'][field_name]['allowed_values_href']
    with open(cache_path, 'w') as f:
        json.dump(cache, f, indent=2)
except: pass
" 2>/dev/null
      result="LINK:$key:$href"
    else
      result="ERROR:value_not_found:${value}"
    fi
  fi

  echo "$result"
}

# Build a PATCH payload fragment from resolve_field_value results
# Input: array of "LINK:key:href" or "TEXT:key:value" strings
# Output: JSON object with proper structure for OP API v3
build_patch_payload() {
  local lock_version="$1"
  shift
  local fragments=("$@")

  python3 -c "
import json,sys

lock_version = int('$lock_version')
fragments = sys.argv[1:]

payload = {'lockVersion': lock_version}
links = {}

for frag in fragments:
    parts = frag.split(':', 2)
    if len(parts) < 3:
        continue
    ftype, key, value = parts[0], parts[1], parts[2]

    if ftype == 'LINK':
        links[key] = {'href': value}
    elif ftype == 'TEXT':
        payload[key] = value

if links:
    payload['_links'] = links

print(json.dumps(payload))
" "${fragments[@]}"
}

# ─── Status resolution (cached per session) ──────────────────

_STATUSES_CACHE=""

resolve_status_id() {
  local name="$1"

  if [ -z "$_STATUSES_CACHE" ]; then
    _STATUSES_CACHE="$(api GET "/api/v3/statuses")"
  fi

  echo "$_STATUSES_CACHE" | jq -r "._embedded.elements[] | select(.name == \"$name\") | .id" | head -1
}

resolve_status_name() {
  local id="$1"

  if [ -z "$_STATUSES_CACHE" ]; then
    _STATUSES_CACHE="$(api GET "/api/v3/statuses")"
  fi

  echo "$_STATUSES_CACHE" | jq -r "._embedded.elements[] | select(.id == $id) | .name" | head -1
}

# ─── Type resolution ─────────────────────────────────────────

resolve_type_id() {
  local project_ref="$1"
  local name="$2"

  api GET "/api/v3/projects/$project_ref/types" | jq -r "._embedded.elements[] | select(.name == \"$name\") | .id" | head -1
}
