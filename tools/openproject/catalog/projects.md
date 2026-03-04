# OpenProject — Proyectos (Capa de Orquestación)

El **Proyecto** no es solo un contenedor de WPs — es una capa de metadatos que dirige la orquestación: estado general, stack tecnológico, equipo, configuración y jerarquía organizativa.

## Anatomía de un proyecto

### Campos nativos

| Campo | Tipo | R/W | Uso en orquestación |
|-------|------|-----|---------------------|
| `id` | Integer | R | Identificador único |
| `identifier` | String | RW | Slug URL (e.g., `agents-sak`) |
| `name` | String | RW | Nombre visible |
| `description` | Markdown | RW | Contexto, objetivos, scope del proyecto |
| `active` | Boolean | RW | Archivar/activar proyecto |
| `public` | Boolean | RW | Visibilidad |
| `status` | Enum | RW | **on_track / at_risk / in_trouble** |
| `statusExplanation` | Markdown | RW | Resumen ejecutivo del estado |
| `parent` | Project ref | RW | Proyecto padre (jerarquía) |
| `createdAt` | DateTime | R | Fecha de creación |
| `updatedAt` | DateTime | R | Última modificación |

### Campos custom (a configurar en admin)

| Campo propuesto | Tipo | Valores | Uso |
|----------------|------|---------|-----|
| `Tech Stack` | List (multi) | HTML/CSS, JS, Python, Bash, Docker, Terraform, Go, Rust | Tecnologías del proyecto |
| `Project Type` | List | Product, Library, Governance, Infrastructure, Research | Naturaleza del proyecto |
| `Lead Agent` | List | @jarvis, @inception, @gtd, etc. | Agente principal responsable |
| `Automation Tier` | List | Full-auto, Semi-auto, Human-heavy | Nivel de automatización alcanzable |
| `Compliance Scope` | List (multi) | ISO 27001, ISO 9001, ISO 42001, SOC2, ENS Alta | Frameworks aplicables |
| `Repository URL` | String | URL | Link al repo GitHub |
| `Lighthouse Version` | String | e.g., 2.0.0 | Versión del protocolo Sentinels aplicada |

## Status del proyecto como señal de orquestación

| Status | Significado | Acción de @jarvis |
|--------|-------------|-------------------|
| `on_track` | Todo según plan | Monitoreo normal |
| `at_risk` | Desviaciones detectadas | Escalar, revisar scope, reasignar |
| `in_trouble` | Bloqueo crítico | Intervención humana requerida |

### Actualización automática del status

```
Si (WPs bloqueados > 20% del total) → at_risk
Si (WPs con dueDate vencido > 10%) → at_risk
Si (WPs bloqueados > 40% O incidentes abiertos) → in_trouble
Si (progreso general > 80% y sin bloqueos) → on_track
```

### statusExplanation como resumen ejecutivo

@jarvis genera automáticamente:

```markdown
**Sprint v0.1.0** — 85% completado (13/15 WPs)
- 2 tareas en progreso: Task#1914, Task#1916
- 0 bloqueos activos
- Horas: 12h estimadas / 10.5h registradas
- Gates: G0-G4 passed, G5 active
- Próximo hito: Code review completo (ETA 2 días)
```

## Jerarquía de proyectos

```
Sentinels Hub (programa)
├── sentinels-lighthouse      (governance)
├── sentinels-agents          (runtime)
├── agents-sak                (toolkit)
├── sentinels-core-ui         (UI framework)
├── cerebro-genesis           (AI core)
└── sentinels-toolkit-v4      (legacy)
```

### API de jerarquía

```bash
# Ver candidatos a padre
GET /api/v3/projects/available_parent_projects

# Crear subproyecto
POST /api/v3/projects
{
  "name": "agents-sak",
  "identifier": "agents-sak",
  "description": { "raw": "Agents Sentinels Army Knife" },
  "_links": {
    "parent": { "href": "/api/v3/projects/42" }
  }
}

# Cambiar padre
PATCH /api/v3/projects/{id}
{
  "_links": {
    "parent": { "href": "/api/v3/projects/42" }
  }
}

# Remover padre (hacer top-level)
PATCH /api/v3/projects/{id}
{
  "_links": {
    "parent": { "href": null }
  }
}
```

## Operaciones de proyecto

### CRUD

