#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# co-core.sh — Funciones compartidas para Compliance CLI
# ─────────────────────────────────────────────────────────────
# Alineado con Sentinels Protocol v1.0 (Lighthouse)
#
# Requiere: jq, python3
# Importar con:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/co-core.sh"
# ─────────────────────────────────────────────────────────────

# ─── Timestamps ──────────────────────────────────────────────

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

# ─── Audit Entry ID generation ───────────────────────────────
# Format: audit-<YYYYMMDDHHmmss>-<contract_id>
# Example: audit-20260304143000-CTR-sentinels-hub-20260302

generate_audit_entry_id() {
  local contract_id="$1"
  local ts
  ts="$(numeric_timestamp)"
  echo "audit-${ts}-${contract_id}"
}

# ─── Audit Trail Paths ──────────────────────────────────────
# Structure: audit/<CONTRACT_ID>/audit-trail.jsonl

audit_trail_path() {
  local journal_path="$1"
  local contract_id="$2"
  echo "$journal_path/audit/$contract_id/audit-trail.jsonl"
}

# Read all entries from audit trail for a contract
audit_trail_entries() {
  local journal_path="$1"
  local contract_id="$2"
  local trail_file
  trail_file="$(audit_trail_path "$journal_path" "$contract_id")"

  if [ -f "$trail_file" ]; then
    cat "$trail_file"
  fi
}

# Count entries in audit trail
audit_trail_count() {
  local journal_path="$1"
  local contract_id="$2"
  local count
  count="$(audit_trail_entries "$journal_path" "$contract_id" | wc -l | tr -d ' ')"
  echo "$count"
}

# Last entry in audit trail
audit_trail_last() {
  local journal_path="$1"
  local contract_id="$2"
  audit_trail_entries "$journal_path" "$contract_id" | tail -1
}

# ─── Validation ──────────────────────────────────────────────

# Validate an audit entry JSON string against required fields and enums
validate_audit_entry() {
  local entry_json="$1"
  python3 -c "
import json
import sys

required = ['timestamp', 'contract_id', 'gate', 'agent', 'action', 'controls', 'evidence_ref', 'result']
valid_actions = ['control_verified', 'control_failed', 'non_conformity', 'corrective_action', 'risk_accepted', 'audit_completed']
valid_results = ['PASS', 'FAIL', 'PARTIAL', 'N/A']

entry = json.loads(sys.argv[1])

missing = [f for f in required if f not in entry]
if missing:
    print(f'FAIL: missing fields: {\", \".join(missing)}', file=sys.stderr)
    sys.exit(1)

if entry['action'] not in valid_actions:
    print(f'FAIL: invalid action: {entry[\"action\"]}', file=sys.stderr)
    sys.exit(1)

if entry['result'] not in valid_results:
    print(f'FAIL: invalid result: {entry[\"result\"]}', file=sys.stderr)
    sys.exit(1)

if not isinstance(entry.get('controls'), list) or len(entry['controls']) == 0:
    print('FAIL: controls must be a non-empty array', file=sys.stderr)
    sys.exit(1)

import re
if not re.match(r'^G[0-9]$', entry.get('gate', '')):
    print(f'FAIL: invalid gate: {entry.get(\"gate\")}', file=sys.stderr)
    sys.exit(1)

print('OK')
" "$entry_json"
}

# ─── Control Registry ────────────────────────────────────────
# 20 controls embebidos como JSON (self-contained, zero-config)

