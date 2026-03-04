#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# ev-core.sh — Funciones compartidas para Evidence CLI
# ─────────────────────────────────────────────────────────────
# Alineado con Sentinels Protocol v1.0 (Lighthouse)
#
# Requiere: sha256sum/shasum, jq, python3
# Importar con:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/ev-core.sh"
# ─────────────────────────────────────────────────────────────

# Source sak-core.sh if available (shared timestamps, validators, output helpers)
_SAK_CORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../scripts" 2>/dev/null && pwd)/sak-core.sh"
if [ -f "$_SAK_CORE" ]; then source "$_SAK_CORE"; fi

# ─── SHA-256 ──────────────────────────────────────────────────

# Cross-platform SHA-256 of a file
sha256() {
  local file="$1"
  if command -v sha256sum &>/dev/null; then
    sha256sum "$file" | cut -d' ' -f1
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$file" | cut -d' ' -f1
  else
    python3 -c "import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$file"
  fi
}

# SHA-256 of a string
sha256_string() {
  local str="$1"
  printf '%s' "$str" | if command -v sha256sum &>/dev/null; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum &>/dev/null; then
    shasum -a 256 | cut -d' ' -f1
  else
    python3 -c "import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())"
  fi
}

# ─── Timestamps (fallback if sak-core not loaded) ───────────

