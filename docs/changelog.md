# Agents SAK — Changelog

Todos los cambios relevantes de este proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

---

## [1.0.0] — 2026-03-04

### Summary
First production release. Complete cross-tool toolkit for the Sentinels ecosystem.
All 4 domain tools (openproject, github, evidence, compliance) + cross-tool layer
(sak-core, sak-cli, sak-trace, sak-gates, sak-metrics) + UI + tests + docs.

### Added
- Triada integration: sentinels-agents, sentinels-lighthouse, sentinels-agents-journal
  updated with SAK references, integration docs, and cross-repo coordination

### Changed
- Version bumped to v1.0.0 across CLI, UI header, and all documentation
- README ecosystem table updated to v1.0.0

---

## [0.9.0-dev] — 2026-03-04

### Added
- `tests/smoke-test.sh` — Tests offline con journal mock (~50 assertions)
  - Tests para sak-core, gh-core, ev-core, co-core, sak-trace, sak-gates, sak-metrics, sak-cli
  - Syntax check de todos los scripts
  - Mock journal con bundles, ledger y audit trail
- `docs/api-reference.md` — Referencia completa de funciones y comandos de cada módulo

### Changed
- `docs/roadmap.md` — v0.6.0-v0.9.0 marcados como completados
- `docs/architecture.md` — Añadida capa sak-core al diagrama
- `README.md` — Actualizado a v0.9.0, link a API reference

---

## [0.8.0-dev] — 2026-03-04

### Added
- `tools/scripts/sak-metrics.sh` — Métricas cross-tool
  - `summary` — Control coverage, gate pass rate, chain completeness, bundle count, ledger health, audit density
  - `gaps` — Identifica gaps en gates, evidence y controls
  - `coverage` — Coverage por framework (tabla + porcentajes)
  - Output JSON + tabla

---

## [0.7.0-dev] — 2026-03-04

### Added
- `tools/scripts/sak-gates.sh` — Gate Validation
  - `check-ready` — Pre-flight check de prerequisites por gate
  - `check-complete` — Verificación post-gate
  - `status` — Tabla de todos los gates (PASS/NC/--)
  - `next` — Sugiere el próximo gate a completar
  - Prerequisites embebidos: G0 (contract) → G4 (+branch) → G8 (+bundle) → G9 (+all controls)

---

## [0.6.0-dev] — 2026-03-04

### Added
- `tools/scripts/sak-core.sh` — Funciones compartidas cross-tool
  - Timestamps: iso_timestamp, compact_timestamp, numeric_timestamp
  - Output helpers: ok, fail, warn, info, section
  - Require checks: require_command, require_jq, require_python3, require_git
  - Validators: contract_id_validate, journal_path_resolve, sak_root
- `tools/scripts/sak-cli.sh` — CLI unificado
  - Router: sak op|gh|ev|co|trace|gates|metrics
  - Comandos propios: version, status
- `tools/scripts/sak-trace.sh` — E2E Traceability Verification
  - 10 checks: contract format, audit trail, gates coverage, bundles, bundle integrity, ledger chain, ledger linkage, branch naming, commit format, compliance score
  - API-dependent checks → [SKIP] sin error
- `ui/js/components/contracts.js` — Vista unificada por contrato
  - Gate pipeline, trace chain, compliance/evidence/ledger scores
  - Gate detail table con agentes y descripciones

### Changed
- `tools/evidence/scripts/ev-core.sh` — Source sak-core.sh con fallback para timestamps
- `tools/compliance/scripts/co-core.sh` — Source sak-core.sh con fallback para timestamps
- `tools/evidence/scripts/ev-setup.sh` — Source sak-core.sh con fallback para output helpers
- `tools/compliance/scripts/co-setup.sh` — Source sak-core.sh con fallback para output helpers
- `ui/index.html` — Nav item "Contracts" en Orchestration, script tag contracts.js
- `ui/js/app.js` — Registrada vista contracts, añadido contrato CTR-agents-sak-20260304

---

## [0.5.0-dev] — 2026-03-04

