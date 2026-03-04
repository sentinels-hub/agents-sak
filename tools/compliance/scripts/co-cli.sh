#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# co-cli.sh — CLI de Compliance para Sentinels
# ─────────────────────────────────────────────────────────────
# Alineado con Sentinels Protocol v1.0 (Lighthouse)
#
# Estructura real:
#   audit/<CONTRACT_ID>/audit-trail.jsonl
#
# Requiere: jq, python3, git
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/co-core.sh"

# ═══════════════════════════════════════════════════════════════
# AUDIT COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── audit append ─────────────────────────────────────────────
# Appends entry to audit trail: audit/<CONTRACT_ID>/audit-trail.jsonl
# Auto git commit (disable with --no-git-commit)

cmd_audit_append() {
  local contract_id=""
  local gate=""
  local agent=""
  local action=""
  local controls=""
  local evidence_ref=""
  local result=""
  local notes=""
  local journal_path=""
  local no_git_commit=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --contract)        shift; contract_id="$1"; shift ;;
      --gate)            shift; gate="$1"; shift ;;
      --agent)           shift; agent="$1"; shift ;;
      --action)          shift; action="$1"; shift ;;
      --controls)        shift; controls="$1"; shift ;;
      --evidence-ref)    shift; evidence_ref="$1"; shift ;;
      --result)          shift; result="$1"; shift ;;
      --notes)           shift; notes="$1"; shift ;;
      --journal-path)    shift; journal_path="$1"; shift ;;
      --no-git-commit)   no_git_commit=true; shift ;;
      *)                 echo "ERROR: opción desconocida: $1" >&2; return 1 ;;
    esac
  done

  if [ -z "$contract_id" ] || [ -z "$gate" ] || [ -z "$agent" ] || [ -z "$action" ] || [ -z "$controls" ] || [ -z "$evidence_ref" ] || [ -z "$result" ] || [ -z "$journal_path" ]; then
    echo "ERROR: --contract, --gate, --agent, --action, --controls, --evidence-ref, --result y --journal-path son requeridos" >&2
    return 1
  fi

  local timestamp
  timestamp="$(iso_timestamp)"

  # Build controls array from comma-separated string
  local controls_json
  controls_json="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1].split(',')))" "$controls")"

  # Build entry
  local entry
  entry="$(python3 -c "
import json
import sys

entry = {
    'timestamp': sys.argv[1],
    'contract_id': sys.argv[2],
    'gate': sys.argv[3],
    'agent': sys.argv[4],
    'action': sys.argv[5],
    'controls': json.loads(sys.argv[6]),
    'evidence_ref': sys.argv[7],
    'result': sys.argv[8]
}

if sys.argv[9]:
    entry['notes'] = sys.argv[9]

print(json.dumps(entry, separators=(',', ':')))
" "$timestamp" "$contract_id" "$gate" "$agent" "$action" "$controls_json" "$evidence_ref" "$result" "$notes")"

  # Validate before appending
  if ! validate_audit_entry "$entry" > /dev/null 2>&1; then
    echo "ERROR: entry validation failed" >&2
    validate_audit_entry "$entry" 2>&1 || true
    return 1
  fi

  # Append to audit trail
  local trail_file
  trail_file="$(audit_trail_path "$journal_path" "$contract_id")"
  mkdir -p "$(dirname "$trail_file")"
  echo "$entry" >> "$trail_file"

  local entry_count
  entry_count="$(audit_trail_count "$journal_path" "$contract_id")"

  echo "Audit entry añadida:"
  echo "  Contract: $contract_id"
  echo "  Gate: $gate"
  echo "  Agent: $agent"
  echo "  Action: $action"
  echo "  Controls: $controls"
  echo "  Result: $result"
  echo "  Trail entries: $entry_count"
  echo "  Trail file: $trail_file"

  # Auto git commit
  if [ "$no_git_commit" = false ] && [ -d "$journal_path/.git" ]; then
    (
      cd "$journal_path"
      git add -A
      git commit -m "audit: $action $gate for $contract_id ($result)" --quiet 2>/dev/null || true
    )
    echo "  Git: committed"
  fi
}

# ─── audit list ───────────────────────────────────────────────

