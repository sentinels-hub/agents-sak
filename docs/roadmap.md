# Agents SAK — Roadmap

## Versiones completadas

### v0.1.0 — OpenProject Foundation
- [x] Estructura del repositorio
- [x] `tools/openproject/catalog/` — 7 documentos de operaciones (work-packages, versions, backlogs, roadmaps, time-tracking, status-workflow, traceability)
- [x] `tools/openproject/schemas/` — 3 schemas (work-package, version, comment)
- [x] `tools/openproject/templates/` — 3 templates (wp-description, governance-comment, planning-tree)
- [x] `ui/` — Dashboard web con 4 vistas (Dashboard, Backlog, Roadmap, Traceability)
- [x] `docs/` — architecture, roadmap, changelog

### v0.2.0 — Orchestration Layer
- [x] `tools/openproject/catalog/` — 3 nuevos docs (queries, relations, projects)
- [x] `tools/openproject/schemas/` — 3 nuevos schemas (query, relation, project)
- [x] `tools/openproject/playbooks/` — 8 playbooks por agente
- [x] `ui/` — 2 nuevas vistas (Work Queues, Agents)
- [x] Campos de orquestación en catalog (Difficulty, Specialization, Agent Assigned, Tech Stack, Automation Level, Gate Current)

### v0.3.0 — OpenProject CLI Modular
- [x] `tools/openproject/scripts/op-core.sh` — API retry, field resolution, caching
- [x] `tools/openproject/scripts/op-cli.sh` — CLI: query, wp, relation commands
- [x] `tools/openproject/scripts/op-setup.sh` — Setup verification + saved queries

### v0.4.0 — Tools Expansion
- [x] `tools/github/` — Tool GitHub completa (catalog, schemas, templates, scripts gh-core/gh-cli)
- [x] `tools/evidence/` — Tool Evidence completa (bundles SHA-256, ledger, verification, redaction)
- [x] `tools/compliance/` — Tool Compliance completa (4 frameworks, 24 controles, audit trail, scoring)
- [x] Compliance scripts: co-core.sh (registry embebido), co-cli.sh (CLI), co-setup.sh (setup)
- [x] Compliance playbooks: jarvis (G9), oracle (G6)

---

## v0.5.0 — Consolidation & Consistency (actual)

### Objetivos
- Alinear catálogos, schemas y scripts al 100%
- Verificación completa del entorno OP (statuses, types, project fields)
- Comandos de proyecto en CLI

### Entregables
- [x] Fix inconsistencias catalog ↔ op-setup.sh (field names, types, values)
- [x] Campos de orquestación en work-package.schema.json
- [x] Verificación de 21 statuses y 7 types en op-setup.sh
- [x] Verificación de 7 project-level custom fields en op-setup.sh
- [x] Comandos `project list/get/set/versions/members` en op-cli.sh
- [x] Roadmap actualizado
- [x] Changelog v0.5.0

---

### v0.6.0 — Cross-Tool Integration
- [x] `tools/scripts/sak-core.sh` — Funciones compartidas cross-tool (timestamps, validators, output helpers)
- [x] `tools/scripts/sak-cli.sh` — CLI unificado: `sak op|gh|ev|co|trace|gates|metrics|version|status`
- [x] `tools/scripts/sak-trace.sh` — Verificación E2E traceability (10 checks)
- [x] `ui/js/components/contracts.js` — Vista unificada por contrato (gate pipeline, trace chain, compliance)
- [x] Modificaciones ev-core/co-core/ev-setup/co-setup para source sak-core.sh con fallback

### v0.7.0 — Gate Validation
- [x] `tools/scripts/sak-gates.sh` — Validación de gates (check-ready, check-complete, status, next)
- [x] Prerequisites por gate (G0-G9) con verificación de dependencias
- [x] Detección automática del próximo gate a completar

### v0.8.0 — Analytics
- [x] `tools/scripts/sak-metrics.sh` — Métricas cross-tool (summary, gaps, coverage)
- [x] Control coverage, gate pass rate, chain completeness, ledger health
- [x] Output JSON + tabla

### v0.9.0 — QA & Docs
- [x] `tests/smoke-test.sh` — Tests offline con journal mock (~50 assertions)
- [x] `docs/api-reference.md` — Referencia completa de funciones y comandos
- [x] Documentación actualizada (roadmap, changelog, architecture, README)

### v1.0.0 — Production Release
- [x] Version bump a v1.0.0 en CLI, UI y docs
- [x] Integración triada: sentinels-agents, sentinels-lighthouse, sentinels-agents-journal
- [x] Documentación de integración SAK en cada repo de la triada
- [x] Cross-repo coordination: cada repo sabe cómo consumir agents-sak

---

## Futuro (v1.1+)

- `tools/notifications/` — Alertas por estado, bloqueos, gates
- API REST propia para consumo programático
- Plugin system para tools de terceros
- Multi-instance OP support