control_registry() {
  python3 -c "
import json

controls = [
    # ENS Alta (4)
    {'control_id': 'change_control', 'name': 'Change Control', 'description': 'Todo cambio es trazable y aprobado', 'framework': 'ens_alto', 'gates': ['G2', 'G3', 'G5'], 'references': {'ens': 'op.exp.6'}},
    {'control_id': 'traceability', 'name': 'Traceability', 'description': 'Cadena completa Contract→WP→Git→Evidence', 'framework': 'ens_alto', 'gates': ['G0', 'G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7', 'G8', 'G9'], 'references': {'ens': 'op.exp.3'}},
    {'control_id': 'least_privilege', 'name': 'Least Privilege', 'description': 'Identidad verificada, mínimo privilegio', 'framework': 'ens_alto', 'gates': ['G1'], 'references': {'ens': 'op.exp.1'}},
    {'control_id': 'risk_management', 'name': 'Risk Management', 'description': 'Riesgos identificados y mitigados', 'framework': 'ens_alto', 'gates': ['G2', 'G4'], 'references': {'ens': 'op.exp.8'}},

    # ISO 27001 (3)
    {'control_id': 'access_control', 'name': 'Access Control', 'description': 'Control de acceso basado en identidad', 'framework': 'iso_27001', 'gates': ['G1'], 'references': {'iso_27001': 'A.9'}},
    {'control_id': 'secure_change_management', 'name': 'Secure Change Management', 'description': 'Cambios con review de seguridad', 'framework': 'iso_27001', 'gates': ['G4', 'G5'], 'references': {'iso_27001': 'A.14.2.2'}},
    {'control_id': 'incident_learning', 'name': 'Incident Learning', 'description': 'Aprendizaje de incidentes y no conformidades', 'framework': 'iso_27001', 'gates': ['G6', 'G9'], 'references': {'iso_27001': 'A.16'}},

    # ISO 9001 (3)
    {'control_id': 'process_standardization', 'name': 'Process Standardization', 'description': 'Procesos estandarizados y repetibles', 'framework': 'iso_9001', 'gates': ['G0', 'G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7', 'G8', 'G9'], 'references': {'iso_9001': '8.1'}},
    {'control_id': 'evidence_based_decisions', 'name': 'Evidence-based Decisions', 'description': 'Decisiones basadas en datos y evidencia', 'framework': 'iso_9001', 'gates': ['G2', 'G6'], 'references': {'iso_9001': '9.1'}},
    {'control_id': 'continuous_improvement', 'name': 'Continuous Improvement', 'description': 'Mejora continua documentada', 'framework': 'iso_9001', 'gates': ['G9'], 'references': {'iso_9001': '10.2'}},

    # SOC 2 Type II (4)
    {'control_id': 'soc2_cc6', 'name': 'Logical and Physical Access', 'description': 'Control de acceso lógico y físico', 'framework': 'soc2', 'gates': ['G1', 'G4'], 'references': {'soc2': 'CC6'}},
    {'control_id': 'soc2_cc7', 'name': 'System Operations', 'description': 'Operaciones del sistema monitoreadas', 'framework': 'soc2', 'gates': ['G6', 'G7'], 'references': {'soc2': 'CC7'}},
    {'control_id': 'soc2_cc8', 'name': 'Change Management', 'description': 'Gestión de cambios controlada', 'framework': 'soc2', 'gates': ['G2', 'G3', 'G4', 'G5'], 'references': {'soc2': 'CC8'}},
    {'control_id': 'soc2_pi1', 'name': 'Processing Integrity', 'description': 'Integridad de procesamiento verificada', 'framework': 'soc2', 'gates': ['G6', 'G8'], 'references': {'soc2': 'PI1'}},

    # Sentinels-specific (10)
    {'control_id': 'SEN-001', 'name': 'Identity verification', 'description': 'Actor identidad verificada en OP y Git', 'framework': 'sentinels', 'gates': ['G1'], 'agent': '@jarvis', 'evidence_required': ['Actor mapping', 'OP me', 'Git config']},
    {'control_id': 'SEN-002', 'name': 'Planning completeness', 'description': 'WP con estimación, scope, AC', 'framework': 'sentinels', 'gates': ['G2'], 'agent': '@inception', 'evidence_required': ['WP con campos completos']},
    {'control_id': 'SEN-003', 'name': 'Implementation traceability', 'description': 'Branch+commits vinculados a WP', 'framework': 'sentinels', 'gates': ['G3'], 'agent': '@gtd', 'evidence_required': ['Branch name', 'Commit messages', 'PR']},
    {'control_id': 'SEN-004', 'name': 'Security analysis', 'description': 'Scan de vulnerabilidades', 'framework': 'sentinels', 'gates': ['G4'], 'agent': '@morpheus', 'evidence_required': ['Security scan report']},
    {'control_id': 'SEN-005', 'name': 'Code review', 'description': 'Review con scoring 4 capas', 'framework': 'sentinels', 'gates': ['G5'], 'agent': '@agent-smith', 'evidence_required': ['Review comments', 'Approval']},
    {'control_id': 'SEN-006', 'name': 'QA verification', 'description': 'Tests funcionales + compliance', 'framework': 'sentinels', 'gates': ['G6'], 'agent': '@oracle', 'evidence_required': ['Test report', 'QA checklist']},
    {'control_id': 'SEN-007', 'name': 'Deployment controlled', 'description': 'Deploy con health check', 'framework': 'sentinels', 'gates': ['G7'], 'agent': '@pepper', 'evidence_required': ['Deployment log', 'Health check']},
    {'control_id': 'SEN-008', 'name': 'Evidence integrity', 'description': 'Bundle SHA-256, ledger chain', 'framework': 'sentinels', 'gates': ['G8'], 'agent': '@ariadne', 'evidence_required': ['Bundle manifest', 'Ledger entry']},
    {'control_id': 'SEN-009', 'name': 'Closure completeness', 'description': 'Todos los gates PASS', 'framework': 'sentinels', 'gates': ['G9'], 'agent': '@jarvis', 'evidence_required': ['All gates PASS', 'Governance comments']},
    {'control_id': 'SEN-010', 'name': 'Hash chain integrity', 'description': 'Ledger append-only sin breaks', 'framework': 'sentinels', 'gates': ['G8', 'G9'], 'agent': '@ariadne', 'evidence_required': ['Ledger verification report']},
]

print(json.dumps(controls, indent=2))
"
}