cmd_audit_list() {
  local contract_id=""
  local journal_path=""
  local gate_filter=""
  local action_filter=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --contract)      shift; contract_id="$1"; shift ;;
      --journal-path)  shift; journal_path="$1"; shift ;;
      --gate)          shift; gate_filter="$1"; shift ;;
      --action)        shift; action_filter="$1"; shift ;;
      *)               shift ;;
    esac
  done

  if [ -z "$contract_id" ] || [ -z "$journal_path" ]; then
    echo "ERROR: --contract y --journal-path son requeridos" >&2
    return 1
  fi

  local count=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue

    # Apply filters
    if [ -n "$gate_filter" ]; then
      local entry_gate
      entry_gate="$(echo "$line" | jq -r '.gate')"
      [ "$entry_gate" != "$gate_filter" ] && continue
    fi

    if [ -n "$action_filter" ]; then
      local entry_action
      entry_action="$(echo "$line" | jq -r '.action')"
      [ "$entry_action" != "$action_filter" ] && continue
    fi

    echo "$line" | jq -r '"  \(.timestamp)\t\(.gate)\t\(.agent)\t\(.action)\t\(.result)\t\(.controls | join(","))"'
    count=$((count + 1))
  done < <(audit_trail_entries "$journal_path" "$contract_id")

  if [ "$count" -eq 0 ]; then
    echo "No audit entries found for $contract_id"
  else
    echo ""
    echo "Total: $count entries"
  fi
}

# ─── audit last ───────────────────────────────────────────────

cmd_audit_last() {
  local contract_id=""
  local journal_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --contract)      shift; contract_id="$1"; shift ;;
      --journal-path)  shift; journal_path="$1"; shift ;;
      *)               shift ;;
    esac
  done

  if [ -z "$contract_id" ] || [ -z "$journal_path" ]; then
    echo "ERROR: --contract y --journal-path son requeridos" >&2
    return 1
  fi

  local last_line
  last_line="$(audit_trail_last "$journal_path" "$contract_id")"

  if [ -z "$last_line" ]; then
    echo "Audit trail vacío para $contract_id"
    return 0
  fi

  echo "$last_line" | jq .
}

# ─── audit verify ─────────────────────────────────────────────
# Completeness verification (4 checks from catalog)

cmd_audit_verify() {
  local contract_id=""
  local journal_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --contract)      shift; contract_id="$1"; shift ;;
      --journal-path)  shift; journal_path="$1"; shift ;;
      *)               shift ;;
    esac
  done

  if [ -z "$contract_id" ] || [ -z "$journal_path" ]; then
    echo "ERROR: --contract y --journal-path son requeridos" >&2
    return 1
  fi

  echo "=== Audit Trail Verification ==="
  echo "Contract: $contract_id"
  echo ""

  local trail_file
  trail_file="$(audit_trail_path "$journal_path" "$contract_id")"

  if [ ! -f "$trail_file" ]; then
    echo "  [FAIL] No audit trail found"
    echo ""
    echo "Status: FAIL"
    return 1
  fi

  local entries
  entries="$(cat "$trail_file")"
  local errors=0

  # Check 1: All gates have at least one control_verified entry
  echo "─── Check 1: Gates coverage ───"
  local gates_covered
  gates_covered="$(echo "$entries" | jq -r 'select(.action == "control_verified") | .gate' | sort -u)"

  local missing_gates=""
  for g in G0 G1 G2 G3 G4 G5 G6 G7 G8 G9; do
    if ! echo "$gates_covered" | grep -qF "$g"; then
      missing_gates="$missing_gates $g"
    fi
  done

  if [ -z "$missing_gates" ]; then
    echo "  [OK] All gates covered"
  else
    echo "  [WARN] Missing gates:$missing_gates"
    errors=$((errors + 1))
  fi

  # Check 2: No control_failed without corrective_action
  echo "─── Check 2: Unresolved failures ───"
  local unresolved
  unresolved="$(python3 -c "
import json, sys

entries = []
for line in sys.argv[1].strip().split('\n'):
    if line.strip():
        entries.append(json.loads(line))

# Find controls that failed
failed_controls = set()
corrected_controls = set()