```bash
# Listar proyectos (con filtros)
GET /api/v3/projects?filters=[{"active":{"operator":"=","values":["t"]}}]&sortBy=[["name","asc"]]

# Filtrar por status
GET /api/v3/projects?filters=[{"project_status_code":{"operator":"=","values":["at_risk"]}}]

# Filtrar por actividad reciente
GET /api/v3/projects?sortBy=[["latest_activity_at","desc"]]&pageSize=10

# Crear proyecto
POST /api/v3/projects
{
  "name": "Mi Proyecto",
  "identifier": "mi-proyecto",
  "description": { "raw": "Descripción del proyecto" },
  "public": false,
  "_links": {
    "parent": { "href": "/api/v3/projects/42" },
    "status": { "href": "/api/v3/project_statuses/on_track" }
  }
}

# Actualizar
PATCH /api/v3/projects/{id}

# Archivar
PATCH /api/v3/projects/{id}
{ "active": false }

# Eliminar (irreversible)
DELETE /api/v3/projects/{id}
```

### Filtros de proyectos

| Filtro | Uso |
|--------|-----|
| `active` | Solo activos: `"=", ["t"]` |
| `ancestor` | Descendientes de un proyecto |
| `parent_id` | Hijos directos de un proyecto |
| `project_status_code` | Filtrar por on_track/at_risk/in_trouble |
| `name_and_identifier` | Búsqueda por nombre o identifier |
| `principal` | Proyectos donde un usuario es miembro |
| `type_id` | Proyectos que usan ciertos tipos de WP |
| `latest_activity_at` | Actividad reciente |
| `created_at` | Fecha de creación |
| `favorited` | Proyectos favoritos del usuario |

### Membresías (quién trabaja en qué)

```bash
# Listar miembros de un proyecto
GET /api/v3/memberships?filters=[{"project":{"operator":"=","values":["42"]}}]

# Añadir miembro con rol
POST /api/v3/memberships
{
  "_links": {
    "principal": { "href": "/api/v3/users/5" },
    "project": { "href": "/api/v3/projects/42" },
    "roles": [
      { "href": "/api/v3/roles/3" }
    ]
  },
  "_meta": {
    "sendNotification": false
  }
}

# Cambiar rol
PATCH /api/v3/memberships/{id}

# Remover miembro
DELETE /api/v3/memberships/{id}
```

## Proyecto como ficha de orquestación

Cuando un agente necesita contexto sobre un proyecto, hace un GET y obtiene:

```json
{
  "id": 42,
  "identifier": "agents-sak",
  "name": "Agents SAK",
  "description": "Agents Sentinels Army Knife — Toolkit de herramientas",
  "active": true,
  "status": "on_track",
  "statusExplanation": "Sprint v0.1.0 — 85% completado, 0 bloqueos",
  "customField10": "Python, Bash, HTML/CSS",
  "customField11": "Toolkit",
  "customField12": "@jarvis",
  "customField13": "Semi-auto",
  "customField14": ["ISO 27001", "ISO 9001"],
  "customField15": "https://github.com/sentinels-hub/agents-sak",
  "customField16": "2.0.0",
  "_links": {
    "parent": { "href": "/api/v3/projects/1", "title": "Sentinels Hub" },
    "versions": { "href": "/api/v3/projects/42/versions" },
    "workPackages": { "href": "/api/v3/projects/42/work_packages" },
    "types": { "href": "/api/v3/projects/42/types" },
    "memberships": { "href": "/api/v3/memberships?filters=[...]" }
  }
}
```

Con esto, el agente sabe: qué tecnologías usa, qué tipo de proyecto es, quién lidera, qué nivel de automatización, qué compliance aplica, y cuál es su estado actual.

## Reglas

1. **Todo proyecto activo debe tener `status` actualizado** — @jarvis lo revisa periódicamente
2. **`statusExplanation` con métricas reales** — no texto genérico, datos cuantificables
3. **Jerarquía coherente** — los subproyectos heredan compliance scope del padre
4. **Un `identifier` por repo** — mapeo 1:1 entre proyecto OP y repo GitHub
5. **Custom fields de orquestación configurados** — Tech Stack, Lead Agent, Automation Tier como mínimo
6. **Membresías actualizadas** — cada agente-usuario tiene rol correcto en sus proyectos
