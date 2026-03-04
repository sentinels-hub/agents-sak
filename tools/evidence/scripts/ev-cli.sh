#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# ev-cli.sh — CLI de Evidence para Sentinels
# ─────────────────────────────────────────────────────────────
# Alineado con Sentinels Protocol v1.0 (Lighthouse)
#
# Estructura real:
#   bundles/<yyyy>/<mm>/<bundle-id>/bundle-manifest.json
#   ledger/<yyyy>/<mm>/entries.jsonl
#
# Requiere: sha256sum/shasum, jq, python3, git
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ev-core.sh"

# ═══════════════════════════════════════════════════════════════
# BUNDLE COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── bundle create ────────────────────────────────────────────
# Creates a bundle with canonical hash algorithm from Lighthouse.
# Output: bundles/<yyyy>/<mm>/<bundle_id>/bundle-manifest.json

cmd_bundle_create() {
  local contract_id=""
  local artifacts_dir=""
  local journal_path=""
  local sources_op="skipped"
  local sources_gh="skipped"
  local sources_oc="skipped"
  local redaction_patterns=""

  # Parse positional + flags
  local positionals=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --journal-path)       shift; journal_path="$1"; shift ;;
      --sources-op)         shift; sources_op="$1"; shift ;;
      --sources-gh)         shift; sources_gh="$1"; shift ;;
      --sources-oc)         shift; sources_oc="$1"; shift ;;
      --redaction-patterns) shift; redaction_patterns="$1"; shift ;;
      -*)                   echo "ERROR: opción desconocida: $1" >&2; return 1 ;;
      *)                    positionals+=("$1"); shift ;;
    esac
  done

  contract_id="${positionals[0]:-}"
  artifacts_dir="${positionals[1]:-}"

  if [ -z "$contract_id" ] || [ -z "$artifacts_dir" ]; then
    echo "ERROR: uso: ev-cli.sh bundle create <CONTRACT_ID> <ARTIFACTS_DIR> [--journal-path PATH]" >&2
    return 1
  fi

  if [ ! -d "$artifacts_dir" ]; then
    echo "ERROR: directorio no encontrado: $artifacts_dir" >&2
    return 1
  fi

  local bundle_id
  bundle_id="$(generate_bundle_id "$contract_id")"

  local timestamp
  timestamp="$(iso_timestamp)"

  # Get previous bundle hash from ledger
  local previous_hash="null"
  if [ -n "$journal_path" ]; then
    previous_hash="$(ledger_last_hash "$journal_path")"
  fi

  # Build artifacts array and redaction info
  local redaction_patterns_json="[]"
  local redaction_count=0

  if [ -n "$redaction_patterns" ]; then
    IFS=',' read -ra _patterns <<< "$redaction_patterns"
    redaction_patterns_json="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${_patterns[@]}")"

    # Apply redaction to each file
    for file in "$artifacts_dir"/*; do
      [ -f "$file" ] || continue
      local count
      count="$(redact_content "$file" "${_patterns[@]}" 2>&1 1>/dev/null)"
      if [ "$count" -gt 0 ]; then
        local redacted
        redacted="$(redact_content "$file" "${_patterns[@]}" 2>/dev/null)"
        echo "$redacted" > "$file"
        redaction_count=$((redaction_count + count))
      fi
    done
  fi

  # Calculate hashes for all artifacts
  local manifest_json
  manifest_json="$(python3 -c "
import hashlib
import json
import os
import sys

artifacts_dir = sys.argv[1]
contract_id = sys.argv[2]
bundle_id = sys.argv[3]
timestamp = sys.argv[4]
previous_hash = sys.argv[5] if sys.argv[5] != 'null' else None
sources_op = sys.argv[6]
sources_gh = sys.argv[7]
sources_oc = sys.argv[8]
redaction_patterns = json.loads(sys.argv[9])
redaction_count = int(sys.argv[10])

artifacts = []
for name in sorted(os.listdir(artifacts_dir)):
    fpath = os.path.join(artifacts_dir, name)
    if not os.path.isfile(fpath):
        continue
    with open(fpath, 'rb') as f:
        content = f.read()
    artifacts.append({
        'path': name,
        'sha256': hashlib.sha256(content).hexdigest(),
        'size_bytes': len(content),
        'redacted': len(redaction_patterns) > 0
    })

if not artifacts:
    print('ERROR: no artifacts found', file=sys.stderr)
    sys.exit(1)

# Build canonical hash material
entries = []
for art in sorted(artifacts, key=lambda a: a['path']):
    entries.append(f\"{art['path']}:{art['sha256']}:{art['size_bytes']}\")
if previous_hash:
    entries.append(f'previous:{previous_hash}')

material = '\n'.join(entries).encode('utf-8')
bundle_sha256 = hashlib.sha256(material).hexdigest()

manifest = {
    'protocol_version': '1.0',
    'bundle_id': bundle_id,
    'contract_id': contract_id,
    'generated_at': timestamp,
    'format': 'json',
    'artifacts': artifacts,
    'bundle_sha256': bundle_sha256,
    'previous_bundle_sha256': previous_hash,
    'sources': {
        'openproject': {'status': sources_op},
        'github': {'status': sources_gh},
        'opencode': {'status': sources_oc}
    },
    'redaction': {
        'patterns_applied': redaction_patterns,
        'replacements': redaction_count
    }
}

print(json.dumps(manifest, indent=2))
" "$artifacts_dir" "$contract_id" "$bundle_id" "$timestamp" \
  "$previous_hash" "$sources_op" "$sources_gh" "$sources_oc" \
  "$redaction_patterns_json" "$redaction_count")"

  local bundle_sha256
  bundle_sha256="$(echo "$manifest_json" | jq -r '.bundle_sha256')"

  # Output or save to journal
  if [ -n "$journal_path" ]; then
    local output_dir
    output_dir="$(journal_bundle_dir "$journal_path" "$bundle_id")"
    mkdir -p "$output_dir"

    # Copy artifacts into bundle directory
    cp "$artifacts_dir"/* "$output_dir/" 2>/dev/null || true

    # Write manifest
    echo "$manifest_json" > "$output_dir/bundle-manifest.json"

    local artifact_count
    artifact_count="$(echo "$manifest_json" | jq '.artifacts | length')"

    echo "Bundle creado: $bundle_id"
    echo "  Manifest: $output_dir/bundle-manifest.json"
    echo "  Artifacts: $artifact_count"
    echo "  SHA-256: $bundle_sha256"
    echo "  Previous: $previous_hash"
  else
    echo "$manifest_json"
  fi
}

# ─── bundle verify ────────────────────────────────────────────
# Verifies bundle integrity using canonical algorithm.
# Backwards-compatible: detects BDL- (legacy) vs bundle- (canonical).

cmd_bundle_verify() {
  local manifest_path="$1"

  if [ ! -f "$manifest_path" ]; then
    echo "ERROR: manifest no encontrado: $manifest_path" >&2
    return 1
  fi

  local manifest_dir
  manifest_dir="$(dirname "$manifest_path")"

  echo "=== Bundle Verification ==="
  echo "Manifest: $manifest_path"
  echo ""

  local errors=0

  # Detect verification mode by bundle_id prefix
  local bundle_id
  bundle_id="$(jq -r '.bundle_id' "$manifest_path")"
  local verify_mode="canonical"

  if [[ "$bundle_id" == BDL-* ]]; then
    verify_mode="legacy"
    echo "  [INFO] Legacy bundle detected (BDL-*), using legacy verification"
  fi

  # Verify bundle_sha256
  local declared_hash
  declared_hash="$(jq -r '.bundle_sha256' "$manifest_path")"

  if [ "$verify_mode" = "canonical" ]; then
    # Canonical: hash from sorted artifact index + previous
    local expected_hash
    expected_hash="$(compute_bundle_sha256 "$manifest_path")"

    if [ "$declared_hash" = "$expected_hash" ]; then
      echo "  [OK] bundle_sha256 (canonical)"
    else
      echo "  [FAIL] bundle_sha256 mismatch (canonical)"
      echo "    Declared: $declared_hash"
      echo "    Expected: $expected_hash"
      errors=$((errors + 1))
    fi
  else
    # Legacy: hash of manifest with empty bundle_sha256
    local actual_manifest actual_hash
    actual_manifest="$(jq '.bundle_sha256 = ""' "$manifest_path")"
    actual_hash="$(sha256_string "$actual_manifest")"

    if [ "$declared_hash" = "$actual_hash" ]; then
      echo "  [OK] bundle_sha256 (legacy)"
    else
      echo "  [FAIL] bundle_sha256 mismatch (legacy)"
      echo "    Declared: $declared_hash"
      echo "    Actual:   $actual_hash"
      errors=$((errors + 1))
    fi
  fi

  # Verify each artifact
  local artifact_count total_ok=0
  artifact_count="$(jq '.artifacts | length' "$manifest_path")"

  for i in $(seq 0 $((artifact_count - 1))); do
    local path hash size
    path="$(jq -r ".artifacts[$i].path" "$manifest_path")"
    hash="$(jq -r ".artifacts[$i].sha256" "$manifest_path")"
    size="$(jq -r ".artifacts[$i].size_bytes" "$manifest_path")"

    # Try path relative to manifest dir
    local full_path="$manifest_dir/$path"

    if [ ! -f "$full_path" ]; then
      echo "  [FAIL] Artifact missing: $path"
      errors=$((errors + 1))
      continue
    fi

    local actual_file_hash actual_size
    actual_file_hash="$(sha256 "$full_path")"
    actual_size="$(wc -c < "$full_path" | tr -d ' ')"

    if [ "$hash" != "$actual_file_hash" ]; then
      echo "  [FAIL] Hash mismatch: $path"
      echo "    Declared: $hash"
      echo "    Actual:   $actual_file_hash"
      errors=$((errors + 1))
    elif [ "$size" != "$actual_size" ]; then
      echo "  [FAIL] Size mismatch: $path ($size vs $actual_size)"
      errors=$((errors + 1))
    else
      total_ok=$((total_ok + 1))
    fi
  done

  echo "  [OK] $total_ok/$artifact_count artifacts verified"

  echo ""
  if [ "$errors" -eq 0 ]; then
    echo "Status: PASS"
    return 0
  else
    echo "Status: FAIL ($errors errors)"
    return 1
  fi
}

# ─── bundle list ──────────────────────────────────────────────
# Scans both bundles/ (new) and evidence/ (legacy) structures.

cmd_bundle_list() {
  local journal_path=""
  local contract_filter=""

  # Parse args: first positional is journal_path, second is optional contract
  local positionals=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --contract) shift; contract_filter="$1"; shift ;;
      -*)         shift ;;
      *)          positionals+=("$1"); shift ;;
    esac
  done

  journal_path="${positionals[0]:-}"
  if [ -z "$journal_path" ]; then
    echo "ERROR: journal path requerido" >&2
    return 1
  fi
  contract_filter="${contract_filter:-${positionals[1]:-}}"

  local found=0

  # Scan new structure: bundles/<yyyy>/<mm>/<bundle-id>/bundle-manifest.json
  if [ -d "$journal_path/bundles" ]; then
    find "$journal_path/bundles" -name "bundle-manifest.json" -type f 2>/dev/null | sort | while read -r manifest; do
      local contract bundle_id generated_at bundle_sha
      contract="$(jq -r '.contract_id' "$manifest" 2>/dev/null)" || continue
      bundle_id="$(jq -r '.bundle_id' "$manifest" 2>/dev/null)"
      generated_at="$(jq -r '.generated_at' "$manifest" 2>/dev/null)"
      bundle_sha="$(jq -r '.bundle_sha256' "$manifest" 2>/dev/null | cut -c1-12)"

      if [ -n "$contract_filter" ] && [ "$contract" != "$contract_filter" ]; then
        continue
      fi

      local artifact_count
      artifact_count="$(jq '.artifacts | length' "$manifest" 2>/dev/null)"
      echo "  $bundle_id  $contract  $generated_at  ${artifact_count} artifacts  ${bundle_sha}..."
    done
    found=1
  fi

  # Scan legacy structure: evidence/<contract>/bundle-manifest*.json
  if [ -d "$journal_path/evidence" ]; then
    find "$journal_path/evidence" -name "bundle-manifest*.json" -type f 2>/dev/null | sort | while read -r manifest; do
      local contract bundle_id generated_at bundle_sha
      contract="$(jq -r '.contract_id' "$manifest" 2>/dev/null)" || continue
      bundle_id="$(jq -r '.bundle_id' "$manifest" 2>/dev/null)"
      generated_at="$(jq -r '.generated_at' "$manifest" 2>/dev/null)"
      bundle_sha="$(jq -r '.bundle_sha256' "$manifest" 2>/dev/null | cut -c1-12)"

      if [ -n "$contract_filter" ] && [ "$contract" != "$contract_filter" ]; then
        continue
      fi

      local artifact_count
      artifact_count="$(jq '.artifacts | length' "$manifest" 2>/dev/null)"
      echo "  [legacy] $bundle_id  $contract  $generated_at  ${artifact_count} artifacts  ${bundle_sha}..."
    done
    found=1
  fi

  if [ "$found" -eq 0 ]; then
    echo "No bundles found in $journal_path"
  fi
}

# ═══════════════════════════════════════════════════════════════
# LEDGER COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── ledger append ────────────────────────────────────────────
# Appends entry to partitioned ledger: ledger/<yyyy>/<mm>/entries.jsonl
# Auto git commit (disable with --no-git-commit)

cmd_ledger_append() {
  local repo=""
  local contract_id=""
  local manifest_path=""
  local journal_path=""
  local evidence_url=""
  local notes=""
  local actor_mapping=""
  local no_git_commit=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --repo)            shift; repo="$1"; shift ;;
      --contract)        shift; contract_id="$1"; shift ;;
      --manifest)        shift; manifest_path="$1"; shift ;;
      --journal-path)    shift; journal_path="$1"; shift ;;
      --evidence-url)    shift; evidence_url="$1"; shift ;;
      --notes)           shift; notes="$1"; shift ;;
      --actor-mapping)   shift; actor_mapping="$1"; shift ;;
      --no-git-commit)   no_git_commit=true; shift ;;
      *)                 echo "ERROR: opción desconocida: $1" >&2; return 1 ;;
    esac
  done

  if [ -z "$journal_path" ] || [ -z "$contract_id" ] || [ -z "$manifest_path" ]; then
    echo "ERROR: --journal-path, --contract y --manifest son requeridos" >&2
    return 1
  fi

  if [ -z "$repo" ]; then
    repo="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "unknown")")"
  fi

  # Ensure repo matches pattern sentinels-*
  if [[ "$repo" != sentinels-* ]]; then
    repo="sentinels-${repo}"
  fi

  # Get bundle_sha256 from manifest
  # Resolve manifest path: try as-is, then relative to journal_path
  local manifest_file="$manifest_path"
  if [ ! -f "$manifest_file" ] && [ -n "$journal_path" ]; then
    manifest_file="$journal_path/$manifest_path"
  fi

  local bundle_sha
  if [ -f "$manifest_file" ]; then
    bundle_sha="$(jq -r '.bundle_sha256' "$manifest_file")"
  else
    echo "ERROR: manifest no encontrado: $manifest_path" >&2
    return 1
  fi

  # Get previous hash from ledger
  local previous_hash
  previous_hash="$(ledger_last_hash "$journal_path")"

  # Generate entry ID
  local entry_id
  entry_id="$(generate_ledger_entry_id "$contract_id")"

  local timestamp
  timestamp="$(iso_timestamp)"

  # Build entry
  local entry
  entry="$(python3 -c "
import json
import sys

entry = {
    'protocol_version': '1.0',
    'entry_id': sys.argv[1],
    'recorded_at': sys.argv[2],
    'repository': sys.argv[3],
    'contract_id': sys.argv[4],
    'bundle_manifest_path': sys.argv[5],
    'bundle_sha256': sys.argv[6],
    'previous_bundle_sha256': None if sys.argv[7] == 'null' else sys.argv[7]
}

if sys.argv[8]:
    entry['actor_mapping_path'] = sys.argv[8]
if sys.argv[9]:
    entry['evidence_url'] = sys.argv[9]
if sys.argv[10]:
    entry['notes'] = sys.argv[10]

print(json.dumps(entry, separators=(',', ':')))
" "$entry_id" "$timestamp" "$repo" "$contract_id" \
  "$manifest_path" "$bundle_sha" "$previous_hash" \
  "$actor_mapping" "$evidence_url" "$notes")"

  # Validate before appending
  if ! validate_ledger_entry "$entry" > /dev/null 2>&1; then
    echo "ERROR: entry validation failed" >&2
    return 1
  fi

  # Append to partitioned ledger
  local ledger_file
  ledger_file="$(ledger_current_path "$journal_path")"
  mkdir -p "$(dirname "$ledger_file")"
  echo "$entry" >> "$ledger_file"

  echo "Ledger entry añadida: $entry_id"
  echo "  Contract: $contract_id"
  echo "  Bundle SHA: ${bundle_sha:0:12}..."
  echo "  Previous:  ${previous_hash:0:12}..."
  echo "  Chain length: $(ledger_count "$journal_path")"
  echo "  Ledger file: $ledger_file"

  # Auto git commit
  if [ "$no_git_commit" = false ] && [ -d "$journal_path/.git" ]; then
    (
      cd "$journal_path"
      git add -A
      git commit -m "ledger: append $entry_id for $contract_id" --quiet 2>/dev/null || true
    )
    echo "  Git: committed"
  fi
}

# ─── ledger verify ────────────────────────────────────────────
# Verifies chain integrity across all partitions.

cmd_ledger_verify() {
  local journal_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --journal-path) shift; journal_path="$1"; shift ;;
      *)              shift ;;
    esac
  done

  if [ -z "$journal_path" ]; then
    echo "ERROR: --journal-path requerido" >&2
    return 1
  fi

  echo "=== Ledger Verification ==="
  echo "Journal: $journal_path"
  echo ""

  local line_num=0
  local previous_hash="null"
  local errors=0
  local seen_ids=""

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    line_num=$((line_num + 1))

    local entry_id entry_prev entry_bundle
    entry_id="$(echo "$line" | jq -r '.entry_id')"
    entry_prev="$(echo "$line" | jq -r '.previous_bundle_sha256 // "null"')"
    entry_bundle="$(echo "$line" | jq -r '.bundle_sha256')"

    # Check for duplicate entry IDs
    if echo "$seen_ids" | grep -qF "$entry_id"; then
      echo "  [FAIL] Duplicate entry_id at #$line_num: $entry_id"
      errors=$((errors + 1))
    fi
    seen_ids="$seen_ids $entry_id"

    # Validate chain linkage
    if [ "$entry_prev" != "$previous_hash" ]; then
      echo "  [FAIL] Chain break at entry #$line_num ($entry_id)"
      echo "    Expected previous: $previous_hash"
      echo "    Got:               $entry_prev"
      errors=$((errors + 1))
    fi

    # Validate required fields
    if ! validate_ledger_entry "$line" > /dev/null 2>&1; then
      echo "  [FAIL] Invalid entry at #$line_num ($entry_id)"
      errors=$((errors + 1))
    fi

    previous_hash="$entry_bundle"
  done < <(ledger_all_entries "$journal_path")

  echo "  Entries: $line_num"

  if [ "$errors" -eq 0 ]; then
    echo "  Chain: UNBROKEN"
    echo ""
    echo "Status: PASS"
    return 0
  else
    echo "  Chain: BROKEN ($errors issue(s))"
    echo ""
    echo "Status: FAIL"
    return 1
  fi
}

# ─── ledger last ──────────────────────────────────────────────

cmd_ledger_last() {
  local journal_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --journal-path) shift; journal_path="$1"; shift ;;
      *)              shift ;;
    esac
  done

  if [ -z "$journal_path" ]; then
    echo "ERROR: --journal-path requerido" >&2
    return 1
  fi

  local last_line
  last_line="$(ledger_all_entries "$journal_path" | tail -1)"

  if [ -z "$last_line" ]; then
    echo "Ledger vacío"
    return 0
  fi

  echo "$last_line" | jq .
}

# ─── ledger list ──────────────────────────────────────────────

cmd_ledger_list() {
  local journal_path=""
  local contract_filter=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --journal-path) shift; journal_path="$1"; shift ;;
      --contract)     shift; contract_filter="$1"; shift ;;
      *)              shift ;;
    esac
  done

  if [ -z "$journal_path" ]; then
    echo "ERROR: --journal-path requerido" >&2
    return 1
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue

    local contract
    contract="$(echo "$line" | jq -r '.contract_id')"

    if [ -n "$contract_filter" ] && [ "$contract" != "$contract_filter" ]; then
      continue
    fi

    echo "$line" | jq -r '"  \(.entry_id)\t\(.recorded_at)\t\(.contract_id)\t\(.bundle_sha256[0:12])..."'
  done < <(ledger_all_entries "$journal_path")
}

# ═══════════════════════════════════════════════════════════════
# REDACTION COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── redact (directory) ──────────────────────────────────────

cmd_redact() {
  local target_dir="$1"
  shift

  local patterns=(email api_key token secret ip path ghp github_pat sk)
  local dry_run=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --patterns) shift; IFS=',' read -ra patterns <<< "$1"; shift ;;
      --dry-run)  dry_run=true; shift ;;
      *)          shift ;;
    esac
  done

  if [ ! -d "$target_dir" ]; then
    echo "ERROR: directorio no encontrado: $target_dir" >&2
    return 1
  fi

  find "$target_dir" -type f \( -name "*.json" -o -name "*.txt" -o -name "*.md" -o -name "*.log" -o -name "*.yml" -o -name "*.yaml" -o -name "*.jsonl" \) | sort | while read -r file; do
    local count
    count="$(redact_content "$file" "${patterns[@]}" 2>&1 1>/dev/null)"

    if [ "$count" -gt 0 ]; then
      if [ "$dry_run" = true ]; then
        echo "  [DRY-RUN] $file: $count replacements"
      else
        local redacted
        redacted="$(redact_content "$file" "${patterns[@]}" 2>/dev/null)"
        echo "$redacted" > "$file"
        echo "  Redacted: $file ($count replacements)"
      fi
    fi
  done

  echo ""
  echo "Patterns: ${patterns[*]}"
}

# ─── redact-file (single file) ──────────────────────────────

cmd_redact_file() {
  local file="$1"
  shift

  local patterns=(email api_key token secret ip path ghp github_pat sk)
  local dry_run=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --patterns) shift; IFS=',' read -ra patterns <<< "$1"; shift ;;
      --dry-run)  dry_run=true; shift ;;
      *)          shift ;;
    esac
  done

  if [ ! -f "$file" ]; then
    echo "ERROR: archivo no encontrado: $file" >&2
    return 1
  fi

  local count
  count="$(redact_content "$file" "${patterns[@]}" 2>&1 1>/dev/null)"

  if [ "$dry_run" = true ]; then
    echo "[DRY-RUN] $file: $count replacements"
  elif [ "$count" -gt 0 ]; then
    local redacted
    redacted="$(redact_content "$file" "${patterns[@]}" 2>/dev/null)"
    echo "$redacted" > "$file"
    echo "Redacted: $file ($count replacements)"
  else
    echo "No replacements needed: $file"
  fi
}

# ═══════════════════════════════════════════════════════════════
# VERIFY COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── verify cross-check ──────────────────────────────────────
# Hybrid: local verifications + checklist for manual API checks.

cmd_verify_crosscheck() {
  local journal_path=""
  local manifest_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --journal-path) shift; journal_path="$1"; shift ;;
      --manifest)     shift; manifest_path="$1"; shift ;;
      *)              shift ;;
    esac
  done

  echo "=== Cross-Check Verification ==="
  echo ""

  local errors=0

  # 1. Bundle integrity (if manifest provided)
  if [ -n "$manifest_path" ] && [ -f "$manifest_path" ]; then
    echo "─── Bundle Integrity ───"
    if cmd_bundle_verify "$manifest_path" > /dev/null 2>&1; then
      echo "  [OK] Bundle integrity verified"
    else
      echo "  [FAIL] Bundle integrity check failed"
      errors=$((errors + 1))
    fi
    echo ""
  fi

  # 2. Ledger chain (if journal provided)
  if [ -n "$journal_path" ]; then
    echo "─── Ledger Chain ───"
    if cmd_ledger_verify --journal-path "$journal_path" > /dev/null 2>&1; then
      echo "  [OK] Ledger chain unbroken"
    else
      echo "  [FAIL] Ledger chain broken"
      errors=$((errors + 1))
    fi
    echo ""
  fi

  # 3. Cross-reference checklist (manual checks for APIs)
  echo "─── Manual Cross-Check Checklist ───"
  echo "  [ ] evidence_url in OpenProject points to existing bundle"
  echo "  [ ] evidence_sha256 in OpenProject matches bundle_sha256"
  echo "  [ ] ledger_entry in OpenProject matches a valid ledger entry"
  echo "  [ ] GitHub PR referenced in contract exists and is merged"
  echo "  [ ] Git commits referenced in evidence exist in the repo"
  echo ""

  if [ "$errors" -eq 0 ]; then
    echo "Local checks: PASS"
    echo "Manual checks: PENDING (complete checklist above)"
  else
    echo "Status: FAIL ($errors local issue(s))"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# USAGE & ROUTER
# ═══════════════════════════════════════════════════════════════

usage() {
  cat <<'EOF'
ev-cli.sh — CLI de Evidence para Sentinels (Protocol v1.0)

Bundles:
  ev-cli.sh bundle create <CONTRACT_ID> <ARTIFACTS_DIR> [--journal-path PATH]
            [--sources-op STATUS] [--sources-gh STATUS] [--redaction-patterns p1,p2]
  ev-cli.sh bundle verify <MANIFEST_PATH>
  ev-cli.sh bundle list <JOURNAL_PATH> [CONTRACT_ID]

Ledger:
  ev-cli.sh ledger append --contract CTR --manifest PATH --journal-path PATH
            [--repo REPO] [--evidence-url URL] [--notes TEXT]
            [--actor-mapping PATH] [--no-git-commit]
  ev-cli.sh ledger verify --journal-path PATH
  ev-cli.sh ledger last --journal-path PATH
  ev-cli.sh ledger list --journal-path PATH [--contract CTR]

Redaction:
  ev-cli.sh redact <DIR> [--patterns email,token,secret] [--dry-run]
  ev-cli.sh redact-file <FILE> [--patterns email,token] [--dry-run]

Verification:
  ev-cli.sh verify cross-check [--journal-path PATH] [--manifest PATH]

Examples:
  ev-cli.sh bundle create CTR-sentinels-hub-20260302 ./artifacts/ --journal-path ~/journal
  ev-cli.sh bundle verify bundles/2026/03/bundle-xxx/bundle-manifest.json
  ev-cli.sh ledger append --contract CTR-xxx --manifest path/manifest.json --journal-path ~/journal
  ev-cli.sh ledger verify --journal-path ~/journal
  ev-cli.sh redact ./artifacts/ --dry-run
  ev-cli.sh redact-file evidence.json --patterns email,token
  ev-cli.sh verify cross-check --journal-path ~/journal --manifest path/manifest.json

Requires:
  sha256sum or shasum, jq, python3, git
EOF
}

main() {
  if [ $# -lt 1 ]; then
    usage
    exit 1
  fi

  local domain="$1"
  shift

  case "$domain" in
    bundle)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        create)  cmd_bundle_create "$@" ;;
        verify)  cmd_bundle_verify "$@" ;;
        list)    cmd_bundle_list "$@" ;;
        *)       echo "ERROR: subcomando desconocido: bundle $subcmd" >&2; exit 1 ;;
      esac
      ;;
    ledger)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        append)  cmd_ledger_append "$@" ;;
        verify)  cmd_ledger_verify "$@" ;;
        last)    cmd_ledger_last "$@" ;;
        list)    cmd_ledger_list "$@" ;;
        *)       echo "ERROR: subcomando desconocido: ledger $subcmd" >&2; exit 1 ;;
      esac
      ;;
    redact)
      cmd_redact "$@"
      ;;
    redact-file)
      cmd_redact_file "$@"
      ;;
    verify)
      local subcmd="${1:-}"
      shift 2>/dev/null || true
      case "$subcmd" in
        cross-check) cmd_verify_crosscheck "$@" ;;
        *)           echo "ERROR: subcomando desconocido: verify $subcmd" >&2; exit 1 ;;
      esac
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "ERROR: dominio desconocido: $domain" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