for e in entries:
    if e['action'] == 'control_failed':
        for c in e.get('controls', []):
            failed_controls.add(c)
    elif e['action'] == 'corrective_action':
        for c in e.get('controls', []):
            corrected_controls.add(c)

unresolved = failed_controls - corrected_controls
if unresolved:
    print(','.join(sorted(unresolved)))
" "$entries")"

  if [ -z "$unresolved" ]; then
    echo "  [OK] No unresolved failures"
  else
    echo "  [FAIL] Unresolved failures: $unresolved"
    errors=$((errors + 1))
  fi

  # Check 3: All controls appear at least once as PASS
  echo "─── Check 3: Control coverage ───"
  local registry
  registry="$(control_registry)"
  local uncovered
  uncovered="$(python3 -c "
import json, sys

controls = json.loads(sys.argv[1])
entries_text = sys.argv[2]

entries = []
for line in entries_text.strip().split('\n'):
    if line.strip():
        entries.append(json.loads(line))

# Find controls with PASS
passed = set()
for e in entries:
    if e.get('result') == 'PASS':
        for c in e.get('controls', []):
            passed.add(c)

all_ids = {c['control_id'] for c in controls}
uncovered = sorted(all_ids - passed)
if uncovered:
    print(','.join(uncovered))
" "$registry" "$entries")"

  if [ -z "$uncovered" ]; then
    echo "  [OK] All controls covered with PASS"
  else
    local uncovered_count
    uncovered_count="$(echo "$uncovered" | tr ',' '\n' | wc -l | tr -d ' ')"
    echo "  [WARN] $uncovered_count controls without PASS: $uncovered"
    errors=$((errors + 1))
  fi

  # Check 4: Non-conformities have resolution
  echo "─── Check 4: Non-conformity resolution ───"
  local unresolved_ncs
  unresolved_ncs="$(python3 -c "
import json, sys

entries = []
for line in sys.argv[1].strip().split('\n'):
    if line.strip():
        entries.append(json.loads(line))

nc_controls = set()
resolved_controls = set()

for e in entries:
    if e['action'] == 'non_conformity':
        for c in e.get('controls', []):
            nc_controls.add(c)
    elif e['action'] in ('corrective_action', 'risk_accepted'):
        for c in e.get('controls', []):
            resolved_controls.add(c)

unresolved = nc_controls - resolved_controls
if unresolved:
    print(','.join(sorted(unresolved)))
" "$entries")"

  if [ -z "$unresolved_ncs" ]; then
    echo "  [OK] All non-conformities resolved"
  else
    echo "  [FAIL] Unresolved non-conformities: $unresolved_ncs"
    errors=$((errors + 1))
  fi

  echo ""
  local total_entries
  total_entries="$(echo "$entries" | wc -l | tr -d ' ')"
  echo "  Total entries: $total_entries"

  if [ "$errors" -eq 0 ]; then
    echo ""
    echo "Status: PASS"
    return 0
  else
    echo ""
    echo "Status: INCOMPLETE ($errors issue(s))"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# CONTROL COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── control list ─────────────────────────────────────────────

cmd_control_list() {
  local framework_filter=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --framework)  shift; framework_filter="$1"; shift ;;
      *)            shift ;;
    esac
  done

  local controls
  if [ -n "$framework_filter" ]; then
    controls="$(controls_by_framework "$framework_filter")"
  else
    controls="$(control_registry)"
  fi

  python3 -c "
import json, sys

controls = json.loads(sys.argv[1])

if not controls:
    print('No controls found')
    sys.exit(0)

# Group by framework
frameworks = {}
for c in controls:
    fw = c['framework']
    if fw not in frameworks:
        frameworks[fw] = []
    frameworks[fw].append(c)

fw_order = ['ens_alto', 'iso_27001', 'iso_9001', 'soc2', 'sentinels']
for fw in fw_order:
    if fw not in frameworks:
        continue
    print(f'\n  {fw} ({len(frameworks[fw])} controls)')
    print(f'  {\"─\" * 50}')
    for c in frameworks[fw]:
        gates = ','.join(c['gates'])
        agent = c.get('agent', '')
        print(f'  {c[\"control_id\"]:30s} {gates:15s} {agent:15s} {c[\"name\"]}')

