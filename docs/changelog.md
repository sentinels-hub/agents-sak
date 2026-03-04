# Agents SAK — Changelog

Todos los cambios relevantes de este proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

---

## [0.3.0-dev] — 2026-03-04

### Added
- `tools/openproject/scripts/op-setup.sh` — Script de setup y verificación
  - Verifica conectividad, auth, permisos
  - Verifica custom fields de orquestación (Difficulty, Specialization, Agent Assigned, Tech Stack, Automation Level, Gate Current)
  - Verifica custom fields de trazabilidad (Contract ID, GitHub PR, etc.)
  - Crea saved queries por agente (13 queries, idempotente)
  - Genera reporte con instrucciones para campos faltantes (Admin UI)
- `tools/openproject/scripts/op-cli.sh` — CLI modular para orquestación
  - `query list/exec/create/delete` — Gestión de saved queries
  - `wp list/list-all/get` — Listado con filtros, paginación, múltiples formatos
  - `wp set-orchestration` — Asignar campos de orquestación a un WP
  - `wp set-orchestration-batch` — Batch via archivo TSV
  - `relation create/list/check-blocked` — Gestión de relaciones entre WPs
  - Cache de custom fields con TTL 24h
  - Resolución automática de status/type por nombre

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
