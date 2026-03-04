# OpenProject — Queries (Colas de Trabajo)

Las Queries son el mecanismo que convierte OpenProject de registro pasivo a **sistema de orquestación activa**. Un agente ejecuta una query para saber qué tiene que hacer.

## Concepto

Una **Query** es un filtro persistente y nombrado que devuelve una colección de Work Packages. Funciona como una **cola de trabajo**: el agente la ejecuta, obtiene sus tareas pendientes, y las procesa en orden.

```
@gtd ejecuta "Mis tareas pendientes"
  → OP devuelve: [Task#1897, Task#1899, Task#1901]
  → @gtd procesa Task#1897 (la primera por prioridad)
  → Transiciona a "Developed"
  → Ejecuta la query de nuevo → quedan [Task#1899, Task#1901]
```

## Queries por agente

### @jarvis — Orquestador (G0, G1, G8, G9)

| Query | Filtros | Ordenación |
|-------|---------|-----------|
| Contratos pendientes de inicialización | `type=User story`, `status=New`, `contract_id=!*` (null) | `createdAt ASC` |
| Pendiente de cierre | `status=Deployed`, gate G8 passed | `priority DESC` |
| Identidades sin verificar | `status=New`, contract exists, G1 pending | `createdAt ASC` |

### @inception — Planificación (G2)

| Query | Filtros | Ordenación |
|-------|---------|-----------|
| Backlog sin planificar | `type=User story`, `status=New`, `version=!*` (sin versión) | `priority DESC` |
| WPs sin estimación | `estimatedTime=!*` (null), `status!=Closed` | `type ASC` |
| WPs sin descripción completa | `description~!## Contexto` (falta sección) | `createdAt ASC` |

### @gtd — Implementación (G3)

| Query | Filtros | Ordenación |
|-------|---------|-----------|
| Mis tareas pendientes | `type=Task`, `status=In specification\|Scheduled`, `agentAssigned=@gtd` | `priority DESC, estimatedTime ASC` |
| En progreso | `type=Task`, `status=In progress`, `agentAssigned=@gtd` | `updatedAt ASC` |
| Bloqueados | `status=On hold`, `agentAssigned=@gtd` | `priority DESC` |

### @morpheus — Seguridad (G4)

| Query | Filtros | Ordenación |
|-------|---------|-----------|
| Pendiente de análisis | `status=Developed`, `type=User story\|Feature` | `priority DESC` |
| Riesgo alto sin mitigación | `risk_summary=*`, `mitigation=!*` | `priority DESC` |

### @agent-smith — Code Review (G5)

| Query | Filtros | Ordenación |
|-------|---------|-----------|
| Pendiente de review | `status=In security analysis` (post-G4) | `priority DESC` |
| Reviews con findings abiertos | `status=In review`, comments con "REQUEST_CHANGES" | `updatedAt ASC` |

### @oracle — QA + Compliance (G6)

| Query | Filtros | Ordenación |
|-------|---------|-----------|
| Pendiente de verificación | `status=In review` (post-G5 APPROVE) | `priority DESC` |
| Test failures | `status=Test failed` | `updatedAt DESC` |

### @pepper — Deployment (G7)

| Query | Filtros | Ordenación |
|-------|---------|-----------|
| Pendiente de deploy | `status=Verification` (post-G6 PASS) | `priority DESC` |
| Rollback necesario | `status=Test failed`, deployed=true | `priority DESC` |

### @ariadne — Evidence (G8)

| Query | Filtros | Ordenación |
|-------|---------|-----------|
| Pendiente de evidence | `status=Deployed`, `evidence_url=!*` (sin evidence) | `updatedAt ASC` |

## API de Queries

### CRUD completo

```bash
# Listar queries existentes
GET /api/v3/queries

# Crear query persistente
POST /api/v3/queries
{
  "name": "@gtd — Mis tareas pendientes",
  "public": true,
  "filters": [
    { "status": { "operator": "=", "values": ["7"] } },
    { "type": { "operator": "=", "values": ["3"] } },
    { "customField42": { "operator": "=", "values": ["@gtd"] } }
  ],
  "sortBy": [["priority", "desc"], ["estimatedTime", "asc"]],
  "columns": ["id", "subject", "status", "priority", "estimatedTime", "assignee"]
}

# Ejecutar query (devuelve WPs)
GET /api/v3/queries/{id}
# → response._embedded.results = WorkPackageCollection

# Actualizar query
PATCH /api/v3/queries/{id}

# Eliminar query
DELETE /api/v3/queries/{id}

# Marcar como favorita
POST /api/v3/queries/{id}/star
```