total = len(controls)
print(f'\nTotal: {total} controls')
" "$controls"
}

# ─── control get ──────────────────────────────────────────────

cmd_control_get() {
  local control_id=""

  local positionals=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -*)  shift ;;
      *)   positionals+=("$1"); shift ;;
    esac
  done

  control_id="${positionals[0]:-}"

  if [ -z "$control_id" ]; then
    echo "ERROR: control_id requerido" >&2
    echo "Uso: co-cli.sh control get <CONTROL_ID>" >&2
    return 1
  fi

  control_get "$control_id"
}

# ─── control check ────────────────────────────────────────────
# Estado de controles vs audit trail (score)

cmd_control_check() {
  local contract_id=""
  local journal_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --contract)      shift; contract_id="$1"; shift ;;
      --journal-path)  shift; journal_path="$1"; shift ;;
      *)               shift ;;
    esac
  done

  if [ -z "$contract_id" ] || [ -z "$journal_path" ]; then
    echo "ERROR: --contract y --journal-path son requeridos" >&2
    return 1
  fi

  echo "=== Control Compliance Check ==="
  echo "Contract: $contract_id"
  echo ""

  local score
  score="$(compliance_score "$journal_path" "$contract_id")"

  # Display per-framework scores
  python3 -c "
import json, sys

data = json.loads(sys.argv[1])

fw_names = {
    'ens_alto': 'ENS Alta',
    'iso_27001': 'ISO 27001',
    'iso_9001': 'ISO 9001',
    'soc2': 'SOC 2',
    'sentinels': 'Sentinels'
}

fw_order = ['ens_alto', 'iso_27001', 'iso_9001', 'soc2', 'sentinels']
print(f'  {\"Framework\":15s} {\"Total\":>6s} {\"Pass\":>6s} {\"Fail\":>6s} {\"Pending\":>8s} {\"Coverage\":>9s}')
print(f'  {\"─\" * 55}')

for fw in fw_order:
    if fw not in data['frameworks']:
        continue
    d = data['frameworks'][fw]
    name = fw_names.get(fw, fw)
    print(f'  {name:15s} {d[\"total\"]:6d} {d[\"pass\"]:6d} {d[\"fail\"]:6d} {d[\"pending\"]:8d} {d[\"coverage\"]:8.1f}%')

t = data['total']
print(f'  {\"─\" * 55}')
print(f'  {\"TOTAL\":15s} {t[\"total\"]:6d} {t[\"pass\"]:6d} {t[\"fail\"]:6d} {t[\"pending\"]:8d} {t[\"coverage\"]:8.1f}%')
" "$score"

  echo ""

  # Show verified controls
  local verified_count
  verified_count="$(echo "$score" | jq '.controls_verified | length')"
  local total_controls
  total_controls="$(echo "$score" | jq '.total.total')"
  echo "Controls with audit trail entry: $verified_count/$total_controls"
}

# ═══════════════════════════════════════════════════════════════
# REPORT COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── report checklist ─────────────────────────────────────────
# Generates checklist populated from audit trail

cmd_report_checklist() {
  local contract_id=""
  local journal_path=""
  local agent="@jarvis"
  local output=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --contract)      shift; contract_id="$1"; shift ;;
      --journal-path)  shift; journal_path="$1"; shift ;;
      --agent)         shift; agent="$1"; shift ;;
      --output)        shift; output="$1"; shift ;;
      *)               shift ;;
    esac
  done

  if [ -z "$contract_id" ] || [ -z "$journal_path" ]; then
    echo "ERROR: --contract y --journal-path son requeridos" >&2
    return 1
  fi

  local template_path="$SCRIPT_DIR/../templates/control-checklist.md"
  if [ ! -f "$template_path" ]; then
    echo "ERROR: template no encontrado: $template_path" >&2
    return 1
  fi

  local template
  template="$(cat "$template_path")"

  local date_now
  date_now="$(date -u +%Y-%m-%d)"

  local score
  score="$(compliance_score "$journal_path" "$contract_id")"

  local report
  report="$(python3 -c "
import json, sys

template = sys.argv[1]
contract_id = sys.argv[2]
date_now = sys.argv[3]
agent = sys.argv[4]
score_data = json.loads(sys.argv[5])

