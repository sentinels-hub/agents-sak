# OpenProject — Work Packages

Guía completa para que los agentes gestionen Work Packages (WPs) en OpenProject.

## Jerarquía de tipos

```
Epic                    (objetivo macro — semanas/meses)
  └── Feature           (capacidad funcional)
      └── User Story    (unidad contractual — DEBE tener Contract ID)
          ├── Task      (subtarea ejecutable)
          └── Bug       (defecto encontrado)
      └── Incident Story (incidente operacional con naturaleza contractual)
  └── Milestone         (checkpoint de calendario — opcional)
```

> **Regla clave**: La User Story es la raíz contractual. Todo Task/Bug hijo hereda su versión.

## Campos requeridos (Hard-Required)

| Campo | Tipo | Descripción | Ejemplo |
|-------|------|-------------|---------|
| `subject` | string | Título descriptivo del WP | "Implementar autenticación OAuth2" |
| `description` | markdown | Descripción con secciones obligatorias (ver template) | Ver `templates/wp-description.md` |
| `type` | enum | Tipo del WP | Epic, Feature, User story, Task, Bug |
| `status` | enum | Estado actual | New, In progress, Developed... |
| `version` | ref | Versión/iteración asignada | v0.1.0 |
| `priority` | enum | Prioridad | Normal, High, Immediate |
| `estimatedTime` | duration | Horas estimadas | PT2H (2 horas) |
| `risk_summary` | custom | Resumen de riesgos identificados | "Dependencia de API externa" |
| `mitigation` | custom | Medidas de mitigación | "Implementar circuit breaker" |
| `target_branch` | custom | Branch objetivo | feat/wp-1837-auth |
| `contract_id` | custom | ID del contrato asociado | CTR-my-project-20260302 |

## Campos de scheduling (nativos OP)

| Campo | Tipo | R/W | Descripción | Ejemplo |
|-------|------|-----|-------------|---------|
| `startDate` | date | RW | Fecha de inicio | 2026-03-10 |
| `dueDate` | date | RW | Fecha de vencimiento | 2026-03-14 |
| `duration` | duration | RW | Duración planificada | P5D (5 días) |
| `derivedStartDate` | date | R | Calculada desde hijos | Automático |
| `derivedDueDate` | date | R | Calculada desde hijos | Automático |
| `percentageDone` | integer | RW | Progreso manual (0-100) | 60 |
| `derivedPercentageDone` | integer | R | Calculado desde hijos | Automático |
| `remainingTime` | duration | RW | Tiempo restante estimado | PT3H |
| `spentTime` | duration | R | Tiempo registrado real | PT5H |
| `scheduleManually` | boolean | RW | Bypass de scheduling automático | false |

> **Tip**: Si un Epic tiene hijos, `derivedStartDate` y `derivedDueDate` se calculan automáticamente desde los dates de los hijos. No asignar dates manualmente a padres con hijos.

## Campos de orquestación (custom fields — configurar en admin)

| Campo | Tipo | Valores | Quién lo asigna | Uso |
|-------|------|---------|----------------|-----|
| `Difficulty` | List | Trivial, Easy, Medium, Hard, Expert | @inception (G2) | Estimar complejidad para asignación |
| `Specialization` | List | Frontend, Backend, Infra, Security, QA, Compliance, DevOps, Full-stack | @inception (G2) | Routing a agente con expertise correcto |
| `Agent Assigned` | List | @jarvis, @inception, @gtd, @morpheus, @agent-smith, @oracle, @pepper, @ariadne | @inception (G2) o auto | Quién debe ejecutar este WP |
| `Tech Stack` | List (multi) | HTML/CSS, JavaScript, Python, Bash, Docker, Terraform, Go, Rust, SQL | @inception (G2) | Tecnologías requeridas |
| `Automation Level` | List | Full-auto, Semi-auto, Human-required | @inception (G2) | Grado de autonomía del agente |
| `Gate Current` | List | G0, G1, G2, G3, G4, G5, G6, G7, G8, G9 | Automático | Gate activo para este WP |

### Lógica de asignación automática

