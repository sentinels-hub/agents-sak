# OpenProject — Roadmaps

Guía para gestión de roadmaps y planificación a medio/largo plazo.

## Concepto

El **Roadmap** muestra la planificación temporal de versiones y su progreso. En OpenProject, el roadmap se construye a partir de:

- **Versiones** (con fechas start/end)
- **WPs asignados** a cada versión
- **Progreso** calculado por horas (work-based)

## Vista del roadmap

```
Timeline 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Mar         Abr         May         Jun
  ├─ v0.1.0 ──┤
  │ 14h est.  │
  │ ████░░ 60%│
  │            ├── v0.2.0 ──┤
  │            │  20h est.   │
  │            │  ░░░░░░ 0%  │
  │                          ├── v1.0.0 ────────┤
  │                          │  40h est.         │
  │                          │  ░░░░░░░░░░ 0%   │
```

## Niveles de planificación

| Nivel | Horizonte | Tipo OP | Ejemplo |
|-------|-----------|---------|---------|
| Estratégico | Trimestral+ | Epic | "Plataforma de autenticación" |
| Táctico | Sprint/Versión | Feature + User Story | "OAuth2 + SSO" |
| Operativo | Diario | Task | "Configurar provider OAuth" |

## Roadmap statuses (items visibles)

Según `sentinels_default` flow profile:
- Scheduled
- In progress
- Developed
- In review
- Verification
- Done
- Closed

> Items en backlog statuses (New, In specification...) NO aparecen en roadmap.

## Operaciones

### Crear planificación de versión

```bash
# Crear versiones del roadmap
openproject-sync.sh create-version <PROJECT> "v0.1.0" "2026-03-01" "2026-03-14"
openproject-sync.sh create-version <PROJECT> "v0.2.0" "2026-03-15" "2026-03-28"
openproject-sync.sh create-version <PROJECT> "v1.0.0" "2026-04-01" "2026-05-31"

# Asignar WPs a versiones
openproject-sync.sh version <EPIC_ID> <VERSION_ID>
openproject-sync.sh propagate-version <EPIC_ID>
```

### Consultar estado del proyecto

```bash
# Ver info del proyecto
openproject-sync.sh project-get <PROJECT>

# Ver opciones de estado del proyecto
openproject-sync.sh project-status-options <PROJECT>

# Actualizar estado general del proyecto
openproject-sync.sh project-set-status <PROJECT> <STATUS_CODE>

# Añadir explicación del estado
openproject-sync.sh project-set-status-explanation <PROJECT> "Sprint 1 complete. On track for v0.2.0."
```

### Estructura de proyectos

```bash
# Ver candidatos a proyecto padre
openproject-sync.sh project-parent-candidates <PROJECT>

# Crear subproyecto
openproject-sync.sh project-create-subproject <PARENT_PROJECT> <IDENTIFIER> "Nombre" ["Descripción"]

# Asignar/cambiar proyecto padre
openproject-sync.sh project-set-parent <PROJECT> <PARENT_PROJECT>
```

## Governance del roadmap

### Template de evaluación de roadmap

Al evaluar la salud del roadmap, verificar:

1. **Cobertura**: ¿Todos los Epics tienen versión asignada?
2. **Estimación**: ¿Todos los WPs ejecutables tienen `estimatedTime`?
3. **Dependencias**: ¿Hay bloqueos entre versiones?
4. **Capacidad**: ¿La suma de horas por versión es realista?
5. **Trazabilidad**: ¿Cada WP en ejecución tiene branch y commits?
6. **Riesgos**: ¿Cada WP tiene `risk_summary` y `mitigation`?

### KPIs del roadmap

| KPI | Target | Descripción |
|-----|--------|-------------|
| Trazabilidad completa | ≥95% | WPs con todos los campos de traceability |
| PRs con evidencia | ≥95% | PRs con test + documentation evidence |
| Lead time por tipo | Monitored | Tiempo desde New hasta Closed |
| Ratio de reapertura | Monitored | WPs reabiertos / total cerrados |
| Releases con checklist | 100% | Releases con closure checklist completa |