# Replace placeholders
report = template
report = report.replace('{CONTRACT_ID}', contract_id)
report = report.replace('{DATE}', date_now)
report = report.replace('{AGENT}', agent)

# Fill in results from audit trail
verified = score_data.get('controls_verified', {})
for ctrl_id, result in verified.items():
    if result == 'PASS':
        report = report.replace(f'| [ ] PASS / [ ] FAIL |', f'| [x] PASS / [ ] FAIL |', 1)

# Fill summary
total = score_data['total']
report = report.replace('| PASS | |', f'| PASS | {total[\"pass\"]} |')
report = report.replace('| FAIL | |', f'| FAIL | {total[\"fail\"]} |')
report = report.replace('| Coverage | % |', f'| Coverage | {total[\"coverage\"]}% |')

print(report)
" "$template" "$contract_id" "$date_now" "$agent" "$score")"

  if [ -n "$output" ]; then
    echo "$report" > "$output"
    echo "Checklist generado: $output"
  else
    echo "$report"
  fi
}

# ─── report audit ─────────────────────────────────────────────
# Generates audit report populated from audit trail

cmd_report_audit() {
  local contract_id=""
  local journal_path=""
  local agent="@jarvis"
  local repo=""
  local version=""
  local output=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --contract)      shift; contract_id="$1"; shift ;;
      --journal-path)  shift; journal_path="$1"; shift ;;
      --agent)         shift; agent="$1"; shift ;;
      --repo)          shift; repo="$1"; shift ;;
      --version)       shift; version="$1"; shift ;;
      --output)        shift; output="$1"; shift ;;
      *)               shift ;;
    esac
  done

  if [ -z "$contract_id" ] || [ -z "$journal_path" ]; then
    echo "ERROR: --contract y --journal-path son requeridos" >&2
    return 1
  fi

  local template_path="$SCRIPT_DIR/../templates/audit-report.md"
  if [ ! -f "$template_path" ]; then
    echo "ERROR: template no encontrado: $template_path" >&2
    return 1
  fi

  if [ -z "$repo" ]; then
    repo="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "unknown")")"
  fi

  local template
  template="$(cat "$template_path")"

  local date_now
  date_now="$(date -u +%Y-%m-%d)"

  local score
  score="$(compliance_score "$journal_path" "$contract_id")"

  local entries=""
  local trail_file
  trail_file="$(audit_trail_path "$journal_path" "$contract_id")"
  if [ -f "$trail_file" ]; then
    entries="$(cat "$trail_file")"
  fi

  local report
  report="$(python3 -c "
import json, sys

template = sys.argv[1]
contract_id = sys.argv[2]
date_now = sys.argv[3]
agent = sys.argv[4]
repo = sys.argv[5]
version = sys.argv[6] if sys.argv[6] else 'N/A'
score_data = json.loads(sys.argv[7])
entries_text = sys.argv[8]

# Parse entries
entries = []
for line in entries_text.strip().split('\n'):
    if line.strip():
        entries.append(json.loads(line))

report = template
report = report.replace('{CONTRACT_ID}', contract_id)
report = report.replace('{DATE}', date_now)
report = report.replace('{AGENT}', agent)
report = report.replace('{REPO}', repo)
report = report.replace('{VERSION}', version)

# Fill compliance score table
fw_map = {
    'ens_alto': 'ENS Alta',
    'iso_27001': 'ISO 27001',
    'iso_9001': 'ISO 9001',
    'soc2': 'SOC 2',
    'sentinels': 'Sentinels'
}

for fw_key, fw_name in fw_map.items():
    if fw_key in score_data['frameworks']:
        d = score_data['frameworks'][fw_key]
        old = f'| {fw_name} | {d[\"total\"]} | | | % |'
        new = f'| {fw_name} | {d[\"total\"]} | {d[\"pass\"]} | {d[\"fail\"]} | {d[\"coverage\"]}% |'
        report = report.replace(old, new)

t = score_data['total']
report = report.replace('| **Total** | **24** | | | **%** |',
                        f'| **Total** | **{t[\"total\"]}** | **{t[\"pass\"]}** | **{t[\"fail\"]}** | **{t[\"coverage\"]}%** |')

