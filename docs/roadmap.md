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

## v0.6.0 — Cross-Tool Integration (próximo)

### Objetivos
- Pipeline end-to-end: OP → GitHub → Evidence → Compliance → Ledger
- Trazabilidad completa verificable entre herramientas
- Comandos de integración cruzada

### Entregables
- [ ] `sak-orchestrator.sh` — Orquestador que coordina las 4 tools
- [ ] Traceability check end-to-end (WP → branch → PR → bundle → ledger → audit)
- [ ] Dashboard UI: vista unificada de estado por contrato
- [ ] Métricas de trazabilidad (≥95% target)

---

## v0.7.0 — Agent Runtime Hooks

### Objetivos
- Hooks para que sentinels-agents consuma SAK de forma nativa
- Entry points claros por gate para cada agente
- Configuración por proyecto exportable

### Entregables
- [ ] `hooks/` — Entry points por gate (gate-entry.sh, gate-exit.sh)
- [ ] Config exporter: genera configuración de agente desde OP
- [ ] Validación pre-gate (verifica prerequisites antes de ejecutar)
- [ ] Integración documentada con sentinels-agents

---

## v0.8.0 — Analytics & Reporting

### Objetivos
- Métricas históricas, KPIs, reports automáticos
- Dashboard con gráficos de progreso, velocity, lead time

### Entregables
- [ ] `tools/analytics/` — Métricas históricas
- [ ] UI: gráficos de velocity, lead time, gate pass rate
- [ ] Reports periódicos automáticos (sprint summary, compliance status)

---

## v0.9.0 — Production Ready

### Objetivos
- QA final, refactorización, documentación completa
- Todo listo para uso en producción por la triada (agents, lighthouse, journal)

### Entregables
- [ ] QA review de todos los scripts (edge cases, error handling)
- [ ] Documentación completa de API de cada tool
- [ ] E2E tests automatizados
- [ ] Release notes v1.0.0-rc

---

## Futuro (v1.0+)

- `tools/notifications/` — Alertas por estado, bloqueos, gates
- API REST propia para consumo programático
- Plugin system para tools de terceros
- Multi-instance OP support