### Added
- `tools/openproject/scripts/op-setup.sh` — Verificación de statuses y types
  - 21 statuses corporativos verificados (antes solo 11)
  - 7 tipos de WP verificados (Epic, Feature, User story, Task, Bug, Incident Story, Milestone)
  - 7 project-level custom fields verificados (Tech Stack, Project Type, Lead Agent, Automation Tier, Compliance Scope, Repository URL, Lighthouse Version)
  - Instrucciones de creación manual para campos faltantes
- `tools/openproject/scripts/op-cli.sh` — Comandos de proyecto
  - `project list` — Lista proyectos activos (table/json/ids)
  - `project get` — Detalle de proyecto con custom fields
  - `project set` — Actualizar status y statusExplanation
  - `project versions` — Versiones del proyecto
  - `project members` — Miembros y roles
- `tools/openproject/schemas/work-package.schema.json` — 6 campos de orquestación
  - difficulty, specialization, agent_assigned, tech_stack, automation_level, gate_current
  - Validación con enums alineados a op-setup.sh

### Changed
- `tools/openproject/catalog/work-packages.md` — Alineado con op-setup.sh
  - Tech Stack: List (multi) → Text (libre)
  - Automation Level: Full-auto/Semi-auto → Full/Supervised
  - Specialization: valores alineados (8 valores)
- `tools/openproject/scripts/op-setup.sh` — Renumerado a 7 secciones
  - Sección 3: Status & Types (nueva)
  - Sección 5: Project Custom Fields (nueva)
- `docs/roadmap.md` — Reescrito completamente (v0.1.0→v0.9.0+ con estado real)

### Fixed
- Inconsistencia catalog ↔ op-setup.sh: field names, types, values alineados
- Traceability field names alineados con Lighthouse policy.yaml ("Github", "Github Commit")

---

## [0.4.0-dev] — 2026-03-04

### Added
- `tools/github/` — Tool GitHub completa
  - catalog/: repos, branches, pull-requests, commits, issues, actions
  - schemas/: branch.schema.json, commit.schema.json, pr.schema.json
  - templates/: pr-description.md, commit-message.md
  - scripts/: gh-core.sh (funciones compartidas), gh-cli.sh (CLI modular)
  - Comandos: branch create/validate/list, commit validate, pr create/list/link-wp
  - Labels de governance (gate:G0-G9, agent:*), repo setup, traceability check
- `tools/evidence/` — Tool Evidence completa
  - catalog/: bundles, ledger, verification, redaction
  - schemas/: bundle.schema.json, ledger-entry.schema.json
  - templates/: bundle-manifest.md, release-notes.md
  - scripts/: ev-core.sh (SHA-256, IDs, redaction), ev-cli.sh (CLI modular)
  - Comandos: bundle create/verify/list, ledger append/verify/last/list, redact
  - Hash chain integrity, cross-platform SHA-256
- `tools/compliance/` — Tool Compliance completa
  - catalog/: frameworks, controls, mapping, audit-trail
  - schemas/: control.schema.json, audit-entry.schema.json
  - templates/: control-checklist.md, audit-report.md
  - scripts/: co-core.sh (registry embebido, scoring), co-cli.sh (CLI modular), co-setup.sh (setup)
  - playbooks/: jarvis.md (G9 Compliance Audit), oracle.md (G6 QA Compliance Check)
  - 4 frameworks: ISO 27001, ISO 9001, SOC 2, ENS Alta
  - 24 controles (10 Lighthouse + 4 SOC 2 + 10 Sentinels-specific SEN-001 a SEN-010)
  - Comandos: audit append/list/last/verify, control list/get/check, report checklist/audit, verify completeness/non-conformities
  - Matriz gate→control→evidencia, audit trail JSONL, scoring por framework

---

## [0.3.0-dev] — 2026-03-04