# ─── Control Lookups ─────────────────────────────────────────

# Get a specific control by ID
control_get() {
  local control_id="$1"
  control_registry | python3 -c "
import json, sys
controls = json.load(sys.stdin)
cid = sys.argv[1]
found = [c for c in controls if c['control_id'] == cid]
if not found:
    print(f'ERROR: control no encontrado: {cid}', file=sys.stderr)
    sys.exit(1)
print(json.dumps(found[0], indent=2))
" "$control_id"
}

# Filter controls by framework
controls_by_framework() {
  local framework="$1"
  control_registry | python3 -c "
import json, sys
controls = json.load(sys.stdin)
fw = sys.argv[1]
filtered = [c for c in controls if c['framework'] == fw]
print(json.dumps(filtered, indent=2))
" "$framework"
}

# Filter controls by gate
controls_by_gate() {
  local gate="$1"
  control_registry | python3 -c "
import json, sys
controls = json.load(sys.stdin)
gate = sys.argv[1]
filtered = [c for c in controls if gate in c['gates']]
print(json.dumps(filtered, indent=2))
" "$gate"
}

# ─── Scoring ─────────────────────────────────────────────────

# Calculate compliance score from audit trail entries
# Output: JSON with per-framework and total scores
compliance_score() {
  local journal_path="$1"
  local contract_id="$2"

  local trail_file
  trail_file="$(audit_trail_path "$journal_path" "$contract_id")"

  local registry
  registry="$(control_registry)"

  local entries=""
  if [ -f "$trail_file" ]; then
    entries="$(cat "$trail_file")"
  fi

  python3 -c "
import json
import sys

controls = json.loads(sys.argv[1])
entries_text = sys.argv[2]

# Parse audit trail entries
entries = []
for line in entries_text.strip().split('\n'):
    if line.strip():
        entries.append(json.loads(line))

# Track latest result per control_id
control_results = {}
for entry in entries:
    if entry.get('action') in ('control_verified', 'control_failed'):
        for ctrl in entry.get('controls', []):
            result = entry.get('result', 'N/A')
            control_results[ctrl] = result

# Calculate per-framework scores
frameworks = {}
for ctrl in controls:
    fw = ctrl['framework']
    if fw not in frameworks:
        frameworks[fw] = {'total': 0, 'pass': 0, 'fail': 0, 'pending': 0}
    frameworks[fw]['total'] += 1

    cid = ctrl['control_id']
    if cid in control_results:
        if control_results[cid] == 'PASS':
            frameworks[fw]['pass'] += 1
        else:
            frameworks[fw]['fail'] += 1
    else:
        frameworks[fw]['pending'] += 1

# Calculate totals
total = {'total': 0, 'pass': 0, 'fail': 0, 'pending': 0}
for fw_data in frameworks.values():
    total['total'] += fw_data['total']
    total['pass'] += fw_data['pass']
    total['fail'] += fw_data['fail']
    total['pending'] += fw_data['pending']

# Add coverage percentage
for fw_data in list(frameworks.values()) + [total]:
    if fw_data['total'] > 0:
        fw_data['coverage'] = round(fw_data['pass'] / fw_data['total'] * 100, 1)
    else:
        fw_data['coverage'] = 0.0

output = {
    'contract_id': sys.argv[3],
    'frameworks': frameworks,
    'total': total,
    'controls_verified': control_results
}

print(json.dumps(output, indent=2))
" "$registry" "$entries" "$contract_id"
}
