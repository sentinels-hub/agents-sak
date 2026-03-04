# OpenProject — Catálogo de Operaciones

Índice de todas las operaciones que un agente puede realizar en OpenProject.

## Documentos

### Operaciones base
| Documento | Qué cubre |
|-----------|-----------|
| [work-packages.md](work-packages.md) | CRUD de WPs, jerarquía, campos requeridos + orquestación + scheduling |
| [versions.md](versions.md) | Gestión de versiones/iteraciones, SemVer, ciclo de vida |
| [backlogs.md](backlogs.md) | Backlogs, sprints, prioridades, métricas |
| [roadmaps.md](roadmaps.md) | Roadmap, planificación temporal, governance, KPIs |
| [time-tracking.md](time-tracking.md) | Registro de tiempo, actividades, estimación vs. real |
| [status-workflow.md](status-workflow.md) | Flujo de estados, transiciones por rol y gate |
| [traceability.md](traceability.md) | Cadena Git↔OP↔Evidence, convenciones, verificación |

### Orquestación activa
| Documento | Qué cubre |
|-----------|-----------|
| [queries.md](queries.md) | Colas de trabajo por agente, filtros, saved queries como punto de entrada |
| [relations.md](relations.md) | Dependencias entre WPs: blocks, precedes, requires — grafo de ejecución |
| [projects.md](projects.md) | Proyecto como capa de orquestación: status, custom fields, jerarquía |

## Guía rápida por agente

| Agente | Operaciones base | Orquestación | Playbook |
|--------|-----------------|--------------|----------|
| @jarvis | work-packages, traceability, status-workflow | projects, queries | [jarvis.md](../playbooks/jarvis.md) |
| @inception | work-packages, backlogs, roadmaps, versions | queries, relations, projects | [inception.md](../playbooks/inception.md) |
| @gtd | work-packages, status-workflow, time-tracking | queries, relations | [gtd.md](../playbooks/gtd.md) |
| @morpheus | status-workflow, traceability | queries | [morpheus.md](../playbooks/morpheus.md) |
| @agent-smith | status-workflow, traceability | queries | [agent-smith.md](../playbooks/agent-smith.md) |
| @oracle | traceability, status-workflow, time-tracking | queries | [oracle.md](../playbooks/oracle.md) |
| @pepper | status-workflow, traceability | queries | [pepper.md](../playbooks/pepper.md) |
| @ariadne | traceability | queries | [ariadne.md](../playbooks/ariadne.md) |