```
Si Specialization=Security → Agent Assigned=@morpheus
Si Specialization=QA       → Agent Assigned=@oracle
Si Specialization=DevOps   → Agent Assigned=@pepper
Si Specialization=Frontend AND Difficulty≤Medium → Agent Assigned=@gtd
Si Specialization=Backend AND Difficulty=Expert → Agent Assigned=@gtd + Human-required
Si Gate Current=G2 → Agent Assigned=@inception
Si Gate Current=G5 → Agent Assigned=@agent-smith
```

### Cómo un agente usa estos campos

```
1. @gtd ejecuta query: "Mis tareas pendientes"
2. Obtiene Task#1897 con:
   - Difficulty: Medium
   - Specialization: Frontend
   - Tech Stack: [HTML/CSS, JavaScript]
   - Automation Level: Full-auto
   - Gate Current: G3
3. @gtd sabe:
   - Complejidad media → no necesita escalar
   - Frontend con HTML/CSS + JS → sus herramientas estándar
   - Full-auto → puede completar sin intervención humana
   - Está en G3 → debe implementar y transicionar a Developed
```

## Campos custom de trazabilidad

| Campo | Tipo | Cuándo se rellena | Ejemplo |
|-------|------|-------------------|---------|
| `Github` | url | Al crear PR | https://github.com/org/repo/pull/42 |
| `Github Commit` | url | Al hacer commit | https://github.com/org/repo/commit/abc123 |
| `Evidence URL` | url | En G8 (evidence export) | https://github.com/org/journal/bundle/... |
| `Evidence SHA256` | string | En G8 | a1b2c3d4... |
| `Ledger Entry` | string | En G8 | ledger/2026/03/entries.jsonl:42 |

## Secciones obligatorias en `description`

Toda descripción de WP debe incluir:

```markdown
## Contexto
[Por qué existe este WP, contexto de negocio]

## Plan
[Pasos de implementación, riesgos, mitigaciones]

## Trazabilidad Git
- Branch: `feat/wp-XXXX-descripcion`
- PR: [pendiente]
- Commits: [pendiente]

## Verificacion
[Criterios de verificación y cierre]
```

## Operaciones CRUD

### Crear Work Package

```bash
# User Story
openproject-sync.sh create-story <PROJECT> "Título" "Descripción" [STATUS_ID] [VERSION_ID] [PARENT_ID]

# Task (hijo de User Story)
openproject-sync.sh create-task <PROJECT> "Título" "Descripción" [STATUS_ID] [VERSION_ID] [PARENT_ID]

# Tipo genérico
openproject-sync.sh create <PROJECT> <TYPE_ID> "Título" "Descripción" [STATUS_ID] [VERSION_ID] [PARENT_ID]

# Hijo de un WP existente (resuelve tipo por nombre)
openproject-sync.sh create-child <PARENT_WP_ID> <TYPE_NAME> "Título" ["Descripción"] [STATUS_ID] [VERSION_ID]
```

### Leer/Consultar

```bash
# Catálogo completo de un proyecto
openproject-sync.sh catalog <PROJECT>

# Validar campos de un WP
openproject-sync.sh validate <WP_ID>

# Ver schema de campos custom
openproject-sync.sh schema-custom-fields <PROJECT> <TYPE_ID>
```

### Actualizar

```bash
# Cambiar estado
openproject-sync.sh transition <WP_ID> <STATUS_NAME>

# Cambiar estado + log de tiempo + comentario
openproject-sync.sh transition-and-log <WP_ID> <STATUS_NAME> [AGENT] [COMMENT]

# Actualizar descripción
openproject-sync.sh description <WP_ID> "MARKDOWN"

# Generar descripción desde template
openproject-sync.sh template-description <SHORT_SUMMARY> <BRANCH> [PR_URL] [COMMIT_URL]

# Asignar versión
openproject-sync.sh version <WP_ID> <VERSION_ID>

# Propagar versión a hijos
openproject-sync.sh propagate-version <WP_ID>

# Estimar horas
openproject-sync.sh estimate <WP_ID> <HOURS>

# Asignar reviewer
openproject-sync.sh assign-reviewer <WP_ID> <USER_ID> [assignee|responsible]

# Cambiar tipo
openproject-sync.sh update-type <WP_ID> <TYPE_NAME>
```

