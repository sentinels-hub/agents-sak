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

## Campos custom recomendados

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

## Errores comunes y soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Custom field no disponible | Schema del proyecto no tiene el campo | Verificar con `schema-custom-fields` |
| No se puede asignar usuario | Falta rol assignee en el proyecto | Pedir config manual a admin OP |
| Versión no encontrada | Versión compartida entre proyectos | Usar `list-versions` para verificar |
| Descripción vacía tras update | Markdown mal escapado | Usar heredoc o file input |