# Fill gate verification status from entries
gate_status = {}
for e in entries:
    gate = e.get('gate', '')
    result = e.get('result', '')
    if e.get('action') == 'control_verified' and result == 'PASS':
        gate_status[gate] = 'PASS'
    elif gate not in gate_status:
        gate_status[gate] = result

# Summary
total_entries = len(entries)
summary = f'Compliance audit for contract {contract_id}. '
summary += f'{t[\"pass\"]}/{t[\"total\"]} controls passed ({t[\"coverage\"]}% coverage). '
summary += f'{total_entries} audit trail entries recorded.'
report = report.replace('{SUMMARY}', summary)

report = report.replace('{RECOMMENDATIONS}', 'No additional recommendations at this time.')

print(report)
" "$template" "$contract_id" "$date_now" "$agent" "$repo" "$version" "$score" "$entries")"

  if [ -n "$output" ]; then
    echo "$report" > "$output"
    echo "Audit report generado: $output"
  else
    echo "$report"
  fi
}

# ═══════════════════════════════════════════════════════════════
# VERIFY COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── verify completeness ─────────────────────────────────────
# All controls covered?

cmd_verify_completeness() {
  local contract_id=""
  local journal_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --contract)      shift; contract_id="$1"; shift ;;
      --journal-path)  shift; journal_path="$1"; shift ;;
      *)               shift ;;
    esac
  done

  if [ -z "$contract_id" ] || [ -z "$journal_path" ]; then
    echo "ERROR: --contract y --journal-path son requeridos" >&2
    return 1
  fi

  echo "=== Completeness Verification ==="
  echo "Contract: $contract_id"
  echo ""

  local score
  score="$(compliance_score "$journal_path" "$contract_id")"

  local total pass pending
  total="$(echo "$score" | jq '.total.total')"
  pass="$(echo "$score" | jq '.total.pass')"
  pending="$(echo "$score" | jq '.total.pending')"

  echo "  Controls: $total"
  echo "  Passed:   $pass"
  echo "  Pending:  $pending"
  echo ""

  if [ "$pass" -eq "$total" ]; then
    echo "Status: COMPLETE — all $total controls verified"
    return 0
  else
    local missing
    missing="$(echo "$score" | jq -r '
      .frameworks as $fws |
      [.frameworks | to_entries[] | .value as $v | .key as $k |
       select($v.pending > 0 or $v.fail > 0) | $k] | join(", ")
    ')"
    echo "Status: INCOMPLETE — $pass/$total controls passed"
    echo "  Frameworks with gaps: $missing"
    return 1
  fi
}

# ─── verify non-conformities ─────────────────────────────────
# Non-conformities without resolution?

cmd_verify_nonconformities() {
  local contract_id=""
  local journal_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --contract)      shift; contract_id="$1"; shift ;;
      --journal-path)  shift; journal_path="$1"; shift ;;
      *)               shift ;;
    esac
  done

  if [ -z "$contract_id" ] || [ -z "$journal_path" ]; then
    echo "ERROR: --contract y --journal-path son requeridos" >&2
    return 1
  fi

  echo "=== Non-conformity Verification ==="
  echo "Contract: $contract_id"
  echo ""

  local trail_file
  trail_file="$(audit_trail_path "$journal_path" "$contract_id")"

  if [ ! -f "$trail_file" ]; then
    echo "  No audit trail found"
    echo ""
    echo "Status: N/A"
    return 0
  fi

  local entries
  entries="$(cat "$trail_file")"

  python3 -c "
import json, sys

entries = []
for line in sys.argv[1].strip().split('\n'):
    if line.strip():
        entries.append(json.loads(line))

nc_entries = [e for e in entries if e['action'] == 'non_conformity']
ca_entries = [e for e in entries if e['action'] in ('corrective_action', 'risk_accepted')]

nc_controls = set()
for e in nc_entries:
    for c in e.get('controls', []):
        nc_controls.add(c)

resolved_controls = set()
for e in ca_entries:
    for c in e.get('controls', []):
        resolved_controls.add(c)

unresolved = nc_controls - resolved_controls

print(f'  Non-conformities found: {len(nc_entries)}')
print(f'  Controls affected: {len(nc_controls)}')
print(f'  Resolved: {len(resolved_controls)}')
print(f'  Unresolved: {len(unresolved)}')
print()