### Filtros disponibles

| Filtro | Operadores | Ejemplo |
|--------|-----------|---------|
| `status` | `=`, `!`, `o` (open), `c` (closed) | Tareas abiertas: `"o"` |
| `type` | `=`, `!` | Solo Tasks: `"=", ["3"]` |
| `assignee` | `=`, `!`, `*`, `!*` | Asignadas a user 5: `"=", ["5"]` |
| `responsible` | `=`, `!`, `*`, `!*` | Responsable específico |
| `version` | `=`, `!`, `*`, `!*` | En versión v0.1.0 |
| `priority` | `=`, `!` | Solo High+: `"=", ["8", "9"]` |
| `project` | `=`, `!` | Proyecto específico |
| `startDate` | `=d`, `<>d`, `t-`, `t+`, `*`, `!*` | Empieza esta semana: `"t+", ["7"]` |
| `dueDate` | `=d`, `<>d`, `t-`, `t+`, `*`, `!*` | Vence en 3 días: `"t+", ["3"]` |
| `estimatedTime` | `=`, `>=`, `<=`, `*`, `!*` | Sin estimar: `"!*"` |
| `percentageDone` | `=`, `>=`, `<=` | Menos del 50%: `"<=", ["50"]` |
| `createdAt` | `<>d`, `t-`, `t+` | Creados esta semana |
| `updatedAt` | `<>d`, `t-`, `t+` | Sin actividad en 7 días: `"t-", ["7"]` |
| `subject` | `~`, `!~` | Contiene "auth": `"~", ["auth"]` |
| `customField{N}` | `=`, `!`, `*`, `!*`, `~` | Dificultad Hard: `"=", ["Hard"]` |
| `parent` | `=`, `!` | Hijos de WP#1837 |
| `relatesTo` | `=` | Relacionado con WP |
| `blocks` | `=` | Bloqueando WP |
| `blocked` | `=` | Bloqueado por WP |
| `precedes` | `=` | Precede a WP |
| `follows` | `=` | Sigue a WP |

> Múltiples filtros se combinan con AND. No hay OR (limitación de OP).

### Ordenación

```json
"sortBy": [
  ["priority", "desc"],
  ["estimatedTime", "asc"],
  ["updatedAt", "desc"]
]
```

Campos ordenables: `id`, `subject`, `type`, `status`, `priority`, `assignee`, `responsible`, `version`, `startDate`, `dueDate`, `estimatedTime`, `percentageDone`, `createdAt`, `updatedAt`, `category`, `project`

### Agrupación

```json
"groupBy": "status"
```

Campos agrupables: `status`, `type`, `priority`, `assignee`, `responsible`, `version`, `project`, `category`

## Flujo de orquestación con queries

```
1. Admin/Inception crea queries públicas para cada agente
   ↓
2. Agente arranca su turno ejecutando su query principal
   ↓
3. Obtiene lista de WPs ordenados por prioridad
   ↓
4. Toma el primer WP, lee sus campos (difficulty, specialization, relations)
   ↓
5. Verifica que no está bloqueado (relation "blocked" vacía)
   ↓
6. Ejecuta el trabajo según su gate
   ↓
7. Transiciona el WP al siguiente estado
   ↓
8. Re-ejecuta la query → siguiente WP en cola
   ↓
9. Cuando la query devuelve vacío → turno completado
```

## Reglas

1. **Cada agente tiene al menos una query principal** — es su punto de entrada
2. **Queries públicas** (`public: true`) para visibilidad del equipo
3. **Queries starred** para acceso rápido en la UI
4. **No duplicar queries** — una query por responsabilidad
5. **Filtros por custom field "Agent Assigned"** para routing correcto
6. **Siempre verificar relaciones "blocked"** antes de tomar un WP
