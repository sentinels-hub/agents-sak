# Agents SAK — API Reference

Referencia completa de funciones y comandos de cada módulo.

---

## sak-core.sh — Funciones compartidas

Capa cross-tool que elimina duplicados entre tools.

### Timestamps

| Función | Descripción | Ejemplo output |
|---------|-------------|----------------|
| `iso_timestamp` | ISO 8601 UTC | `2026-03-04T14:30:00Z` |
| `compact_timestamp` | Compacto para IDs | `20260304T143000Z` |
| `numeric_timestamp` | Numérico para entry IDs | `20260304143000` |

### Output helpers

| Función | Descripción |
|---------|-------------|
| `ok "msg"` | `[OK] msg` en verde |
| `fail "msg"` | `[FAIL] msg` en rojo |
| `warn "msg"` | `[WARN] msg` en amarillo |
| `info "msg"` | `[INFO] msg` en cyan |
| `section "title"` | Separador con título en bold |

### Require checks

| Función | Descripción |
|---------|-------------|
| `require_command CMD` | Verifica que CMD está instalado |
| `require_jq` | Verifica jq |
| `require_python3` | Verifica python3 |
| `require_git` | Verifica git |

### Validators

| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `contract_id_validate CTR` | Contract ID | Regex `CTR-<project>-<YYYYMMDD>` |
| `journal_path_resolve [PATH]` | Optional path | Resuelve: param > `$JOURNAL_PATH` > error |
| `sak_root [DIR]` | Optional start dir | Detecta raíz de agents-sak |

---

## sak-cli.sh — CLI Unificado

Punto de entrada único para todas las herramientas.

### Comandos

```
sak-cli.sh op <args...>           → OpenProject CLI
sak-cli.sh gh <args...>           → GitHub CLI
sak-cli.sh ev <args...>           → Evidence CLI
sak-cli.sh co <args...>           → Compliance CLI
sak-cli.sh trace <args...>        → E2E Traceability
sak-cli.sh gates <args...>        → Gate Validation
sak-cli.sh metrics <args...>      → Analytics
sak-cli.sh version                → Versión y estado de tools
sak-cli.sh status <CTR> [--journal-path PATH]  → Resumen rápido
```

---

## sak-trace.sh — E2E Traceability

Verificación de la cadena completa Contract → Audit.

### Uso

```bash
sak-trace.sh <CONTRACT_ID> --journal-path <PATH>
```

### Checks

| # | Check | Fuente | Requiere API |
|---|-------|--------|-------------|
| 1 | Contract ID format | sak-core | No |
| 2 | Audit trail exists | co-core | No |
| 3 | Gates coverage (G0-G9) | co-core | No |
| 4 | Evidence bundles exist | ev-core | No |
| 5 | Bundle integrity (SHA-256) | ev-core | No |
| 6 | Ledger chain integrity | ev-core | No |
| 7 | Ledger ↔ Contract linkage | ev-core | No |
| 8 | Branch naming convention | gh-core | No (git) |
| 9 | Commit message format | gh-core | No (git) |
| 10 | Compliance score | co-core | No |

API-dependent checks muestran `[SKIP]` cuando no están disponibles.

---

## sak-gates.sh — Gate Validation

### Comandos

```bash
sak-gates.sh check-ready <CTR> <GATE> --journal-path <PATH>
sak-gates.sh check-complete <CTR> <GATE> --journal-path <PATH>
sak-gates.sh status <CTR> --journal-path <PATH>
sak-gates.sh next <CTR> --journal-path <PATH>
```

### Prerequisites por Gate

| Gate | Prerequisites |
|------|--------------|
| G0 | Contract format válido |
| G1 | G0 PASS |
| G2 | G1 PASS |
| G3 | G2 PASS |
| G4 | G3 PASS + branch exists |
| G5 | G4 PASS |
| G6 | G5 PASS |
| G7 | G6 PASS |
| G8 | G7 PASS + bundle exists |
| G9 | G8 PASS + all controls PASS |

---

## sak-metrics.sh — Analytics

### Comandos

```bash
sak-metrics.sh summary <CTR> --journal-path <PATH>
sak-metrics.sh gaps <CTR> --journal-path <PATH>
sak-metrics.sh coverage <CTR> --journal-path <PATH>
```

### Métricas

| Métrica | Fuente | Descripción |
|---------|--------|-------------|
| Control coverage | co-core | % de controles con PASS |
| Gate pass rate | co-core | Gates con PASS / 10 |
| Chain completeness | multi | Checks de cadena que pasan |
| Evidence bundles | ev-core | Bundles para el contrato |
| Ledger health | ev-core | Estado de la cadena (UNBROKEN/BROKEN) |
| Audit density | co-core | Entries por gate |