if nc_entries:
    print('  Non-conformity details:')
    for e in nc_entries:
        ctrls = ','.join(e.get('controls', []))
        status = 'RESOLVED' if all(c in resolved_controls for c in e.get('controls', [])) else 'OPEN'
        print(f'    {e[\"timestamp\"]}  {e[\"gate\"]}  {ctrls}  [{status}]')
        if e.get('notes'):
            print(f'      Notes: {e[\"notes\"]}')
    print()

if unresolved:
    print(f'Status: FAIL — {len(unresolved)} unresolved: {\",\".join(sorted(unresolved))}')
    sys.exit(1)
elif nc_entries:
    print('Status: PASS — all non-conformities resolved')
else:
    print('Status: PASS — no non-conformities found')
" "$entries"
}

# ═══════════════════════════════════════════════════════════════
# USAGE & ROUTER
# ═══════════════════════════════════════════════════════════════

usage() {
  cat <<'EOF'
co-cli.sh — CLI de Compliance para Sentinels (Protocol v1.0)

Audit:
  co-cli.sh audit append --contract CTR --gate G5 --agent @agent-smith
            --action control_verified --controls ctrl1,ctrl2
            --evidence-ref "PR #42" --result PASS --journal-path PATH
            [--notes TEXT] [--no-git-commit]
  co-cli.sh audit list --contract CTR --journal-path PATH [--gate G5] [--action control_verified]
  co-cli.sh audit last --contract CTR --journal-path PATH
  co-cli.sh audit verify --contract CTR --journal-path PATH

Controls:
  co-cli.sh control list [--framework sentinels|ens_alto|iso_27001|iso_9001]
  co-cli.sh control get <CONTROL_ID>
  co-cli.sh control check --contract CTR --journal-path PATH

Reports:
  co-cli.sh report checklist --contract CTR --journal-path PATH [--agent @jarvis] [--output FILE]
  co-cli.sh report audit --contract CTR --journal-path PATH [--agent @jarvis]
            [--repo REPO] [--version VER] [--output FILE]

Verification:
  co-cli.sh verify completeness --contract CTR --journal-path PATH
  co-cli.sh verify non-conformities --contract CTR --journal-path PATH

Examples:
  co-cli.sh control list
  co-cli.sh control list --framework sentinels
  co-cli.sh control get SEN-001
  co-cli.sh audit append --contract CTR-test-20260304 --gate G0 --agent @jarvis \
    --action control_verified --controls traceability,process_standardization \
    --evidence-ref "Contract JSON created" --result PASS --journal-path ~/journal
  co-cli.sh audit list --contract CTR-test-20260304 --journal-path ~/journal
  co-cli.sh control check --contract CTR-test-20260304 --journal-path ~/journal

Requires:
  jq, python3, git
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
    audit)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        append)  cmd_audit_append "$@" ;;
        list)    cmd_audit_list "$@" ;;
        last)    cmd_audit_last "$@" ;;
        verify)  cmd_audit_verify "$@" ;;
        *)       echo "ERROR: subcomando desconocido: audit $subcmd" >&2; exit 1 ;;
      esac
      ;;
    control)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        list)   cmd_control_list "$@" ;;
        get)    cmd_control_get "$@" ;;
        check)  cmd_control_check "$@" ;;
        *)      echo "ERROR: subcomando desconocido: control $subcmd" >&2; exit 1 ;;
      esac
      ;;
    report)
      local subcmd="${1:-}"
      shift 2>/dev/null || true
      case "$subcmd" in
        checklist) cmd_report_checklist "$@" ;;
        audit)     cmd_report_audit "$@" ;;
        *)         echo "ERROR: subcomando desconocido: report $subcmd" >&2; exit 1 ;;
      esac
      ;;
    verify)
      local subcmd="${1:-}"
      shift 2>/dev/null || true
      case "$subcmd" in
        completeness)     cmd_verify_completeness "$@" ;;
        non-conformities) cmd_verify_nonconformities "$@" ;;
        *)                echo "ERROR: subcomando desconocido: verify $subcmd" >&2; exit 1 ;;
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
