# Playbook: @gtd — Implementador

**Gate**: G3 (Implementation Tracked)
**Rol**: Ejecutar las tareas de implementación. Lee de OP qué hacer, implementa, registra trazabilidad.

## Queries principales

### Q1: Mis tareas pendientes (cola de trabajo)
```json
{
  "name": "@gtd — Tareas pendientes",
  "filters": [
    { "field": "type", "operator": "=", "values": ["Task"] },
    { "field": "status", "operator": "=", "values": ["In specification", "Scheduled"] },
    { "field": "customField:agent_assigned", "operator": "=", "values": ["@gtd"] }
  ],
  "sortBy": [["priority", "desc"], ["estimatedTime", "asc"]]
}
```

### Q2: En progreso
```json
{
  "name": "@gtd — En progreso",
  "filters": [
    { "field": "status", "operator": "=", "values": ["In progress"] },
    { "field": "customField:agent_assigned", "operator": "=", "values": ["@gtd"] }
  ],
  "sortBy": [["updatedAt", "asc"]]
}
```

### Q3: Bloqueados
```json
{
  "name": "@gtd — Bloqueados",
  "filters": [
    { "field": "status", "operator": "=", "values": ["On hold"] },
    { "field": "customField:agent_assigned", "operator": "=", "values": ["@gtd"] }
  ],
  "sortBy": [["priority", "desc"]]
}
```

## Flujo G3 — Implementation Tracked

```
1. Ejecutar Q1 → Tasks asignadas a @gtd, listas para implementar
2. Para cada Task (en orden de prioridad):

   a. VERIFICAR que no está bloqueada:
      GET /api/v3/work_packages/{id}/relations?filters=[{"type":{"operator":"=","values":["blocked"]}}]
      → Si bloqueada: saltar, tomar siguiente

   b. LEER instrucciones del WP:
      - subject → qué hacer
      - description → contexto, plan, AC
      - Difficulty → complejidad esperada
      - Specialization → tipo de trabajo
      - Tech Stack → herramientas a usar
      - Automation Level → ¿puedo hacerlo solo?
      - parent → US padre para contexto más amplio
      - Relations "requires" → dependencias técnicas a verificar

   c. TRANSICIONAR: → "In progress"
      transition-and-log {ID} "In progress" "gtd" "Starting implementation"

   d. IMPLEMENTAR:
      - Crear/verificar branch: feat/wp-{ID}-{desc}
      - Escribir código según instrucciones
      - Commits con formato: type(scope): desc [WP#{ID}]
      - Si Automation Level=Human-required → solicitar intervención

   e. REGISTRAR trazabilidad:
      - set-github-commit {ID} {COMMIT_URL}
      - set-github-pr {ID} {PR_URL} (si aplica)
      - log-time {ID} {HOURS} "Implementation" "Development"

   f. TRANSICIONAR: → "Developed"
      transition-and-log {ID} "Developed" "gtd" "Done — commit {SHA} [WP#{ID}]"

   g. ACTUALIZAR campos:
      - Gate Current → G3 (o G4 si es el siguiente)
      - percentageDone → 100 (para la Task)

   h. VERIFICAR propagación:
      - Si todas las Tasks del US padre están Developed:
        → Transicionar US padre a "Developed"
        → Comentario governance G3 en el US

   i. SIGUIENTE:
      Re-ejecutar Q1 → tomar siguiente Task
```

## Decisiones durante implementación

```
Si Difficulty=Trivial/Easy:
  → Implementar directamente, sin preguntas

Si Difficulty=Medium:
  → Implementar, verificar contra AC antes de marcar Developed

Si Difficulty=Hard:
  → Implementar en pasos, commitear frecuentemente
  → Verificar contra AC y DoD antes de marcar Developed

Si Difficulty=Expert:
  → Verificar Automation Level
  → Si Human-required: solicitar review intermedio
  → Si Semi-auto: implementar con cautela, documentar decisiones
```

## Gestión de bloqueos

```
Si un Task está bloqueado:
  1. Verificar la relación "blocked by" → ¿quién lo bloquea?
  2. Si el bloqueador está asignado a otro agente → esperar
  3. Si el bloqueador está asignado a @gtd → resolverlo primero
  4. Si el bloqueo es externo (permiso, config) →
     - Transicionar a "On hold"
     - Comentario: motivo del bloqueo
     - Pasar al siguiente WP en cola

Si surge un bloqueo durante implementación:
  1. Transicionar a "On hold"
  2. Crear Bug o Task hijo describiendo el bloqueo
  3. Establecer relación "blocks" desde el nuevo WP
  4. Continuar con siguiente Task en cola
```

## Campos que @gtd lee/escribe

| Campo | Lee | Escribe | Cuándo |
|-------|-----|---------|--------|
| subject, description | ✓ | | Entender qué implementar |
| Difficulty | ✓ | | Calibrar esfuerzo |
| Specialization | ✓ | | Confirmar que es su área |
| Tech Stack | ✓ | | Seleccionar herramientas |
| Automation Level | ✓ | | Decidir autonomía |
| Relations (blocked) | ✓ | | Verificar bloqueos |
| Relations (requires) | ✓ | | Verificar dependencias |
| status | ✓ | ✓ | In progress → Developed |
| Github Commit | | ✓ | Registrar commits |
| Github PR | | ✓ | Registrar PR |
| percentageDone | | ✓ | Marcar progreso |
| Gate Current | | ✓ | Avanzar a G3 |
| Time entries | | ✓ | Registrar horas |
