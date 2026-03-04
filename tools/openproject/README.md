# OpenProject Tool — Agents SAK

Herramienta completa para que los agentes Sentinels gestionen OpenProject como lo haría una persona.

## Qué incluye

### Catálogo de operaciones (`catalog/`)
Documentación detallada de cada área funcional de OpenProject:

| Documento | Descripción |
|-----------|-------------|
| [work-packages](catalog/work-packages.md) | CRUD, jerarquía, campos, validación |
| [versions](catalog/versions.md) | Versiones, SemVer, ciclo de vida |
| [backlogs](catalog/backlogs.md) | Backlogs, sprints, prioridades |
| [roadmaps](catalog/roadmaps.md) | Planificación temporal, KPIs |
| [time-tracking](catalog/time-tracking.md) | Registro de tiempo, actividades |
| [status-workflow](catalog/status-workflow.md) | Estados, transiciones, roles |
| [traceability](catalog/traceability.md) | Git↔OP↔Evidence chain |

### Schemas de validación (`schemas/`)
JSON Schemas para validar datos antes de enviarlos a la API:

| Schema | Valida |
|--------|--------|
| [work-package.schema.json](schemas/work-package.schema.json) | WPs con campos Sentinels |
| [version.schema.json](schemas/version.schema.json) | Versiones SemVer |
| [comment.schema.json](schemas/comment.schema.json) | Governance comments |

### Templates (`templates/`)
Formatos estándar para documentos y comunicaciones:

| Template | Uso |
|----------|-----|
| [wp-description](templates/wp-description.md) | Descripción de Work Packages |
| [governance-comment](templates/governance-comment.md) | Comentarios de governance |
| [planning-tree](templates/planning-tree.md) | Árbol de planificación |

## Cómo usa esto un agente

```
1. Lee el catálogo → Entiende QUÉ puede hacer
2. Usa los templates → Sabe CÓMO formatear
3. Valida con schemas → Verifica ANTES de enviar
4. Ejecuta scripts → HACE la operación en OP
```

## Requisitos

- `OPENPROJECT_URL` — URL de la instancia OpenProject
- `OPENPROJECT_API_TOKEN` — Token de API (Basic auth)
- `curl`, `jq` — Para scripts de ejecución
- Acceso al proyecto en OP con rol member o project manager

## Alineación con Lighthouse

Esta herramienta implementa los requisitos definidos en:
- `sentinels-lighthouse/policy/policy.yaml` — Campos requeridos, estados, jerarquía
- `sentinels-lighthouse/policy/sentinels-protocol/v1/protocol.yaml` — Gates G0-G9
- `sentinels-lighthouse/scripts/openproject-sync.sh` — Script de referencia (75KB)

**Source of truth**: Siempre es Lighthouse. Si hay conflicto, Lighthouse gana.
