# Agents SAK — Changelog

Todos los cambios relevantes de este proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

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