if ! declare -f iso_timestamp &>/dev/null; then
  iso_timestamp()      { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
  compact_timestamp()  { date -u +"%Y%m%dT%H%M%SZ"; }
  numeric_timestamp()  { date -u +"%Y%m%d%H%M%S"; }
fi

# ─── Bundle ID generation ────────────────────────────────────
# Format: bundle-<YYYYMMDDTHHMMSSz>-<contract_id_lower>
# Example: bundle-20260304T143000Z-ctr-sentinels-hub-20260302

generate_bundle_id() {
  local contract_id="$1"
  local ts
  ts="$(compact_timestamp)"
  local contract_lower
  contract_lower="$(echo "$contract_id" | tr '[:upper:]' '[:lower:]')"
  echo "bundle-${ts}-${contract_lower}"
}

# ─── Ledger entry ID generation ──────────────────────────────
# Format: ledger-<YYYYMMDDHHmmss>-<contract_id>
# Example: ledger-20260304143000-CTR-sentinels-hub-20260302

generate_ledger_entry_id() {
  local contract_id="$1"
  local ts
  ts="$(numeric_timestamp)"
  echo "ledger-${ts}-${contract_id}"
}

# ─── Canonical bundle SHA-256 ────────────────────────────────
# Replicates the algorithm from Lighthouse verify-evidence-chain.sh:
#   1. Sort artifacts by path
#   2. Build lines: "path:sha256:size_bytes"
#   3. If previous_bundle_sha256 exists, append "previous:<hash>"
#   4. Join with newline, SHA-256 the result

compute_bundle_sha256() {
  local manifest_path="$1"
  python3 -c "
import hashlib
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as f:
    manifest = json.load(f)

entries = []
for artifact in sorted(manifest.get('artifacts', []), key=lambda a: a['path']):
    entries.append(f\"{artifact['path']}:{artifact['sha256']}:{artifact.get('size_bytes', 0)}\")

previous = manifest.get('previous_bundle_sha256')
if previous:
    entries.append(f'previous:{previous}')

material = '\n'.join(entries).encode('utf-8')
print(hashlib.sha256(material).hexdigest())
" "$manifest_path"
}

# ─── Ledger path operations (partitioned) ────────────────────
# Structure: ledger/<yyyy>/<mm>/entries.jsonl

# Current partition path based on today's date
ledger_current_path() {
  local journal_path="$1"
  local year month
  year="$(date -u +%Y)"
  month="$(date -u +%m)"
  echo "$journal_path/ledger/$year/$month/entries.jsonl"
}

# Concatenate ALL ledger partition files in chronological order
ledger_all_entries() {
  local journal_path="$1"

  # Partitioned ledger: ledger/<yyyy>/<mm>/entries.jsonl
  if [ -d "$journal_path/ledger" ]; then
    find "$journal_path/ledger" -name "entries.jsonl" -type f 2>/dev/null | sort | while read -r f; do
      cat "$f"
    done
  fi

  # Legacy fallback: ledger/ledger.jsonl
  if [ -f "$journal_path/ledger/ledger.jsonl" ]; then
    cat "$journal_path/ledger/ledger.jsonl"
  fi
}

# Get the last bundle_sha256 from the ledger (for hash chain)
ledger_last_hash() {
  local journal_path="$1"
  local last_line
  last_line="$(ledger_all_entries "$journal_path" | tail -1)"

  if [ -z "$last_line" ]; then
    echo "null"
    return 0
  fi

  echo "$last_line" | jq -r '.bundle_sha256'
}

# Count total entries across all partitions
ledger_count() {
  local journal_path="$1"
  local count
  count="$(ledger_all_entries "$journal_path" | wc -l | tr -d ' ')"
  echo "$count"
}

# ─── Journal directory structure ─────────────────────────────
# Structure: bundles/<yyyy>/<mm>/<bundle_id>/

journal_bundle_dir() {
  local journal_path="$1"
  local bundle_id="$2"
  local year month
  year="$(date -u +%Y)"
  month="$(date -u +%m)"
  echo "$journal_path/bundles/$year/$month/$bundle_id"
}

# ─── Validation ──────────────────────────────────────────────

# Validate required fields in a bundle manifest
validate_manifest() {
  local manifest_path="$1"
  python3 -c "
import json
import sys

required = ['protocol_version', 'bundle_id', 'contract_id', 'generated_at',
            'format', 'artifacts', 'bundle_sha256', 'previous_bundle_sha256']

with open(sys.argv[1], 'r', encoding='utf-8') as f:
    manifest = json.load(f)

missing = [field for field in required if field not in manifest]
if missing:
    print(f'FAIL: missing fields: {', '.join(missing)}', file=sys.stderr)
    sys.exit(1)

if not manifest.get('artifacts'):
    print('FAIL: artifacts array is empty', file=sys.stderr)
    sys.exit(1)

for i, art in enumerate(manifest['artifacts']):
    for key in ('path', 'sha256', 'size_bytes'):
        if key not in art:
            print(f'FAIL: artifact[{i}] missing {key}', file=sys.stderr)
            sys.exit(1)

print('OK')
" "$manifest_path"
}

# Validate required fields in a ledger entry JSON string
validate_ledger_entry() {
  local entry_json="$1"
  python3 -c "
import json
import sys

required = ['protocol_version', 'entry_id', 'recorded_at', 'repository',
            'contract_id', 'bundle_manifest_path', 'bundle_sha256',
            'previous_bundle_sha256']

entry = json.loads(sys.argv[1])
missing = [field for field in required if field not in entry]
if missing:
    print(f'FAIL: missing fields: {', '.join(missing)}', file=sys.stderr)
    sys.exit(1)

print('OK')
" "$entry_json"
}

# ─── Redaction patterns ──────────────────────────────────────

# Apply redaction patterns to a file, output to stdout
# Replacement count is written to stderr
redact_content() {
  local file="$1"
  shift
  local patterns=("$@")

  python3 -c "
import re, sys

content = open(sys.argv[1], 'r', errors='replace').read()
patterns_arg = sys.argv[2:]
count = 0

pattern_map = {
    'email': (r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[REDACTED:email]'),
    'api_key': (r'(?i)(api[_-]?key|apikey|api_token)[\"\'\\s:=]+[a-zA-Z0-9_-]{20,}', '[REDACTED:api_key]'),
    'token': (r'(?i)(bearer|token)[\"\'\\s:=]+[a-zA-Z0-9_.-]{20,}', '[REDACTED:token]'),
    'secret': (r'(?i)(password|secret|passwd)[\"\'\\s:=]+\\S+', '[REDACTED:secret]'),
    'ip': (r'(?:10|172\\.(?:1[6-9]|2\\d|3[01])|192\\.168)\\.\\d{1,3}\\.\\d{1,3}', '[REDACTED:ip]'),
    'path': (r'(?:/Users/|/home/)[a-zA-Z0-9._-]+', '[REDACTED:path]'),
    'ghp': (r'ghp_[A-Za-z0-9]{36,}', '[REDACTED:github_pat]'),
    'github_pat': (r'github_pat_[A-Za-z0-9_]{20,}', '[REDACTED:github_pat]'),
    'sk': (r'sk-[A-Za-z0-9]{20,}', '[REDACTED:api_key]'),
}

for p in patterns_arg:
    if p in pattern_map:
        regex, replacement = pattern_map[p]
        content, n = re.subn(regex, replacement, content)
        count += n

print(content, end='')
sys.stderr.write(str(count))
" "$file" "${patterns[@]}"
}
