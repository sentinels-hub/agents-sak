# Playbook: @inception — Planificador

**Gate**: G2 (Plan Approved)
**Rol**: Validar requisitos, crear árbol de WPs, asignar campos de orquestación, establecer relaciones.

## Queries principales

### Q1: Backlog sin planificar
```json
{
  "name": "@inception — Backlog sin planificar",
  "filters": [
    { "field": "type", "operator": "=", "values": ["User story"] },
    { "field": "status", "operator": "=", "values": ["New"] },
    { "field": "customField:contract_id", "operator": "*", "values": [] }
  ],
  "sortBy": [["priority", "desc"]]
}
```

### Q2: WPs sin estimación
```json
{
  "name": "@inception — Sin estimación",
  "filters": [
    { "field": "estimatedTime", "operator": "!*", "values": [] },
    { "field": "status", "operator": "o", "values": [] }
  ],
  "sortBy": [["type", "asc"]]
}
```

### Q3: WPs sin campos de orquestación
```json
{
  "name": "@inception — Sin orquestación",
  "filters": [
    { "field": "customField:difficulty", "operator": "!*", "values": [] },
    { "field": "status", "operator": "o", "values": [] },
    { "field": "type", "operator": "=", "values": ["Task", "User story"] }
  ]
}
```

## Flujo G2 — Plan Approved

```
1. Ejecutar Q1 → User Stories con contract_id pero sin planificar
2. Para cada US:
   a. ANALIZAR requisitos:
      - Leer description → extraer scope, AC, DoD
      - Evaluar complejidad → asignar Difficulty
      - Identificar especialización → asignar Specialization
      - Identificar tech stack → asignar Tech Stack
      - Determinar nivel de autonomía → asignar Automation Level

   b. CREAR árbol de WPs:
      - Si necesita Features → crear como hijas del Epic
      - Crear Tasks como breakdown de la US
      - Cada Task con: subject, description, estimatedTime

   c. ASIGNAR campos de orquestación a cada WP:
      - Difficulty (Trivial/Easy/Medium/Hard/Expert)
      - Specialization (Frontend/Backend/Infra/Security/QA/...)
      - Agent Assigned (según lógica de routing)
      - Tech Stack ([HTML/CSS, JavaScript, ...])
      - Automation Level (Full-auto/Semi-auto/Human-required)
      - Gate Current: G2

   d. ESTABLECER relaciones:
      - Tasks secuenciales → precedes/follows con lag
      - Tasks con dependencias → requires
      - US que bloquea otra US → blocks

   e. ASIGNAR versión:
      - Asignar versión a la US
      - propagate-version a todos los hijos

   f. ESTABLECER dates:
      - startDate/dueDate en Tasks
      - OP calcula derivedDates en la US automáticamente

   g. COMPLETAR description (template):
      - ## Contexto (ya existe)
      - ## Plan (con Tasks, riesgos, dependencias)
      - ## Trazabilidad Git (branch pendiente)
      - ## Verificacion (AC + DoD)

   h. VALIDAR:
      - Todos los campos requeridos presentes
      - estimatedTime en todas las Tasks
      - Relaciones sin ciclos
      - Version asignada y propagada

   i. TRANSICIONAR:
      - US → "In specification"
      - Tasks → "In specification"

   j. COMENTARIO governance:
      "[@inception@{V}] | contract: {CTR} | gate: G2 | Plan approved — {N} tasks, {H}h estimated, version {VER}"
```

## Lógica de routing de agentes

```python
def assign_agent(wp):
    gate = wp.gate_current
    spec = wp.specialization
    diff = wp.difficulty

    # Gate-based routing (override)
    if gate == "G4": return "@morpheus"
    if gate == "G5": return "@agent-smith"
    if gate == "G6": return "@oracle"
    if gate == "G7": return "@pepper"

    # Specialization-based routing (G3)
    if spec == "Security": return "@morpheus"
    if spec == "QA": return "@oracle"
    if spec == "DevOps": return "@pepper"
    if spec in ["Frontend", "Backend", "Full-stack"]:
        if diff == "Expert":
            return "@gtd"  # + flag Human-required
        return "@gtd"

    # Default
    return "@gtd"
```

## Ejemplo: planificación real

```
Input: US#2001 "Implement OAuth2 for Sentinels Hub"

@inception evalúa:
  - Difficulty: Hard (OAuth es complejo, múltiples flujos)
  - Specialization: Backend
  - Tech Stack: [JavaScript, Python]
  - Automation Level: Semi-auto (necesita config de provider)

@inception crea:
  Task#2010 "Setup OAuth provider"
    Difficulty: Medium, Spec: Backend, Agent: @gtd, Est: 2h

  Task#2011 "Implement JWT flow"
    Difficulty: Hard, Spec: Backend, Agent: @gtd, Est: 3h
    requires → Task#2010

  Task#2012 "Session management"
    Difficulty: Medium, Spec: Backend, Agent: @gtd, Est: 3h
    requires → Task#2011

  Task#2013 "Security review prep"
    Difficulty: Easy, Spec: Security, Agent: @morpheus, Est: 1h
    follows → Task#2012 (lag: 0)

@inception establece relaciones:
  Task#2010 ──precedes(0d)──→ Task#2011
  Task#2011 ──precedes(0d)──→ Task#2012
  Task#2012 ──precedes(0d)──→ Task#2013

Resultado: @gtd ejecuta su query, ve Tasks 2010-2012 en orden.
          @morpheus ve Task#2013 cuando 2012 se complete.
```

## Campos que @inception lee/escribe

| Campo | Lee | Escribe | Cuándo |
|-------|-----|---------|--------|
| subject, description | ✓ | ✓ | Crear/actualizar WPs |
| type | ✓ | ✓ | Crear árbol (Feature, US, Task) |
| estimatedTime | | ✓ | Estimar cada Task |
| version | | ✓ | Asignar versión |
| startDate, dueDate | | ✓ | Planificar dates |
| Difficulty | | ✓ | Evaluar complejidad |
| Specialization | | ✓ | Clasificar expertise |
| Agent Assigned | | ✓ | Routing a agente |
| Tech Stack | | ✓ | Tecnologías requeridas |
| Automation Level | | ✓ | Grado de autonomía |
| Gate Current | | ✓ | Setear a G2 |
| risk_summary, mitigation | | ✓ | Análisis de riesgos |
| target_branch | | ✓ | Convención de branch |
| Relations | | ✓ | Crear dependencias |
