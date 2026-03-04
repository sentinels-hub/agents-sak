# Agents SAK — Changelog

Todos los cambios relevantes de este proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

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
