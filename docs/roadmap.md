# Agents SAK — Roadmap

## v0.1.0 — OpenProject Foundation (actual)

### Objetivos
- Catálogo completo de operaciones OpenProject para agentes
- Schemas de validación para Work Packages, versiones y comentarios
- Templates estandarizados (descripción WP, governance comment, planning tree)
- UI web base con dashboard, backlog, roadmap y trazabilidad
- Documentación de arquitectura

### Entregables
- [x] Estructura del repositorio
- [ ] `tools/openproject/catalog/` — 7 documentos de operaciones
- [ ] `tools/openproject/schemas/` — 3 schemas JSON
- [ ] `tools/openproject/templates/` — 3 templates
- [ ] `ui/` — Dashboard web con 4 vistas
- [ ] `docs/` — architecture, roadmap, changelog

---

## v0.2.0 — OpenProject CLI modular (próximo)

### Objetivos
- Refactorizar `openproject-sync.sh` (75KB monolítico) en módulos
- CLI con subcomandos claros: `sak op wp create`, `sak op version list`, etc.
- Validación pre-envío contra schemas locales
- Tests unitarios para cada módulo

### Entregables
- [ ] `tools/openproject/scripts/op-cli.sh` — CLI principal
- [ ] `tools/openproject/scripts/modules/` — Módulos por dominio
- [ ] `tools/openproject/scripts/op-validate.sh` — Validador local
- [ ] Tests

---

## v0.3.0 — Agent Workflows

### Objetivos
- Workflows pre-definidos por agente y gate
- Cada agente tiene un "playbook" de qué hacer en cada gate
- Integración con el protocolo G0-G9

### Entregables
- [ ] `tools/openproject/workflows/` — Playbooks por gate
- [ ] Integración con contract.json
- [ ] Reportes automáticos de estado por contrato

---

## v0.4.0 — Herramientas adicionales

### Objetivos
- Segunda herramienta: `tools/github/` — Gestión de PRs, branches, releases
- Tercera herramienta: `tools/evidence/` — Bundles, hashing, ledger
- UI ampliada con vistas para cada herramienta

---

## v0.5.0 — Integración completa

### Objetivos
- Pipeline end-to-end: OP → GitHub → Evidence → Ledger
- Dashboard unificado con estado de todos los contratos
- Métricas y KPIs (trazabilidad ≥95%, etc.)

---

## Futuro

- `tools/compliance/` — Checklists automáticos ISO/SOC2/ENS
- `tools/notifications/` — Alertas por estado, bloqueos, gates
- `tools/analytics/` — Métricas históricas, lead time, velocity
- API REST propia para consumo programático