---

## op-core.sh — OpenProject Core

### Funciones principales

| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `require_env` | — | Verifica `OPENPROJECT_URL` y `OPENPROJECT_API_TOKEN` |
| `api METHOD PATH [DATA]` | HTTP method, path, body | API call con retry + backoff |
| `api_try METHOD PATH [DATA]` | Igual que api | Non-fatal wrapper |
| `resolve_field PROJ TYPE FIELD` | Project, type ID, field name | Mapea nombre → customFieldN |
| `resolve_field_value PROJ TYPE NAME VAL` | Project, type, name, value | Resuelve List values a `_links` |
| `build_patch_payload LOCK [fragments...]` | Lock version, field fragments | Construye JSON PATCH |
| `resolve_status_id NAME` | Status name | Nombre → ID (cached) |
| `resolve_status_name ID` | Status ID | ID → nombre (cached) |
| `resolve_type_id PROJ NAME` | Project, type name | Tipo → ID |

### op-cli.sh — Comandos

```
op-cli.sh query list [PROJECT]
op-cli.sh query exec <QUERY_ID> [format]
op-cli.sh wp list <PROJECT> [--status ...] [--type ...] [--format ...]
op-cli.sh wp get <WP_ID> [format]
op-cli.sh wp set-orchestration <WP_ID> [--difficulty ...] [--agent ...] ...
op-cli.sh wp set-orchestration-batch <TSV_FILE>
op-cli.sh wp list-all <PROJECT> [--status ...] [--type ...]
op-cli.sh relation create <FROM> <TYPE> <TO> [DESC] [LAG]
op-cli.sh relation list <WP_ID> [FILTER]
op-cli.sh relation check-blocked <WP_ID>
op-cli.sh project list [format]
op-cli.sh project get <PROJECT> [format]
op-cli.sh project set <PROJECT> [--status ...] [--status-explanation ...]
op-cli.sh project versions <PROJECT>
op-cli.sh project members <PROJECT>
```

---

## gh-core.sh — GitHub Core

### Funciones

| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `require_gh` | — | Verifica gh CLI instalado y autenticado |
| `require_git_repo` | — | Verifica que estamos en un git repo |
| `current_repo` | — | Owner/name del repo actual |
| `current_repo_name` | — | Nombre del repo (sin org) |
| `validate_branch_name NAME` | Branch name | Valida patrón `<type>/wp-<ID>-<desc>` |
| `wp_id_from_branch BRANCH` | Branch name | Extrae WP number |
| `build_branch_name TYPE WP DESC` | type, WP ID, description | Construye nombre de branch |
| `validate_commit_message MSG` | Commit message | Valida `type(scope): desc [WP#ID]` |
| `wp_ids_from_commits` | — | Extrae WP IDs de commits en branch |
| `build_pr_title BRANCH DESC` | Branch, description | Construye título de PR |
| `create_governance_labels REPO` | Repo name | Crea labels gate:G0-G9 + agent:* |

### gh-cli.sh — Comandos

```
gh-cli.sh branch create <TYPE> <WP_ID> <DESCRIPTION>
gh-cli.sh branch validate [BRANCH_NAME]
gh-cli.sh branch list
gh-cli.sh commit validate [BASE_BRANCH]
gh-cli.sh pr create <WP_ID> <CONTRACT_ID> [GATE] [SUMMARY]
gh-cli.sh pr list [REPO] [STATE]
gh-cli.sh pr link-wp <PR_NUMBER> <WP_ID>
gh-cli.sh labels setup [REPO]
gh-cli.sh labels list [REPO]
gh-cli.sh repo setup [REPO]
gh-cli.sh traceability check
```

---

## ev-core.sh — Evidence Core

### Funciones

| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `sha256 FILE` | File path | SHA-256 de archivo (cross-platform) |
| `sha256_string STRING` | String | SHA-256 de string |
| `generate_bundle_id CTR` | Contract ID | `bundle-<ts>-<contract_lower>` |
| `generate_ledger_entry_id CTR` | Contract ID | `ledger-<ts>-<contract>` |
| `compute_bundle_sha256 MANIFEST` | Manifest path | Hash canónico del bundle |
| `ledger_current_path JOURNAL` | Journal path | Path del partition actual |
| `ledger_all_entries JOURNAL` | Journal path | Concatena todas las particiones |
| `ledger_last_hash JOURNAL` | Journal path | Último bundle_sha256 |
| `ledger_count JOURNAL` | Journal path | Total entries |
| `journal_bundle_dir JOURNAL BUNDLE` | Journal, bundle ID | Path del directorio del bundle |
| `validate_manifest MANIFEST` | Manifest path | Valida campos requeridos |
| `validate_ledger_entry JSON` | Entry JSON | Valida campos requeridos |
| `redact_content FILE [patterns...]` | File, pattern names | Aplica redacción |

