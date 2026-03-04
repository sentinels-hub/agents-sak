# OpenProject — Backlogs

Guía para gestión de backlogs en OpenProject bajo el modelo Sentinels.

## Concepto

El **Backlog** es la vista de trabajo pendiente, organizado por versiones. En Sentinels:

- **Story types**: User Story + Incident Story
- **Task type**: Task (breakdown de stories)
- **Progreso**: Basado en horas estimadas (work-based), NO en conteo de tareas

## Vistas de backlog

### Product Backlog (sin versión asignada)
WPs sin versión asignada. Representa trabajo identificado pero no planificado.

### Sprint/Version Backlog
WPs asignados a una versión específica. Representa el scope de una iteración.

```
v0.1.0 (open)                        v0.2.0 (open)
├── US#1889 Implement HUD [14h]      ├── US#2001 Add auth [8h]
│   ├── Task#1897 File structure      │   ├── Task#2010 OAuth setup
│   ├── Task#1899 CSS variables       │   ├── Task#2011 JWT tokens
│   └── Task#1901 Components          │   └── Task#2012 Session mgmt
└── US#1891 Landing page [6h]        └── US#2003 Dashboard [12h]
```

## Configuración backlog

| Parámetro | Valor Sentinels |
|-----------|----------------|
| Story types | User story, Incident Story |
| Task type | Task |
| Progress calculation | Work-based (horas estimadas) |
| Closed items | 100% completion |

## Flujo de trabajo con backlogs

### 1. Crear la estructura (G2 — @inception)

```bash
# Crear User Story raíz
openproject-sync.sh create-story <PROJECT> "Implement OAuth2" "## Contexto\n..." <STATUS_ID> <VERSION_ID>

# Crear Tasks hijas
openproject-sync.sh create-child <US_ID> "Task" "Setup OAuth provider" "" <STATUS_ID> <VERSION_ID>
openproject-sync.sh create-child <US_ID> "Task" "Implement JWT flow" "" <STATUS_ID> <VERSION_ID>
openproject-sync.sh create-child <US_ID> "Task" "Add session management" "" <STATUS_ID> <VERSION_ID>

# Estimar cada tarea
openproject-sync.sh estimate <TASK_1_ID> 2
openproject-sync.sh estimate <TASK_2_ID> 3
openproject-sync.sh estimate <TASK_3_ID> 3

# Propagar versión a hijos
openproject-sync.sh propagate-version <US_ID>
```

### 2. Ejecutar el sprint (G3 — @gtd)

```bash
# Transicionar tareas conforme se ejecutan
openproject-sync.sh transition-and-log <TASK_ID> "In progress" "gtd" "Starting implementation"

# Al completar
openproject-sync.sh transition-and-log <TASK_ID> "Developed" "gtd" "Done — commit abc123 [WP#TASK_ID]"

# Registrar tiempo
openproject-sync.sh log-time <TASK_ID> 2.5 "OAuth provider integration" "Development"
```

### 3. Cerrar el sprint

```bash
# Cuando todos los WPs están en Closed:
# La versión pasa a locked → closed
```

## Prioridades

| Prioridad | Uso |
|-----------|-----|
| Immediate | Incidentes de producción, seguridad crítica |
| Urgent | Bloqueos de sprint, dependencias críticas |
| High | Features principales del sprint |
| Normal | Trabajo estándar planificado |
| Low | Nice-to-have, mejoras menores |

## Métricas del backlog

- **Capacidad del sprint**: Suma de `estimatedTime` de todos los WPs en la versión
- **Velocidad**: Horas completadas por sprint
- **Scope creep**: WPs añadidos después del `locked` de la versión
- **Completion rate**: WPs cerrados / WPs planificados

## Reglas Sentinels

1. **No hay WP sin versión en ejecución** — si está "In progress", debe tener versión asignada
2. **estimatedTime obligatorio** — no se acepta trabajo sin estimación
3. **User Story es la unidad de planning** — Tasks son breakdown, no se planifican solas
4. **Incident Story** para trabajo no planificado (incidentes, urgencias)
5. **Un WP por commit** — trazabilidad 1:1 entre commits y WPs referenciados