### Campos custom

```bash
# Setear campo custom genérico
openproject-sync.sh set-custom-field <WP_ID> <FIELD_NAME> <VALUE>

# Atajos para campos frecuentes
openproject-sync.sh set-contract-id <WP_ID> <CONTRACT_ID>
openproject-sync.sh set-github-pr <WP_ID> <PR_URL>
openproject-sync.sh set-github-commit <WP_ID> <COMMIT_URL>
openproject-sync.sh set-evidence-url <WP_ID> <EVIDENCE_URL>
openproject-sync.sh set-evidence-sha256 <WP_ID> <SHA256>
openproject-sync.sh set-ledger-entry <WP_ID> <LEDGER_VALUE>

# Resolver nombre de campo a API key
openproject-sync.sh resolve-custom-field <WP_ID> <FIELD_NAME> [--verbose]
```

### Eliminar

```bash
# ⚠️ Eliminación permanente — usar con extrema cautela
openproject-sync.sh delete-wp <WP_ID>
```

## Reglas de negocio

1. **Toda User Story DEBE tener `contract_id`** — es la raíz contractual
2. **Tasks heredan versión del padre** — usar `propagate-version` tras asignar
3. **estimatedTime es obligatorio** para todos los WPs ejecutables
4. **Branch naming**: `feat/wp-<ID>-<descripcion-corta>` o `fix/wp-<ID>-<descripcion>`
5. **Commit naming**: `type(scope): description [WP#ID]`
6. **No cerrar WPs sin evidencia** — G8 debe completarse antes de G9

## Operaciones avanzadas

### Consultar WPs (queries)

```bash
# Listar WPs de un proyecto con filtros
GET /api/v3/projects/{id}/work_packages?filters=[
  {"status":{"operator":"o","values":[]}},
  {"type":{"operator":"=","values":["3"]}}
]&sortBy=[["priority","desc"]]&pageSize=50

# WPs asignados a un agente específico (via custom field)
GET /api/v3/projects/{id}/work_packages?filters=[
  {"customField42":{"operator":"=","values":["@gtd"]}},
  {"status":{"operator":"=","values":["7","14"]}}
]

# WPs sin estimar
GET /api/v3/projects/{id}/work_packages?filters=[
  {"estimatedTime":{"operator":"!*","values":[]}}
]

# WPs vencidos (dueDate en el pasado)
GET /api/v3/projects/{id}/work_packages?filters=[
  {"dueDate":{"operator":"t-","values":["0"]}},
  {"status":{"operator":"o","values":[]}}
]
```

### Operaciones silenciosas (batch)

```bash
# Actualizar WP sin disparar notificaciones
PATCH /api/v3/work_packages/{id}?notify=false
{
  "status": { "href": "/api/v3/statuses/7" }
}
```

> **Regla**: Usar `notify=false` cuando un agente hace múltiples transiciones en batch. Evita flooding de emails/notificaciones.

### Available assignees

```bash
# Ver quién puede ser asignado a un WP
GET /api/v3/work_packages/{id}/available_assignees
```

### Available relation candidates

```bash
# Ver WPs candidatos para crear relación
GET /api/v3/work_packages/{id}/available_relation_candidates?query=auth
```

## Errores comunes y soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Custom field no disponible | Schema del proyecto no tiene el campo | Verificar con `schema-custom-fields` |
| No se puede asignar usuario | Falta rol assignee en el proyecto | Pedir config manual a admin OP |
| Versión no encontrada | Versión compartida entre proyectos | Usar `list-versions` para verificar |
| Descripción vacía tras update | Markdown mal escapado | Usar heredoc o file input |
| 409 Conflict en PATCH | Lock version desactualizada | Re-leer WP para obtener lockVersion fresco |
| 422 al crear relación | Ciclo detectado o relación duplicada | Verificar grafo de dependencias antes |
| Dates no se actualizan | WP tiene `scheduleManually=true` | Cambiar a false para scheduling automático |