### ev-cli.sh — Comandos

```
ev-cli.sh bundle create <CTR> <DIR> [--journal-path PATH] [--sources-op ...] [--redaction-patterns ...]
ev-cli.sh bundle verify <MANIFEST_PATH>
ev-cli.sh bundle list <JOURNAL> [CTR]
ev-cli.sh ledger append --contract CTR --manifest PATH --journal-path PATH [--repo ...] [--no-git-commit]
ev-cli.sh ledger verify --journal-path PATH
ev-cli.sh ledger last --journal-path PATH
ev-cli.sh ledger list --journal-path PATH [--contract CTR]
ev-cli.sh redact <DIR> [--patterns email,token,secret] [--dry-run]
ev-cli.sh redact-file <FILE> [--patterns ...] [--dry-run]
ev-cli.sh verify cross-check [--journal-path PATH] [--manifest PATH]
```

---

## co-core.sh — Compliance Core

### Funciones

| Función | Parámetros | Descripción |
|---------|-----------|-------------|
| `generate_audit_entry_id CTR` | Contract ID | `audit-<ts>-<contract>` |
| `audit_trail_path JOURNAL CTR` | Journal, contract | Path del audit trail |
| `audit_trail_entries JOURNAL CTR` | Journal, contract | Lee todas las entries |
| `audit_trail_count JOURNAL CTR` | Journal, contract | Cuenta entries |
| `audit_trail_last JOURNAL CTR` | Journal, contract | Última entry |
| `validate_audit_entry JSON` | Entry JSON | Valida campos, actions, results, gates |
| `control_registry` | — | JSON de 24 controles embebidos |
| `control_get ID` | Control ID | Detalle de un control |
| `controls_by_framework FW` | Framework name | Controles filtrados |
| `controls_by_gate GATE` | Gate (G0-G9) | Controles del gate |
| `compliance_score JOURNAL CTR` | Journal, contract | Score JSON por framework |

### co-cli.sh — Comandos

```
co-cli.sh audit append --contract CTR --gate G5 --agent @smith --action control_verified --controls c1,c2 --evidence-ref "PR #42" --result PASS --journal-path PATH
co-cli.sh audit list --contract CTR --journal-path PATH [--gate G5] [--action ...]
co-cli.sh audit last --contract CTR --journal-path PATH
co-cli.sh audit verify --contract CTR --journal-path PATH
co-cli.sh control list [--framework sentinels|ens_alto|iso_27001|iso_9001|soc2]
co-cli.sh control get <CONTROL_ID>
co-cli.sh control check --contract CTR --journal-path PATH
co-cli.sh report checklist --contract CTR --journal-path PATH [--agent @jarvis] [--output FILE]
co-cli.sh report audit --contract CTR --journal-path PATH [--agent @jarvis] [--output FILE]
co-cli.sh verify completeness --contract CTR --journal-path PATH
co-cli.sh verify non-conformities --contract CTR --journal-path PATH
```

---

## Schemas

| Schema | Path | Descripción |
|--------|------|-------------|
| Work Package | `tools/openproject/schemas/work-package.schema.json` | WP con campos de orquestación |
| Version | `tools/openproject/schemas/version.schema.json` | Versiones/iteraciones |
| Comment | `tools/openproject/schemas/comment.schema.json` | Governance comments |
| Query | `tools/openproject/schemas/query.schema.json` | Saved queries |
| Relation | `tools/openproject/schemas/relation.schema.json` | Relaciones WP |
| Project | `tools/openproject/schemas/project.schema.json` | Datos de proyecto |
| Branch | `tools/github/schemas/branch.schema.json` | Branch naming |
| Commit | `tools/github/schemas/commit.schema.json` | Commit format |
| PR | `tools/github/schemas/pr.schema.json` | Pull request |
| Bundle | `tools/evidence/schemas/bundle.schema.json` | Evidence bundle |
| Ledger Entry | `tools/evidence/schemas/ledger-entry.schema.json` | Ledger entry |
| Control | `tools/compliance/schemas/control.schema.json` | Compliance control |
| Audit Entry | `tools/compliance/schemas/audit-entry.schema.json` | Audit trail entry |