### Added
- `tools/openproject/scripts/op-core.sh` — Funciones compartidas
  - `api()` con retry + exponential backoff (429, 5xx, network)
  - `api_try()` non-fatal wrapper
  - `resolve_field()` — nombre de campo → customFieldN con cache
  - `resolve_field_value()` — resuelve valores de List fields a `_links` href (fix crítico)
  - `build_patch_payload()` — construye JSON PATCH con `_links` para List y valores planos para Text
  - `resolve_status_id/name()` — cache de statuses en memoria (1 API call por sesión)
  - `resolve_type_id()` — resolución de tipos por proyecto
  - Cache de campos con allowedValues en `.sentinels/field-mapping.json` (TTL 24h)
- `tools/openproject/scripts/op-setup.sh` — Script de setup y verificación
  - Verifica conectividad, auth, permisos
  - Verifica custom fields de orquestación y trazabilidad
  - Crea saved queries por agente (13 queries, idempotente)
  - `--dry-run`: muestra qué haría sin tocar OP
  - `--check-only`: solo verificación
  - Genera reporte con instrucciones para campos faltantes (Admin UI)
- `tools/openproject/scripts/op-cli.sh` — CLI modular para orquestación
  - `query list/exec/create/delete` — Gestión de saved queries
  - `wp list/list-all/get` — Listado con filtros, paginación, múltiples formatos
  - `wp set-orchestration` — Asignar campos con resolución List/Text automática
  - `wp set-orchestration-batch` — Batch via archivo TSV
  - `relation create/list/check-blocked` — Gestión de relaciones entre WPs
  - Status cacheados en sesión (no múltiples API calls por filtro)

### Changed
- tools/openproject/README.md: Añadida sección de scripts con tabla de referencia

---

## [0.2.0-dev] — 2026-03-04

### Added
- `tools/openproject/catalog/` — 3 nuevos documentos de orquestación activa
  - queries.md: Colas de trabajo por agente, saved queries como punto de entrada
  - relations.md: Dependencias entre WPs (blocks, precedes, requires)
  - projects.md: Proyecto como capa de orquestación (status, custom fields, jerarquía)
- `tools/openproject/schemas/` — 3 nuevos schemas
  - query.schema.json: Validación de saved queries
  - relation.schema.json: Validación de relaciones entre WPs
  - project.schema.json: Validación de datos de proyecto con campos de orquestación
- `tools/openproject/playbooks/` — 8 playbooks de agentes
  - jarvis.md, inception.md, gtd.md, morpheus.md
  - agent-smith.md, oracle.md, pepper.md, ariadne.md
- `ui/` — 2 nuevas vistas
  - Work Queues: Colas de trabajo por agente con métricas
  - Agents: Carga de trabajo, especialización, asignaciones

### Changed
- work-packages.md: Añadidos campos de scheduling (dates, duration, percentageDone) y campos de orquestación (Difficulty, Specialization, Agent Assigned, Tech Stack, Automation Level, Gate Current)
- work-packages.md: Añadidas operaciones avanzadas (queries, notify=false, available_assignees)
- catalog/README.md: Reorganizado con sección de orquestación + links a playbooks
- ui/index.html: Nueva sección "Orchestration" en sidebar
- ui/js/app.js: Registradas vistas queries y agents

---

## [0.1.0] — 2026-03-04

### Added
- Estructura inicial del repositorio `agents-sak`
- `tools/openproject/catalog/` — Catálogo de operaciones OpenProject
  - work-packages.md: CRUD, jerarquía, campos requeridos
  - versions.md: Gestión de versiones/iteraciones
  - backlogs.md: Backlogs y sprints
  - roadmaps.md: Roadmap y planificación
  - time-tracking.md: Registro de tiempo y actividades
  - status-workflow.md: Flujo de estados y transiciones
  - traceability.md: Trazabilidad Git↔OP↔Evidence
- `tools/openproject/schemas/` — Schemas de validación JSON
  - work-package.schema.json
  - version.schema.json
  - comment.schema.json
- `tools/openproject/templates/` — Templates para agentes
  - wp-description.md
  - governance-comment.md
  - planning-tree.md
- `ui/` — Dashboard web (HTML/CSS/JS, zero deps)
  - Vista Dashboard
  - Vista Backlog
  - Vista Roadmap
  - Vista Traceability
- `docs/` — Documentación
  - architecture.md
  - roadmap.md
  - changelog.md
