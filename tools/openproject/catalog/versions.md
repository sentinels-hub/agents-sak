# OpenProject — Versiones

Guía para gestión de versiones (iteraciones/releases) en OpenProject.

## Concepto

Las **Versiones** en OpenProject representan iteraciones o releases. Sentinels usa SemVer: `vMAJOR.MINOR.PATCH`.

> **No hay concepto separado de "Sprint"**. Los sprints se modelan como versiones con fechas de inicio y fin.

## Estados de versión

| Estado | Significado | Visible en Backlogs | Visible en Roadmap |
|--------|-------------|--------------------|--------------------|
| `open` | Mutable, acepta WPs | ✅ | ✅ |
| `locked` | Scope congelado, no acepta nuevos WPs | ❌ | ✅ |
| `closed` | Completa, no mutable | ❌ | ❌ |

## Operaciones

### Crear versión

```bash
openproject-sync.sh create-version <PROJECT> <NAME> <START_DATE> <END_DATE> [DESCRIPTION]

# Ejemplo
openproject-sync.sh create-version sentinels-hub "v0.2.0" "2026-03-10" "2026-03-24" "Sprint 2: Auth + Dashboard"
```

### Listar versiones

```bash
openproject-sync.sh list-versions <PROJECT>
```

### Asignar versión a WP

```bash
# Asignar a un WP
openproject-sync.sh version <WP_ID> <VERSION_ID>

# Propagar versión del padre a todos los hijos
openproject-sync.sh propagate-version <WP_ID>
```

### Eliminar versión

```bash
# ⚠️ Solo si no tiene WPs asignados
openproject-sync.sh delete-version <VERSION_ID>
```

## Convenciones Sentinels

### Naming

```
v0.1.0    → Primera iteración funcional
v0.2.0    → Segunda iteración (feature increment)
v1.0.0    → Primera release estable
v1.0.1    → Patch/bugfix
```

### Reglas

1. **Una versión por proyecto** — NO compartir versiones entre proyectos
2. **Herencia obligatoria**: User Story → Task (los hijos heredan la versión del padre)
3. **SemVer estricto**: formato `vX.Y.Z`
4. **Ciclo de vida**: `open` → `locked` (al cerrar scope) → `closed` (al completar)
5. **Fechas obligatorias**: start_date y end_date deben estar definidas

### Problemas conocidos

| Problema | Contexto | Workaround |
|----------|----------|------------|
| Versiones compartidas entre proyectos | OP permite version inheritance | Crear versiones específicas por proyecto |
| 8 nombres únicos en 13 proyectos | Herencia histórica | Normalizar con `fresh-start` cleanup |
| startDate/dueDate no disponibles como custom fields | Limitación de schema por proyecto | Usar fechas de la versión, no del WP |
