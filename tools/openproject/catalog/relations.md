# OpenProject — Relations (Dependencias)

Las relaciones modelan el **grafo de dependencias** entre Work Packages. Permiten que los agentes entiendan el orden de ejecución y los bloqueos antes de actuar.

## Tipos de relación

| Tipo | Inverso | Lag (días) | Uso en orquestación |
|------|---------|-----------|---------------------|
| `relates` | `relates` | No | Asociación genérica — "estos WPs están relacionados" |
| `blocks` | `blocked` | No | **Bloqueo**: WP-A bloquea a WP-B → B no puede avanzar hasta que A se complete |
| `precedes` | `follows` | Sí | **Secuencia**: WP-A precede a WP-B con N días de lag → scheduling automático |
| `requires` | `required` | No | **Dependencia**: WP-B requiere que WP-A esté hecho — similar a blocks pero semántico |
| `duplicates` | `duplicated` | No | **Duplicado**: WP-A es duplicado de WP-B → cerrar uno, mantener el otro |
| `includes` | `partof` | No | **Contención**: WP-A incluye a WP-B — jerarquía adicional al parent/child |

## Relaciones clave para orquestación

### `blocks` / `blocked` — Control de flujo

```
Task#1897 "Setup OAuth" ──blocks──→ Task#1899 "Implement JWT"
                                       │
                                  (no puede empezar hasta
                                   que 1897 esté Closed)
```

**Regla**: Antes de tomar un WP de la cola, el agente verifica si tiene relaciones `blocked`. Si las tiene, pasa al siguiente WP.

### `precedes` / `follows` — Secuencia temporal

```
US#1889 "HUD Theme" ──precedes(2d)──→ US#1891 "Landing Page"
                                         │
                                    (startDate = dueDate de 1889 + 2 días)
```

**Lag**: Días entre el fin de A y el inicio de B. OP ajusta automáticamente las fechas.

### `requires` / `required` — Dependencias técnicas

```
Task#2010 "OAuth Setup" ──requires──→ Task#2012 "Session Mgmt"
                                         │
                                    (necesita OAuth configurado
                                     para poder gestionar sesiones)
```

## API de Relations

### CRUD completo

```bash
# Crear relación
POST /api/v3/work_packages/{id}/relations
{
  "_links": {
    "from": { "href": "/api/v3/work_packages/1897" },
    "to": { "href": "/api/v3/work_packages/1899" }
  },
  "type": "blocks",
  "description": "OAuth setup must complete before JWT implementation"
}

# Crear relación con lag (solo precedes/follows)
POST /api/v3/work_packages/{id}/relations
{
  "_links": {
    "from": { "href": "/api/v3/work_packages/1889" },
    "to": { "href": "/api/v3/work_packages/1891" }
  },
  "type": "precedes",
  "lag": 2,
  "description": "Landing page starts 2 days after HUD theme"
}

# Listar relaciones de un WP
GET /api/v3/work_packages/{id}/relations

# Listar todas las relaciones (con filtros)
GET /api/v3/relations?filters=[{"involved":{"operator":"=","values":["1897"]}}]

# Actualizar relación
PATCH /api/v3/relations/{id}

# Eliminar relación
DELETE /api/v3/relations/{id}
```

### Filtros de relaciones

| Filtro | Uso |
|--------|-----|
| `id` | Relación específica |
| `from` | Relaciones que salen de un WP |
| `to` | Relaciones que llegan a un WP |
| `involved` | Relaciones donde el WP es from O to |
| `type` | Solo blocks, solo precedes, etc. |

### Consultar bloqueos antes de actuar

```bash
# ¿Está bloqueado el WP#1899?
GET /api/v3/work_packages/1899/relations?filters=[{"type":{"operator":"=","values":["blocked"]}}]

# Si count > 0 → verificar que los bloqueadores estén Closed
# Si algún bloqueador no está Closed → saltar este WP
```

## Patrones de orquestación con relaciones

### Patrón 1: Pipeline secuencial

```
Task A ──precedes──→ Task B ──precedes──→ Task C
(G3)                 (G3)                 (G3)

@gtd ejecuta A → transiciona a Developed
→ B se desbloquea automáticamente (dates ajustadas por OP)
→ @gtd toma B de la query
```

### Patrón 2: Gate handoff via blocks

```
US#1889 status:Developed ──blocks──→ US#1889 (same WP, different query)
  │                                    │
  └── @gtd completó G3                └── @morpheus puede iniciar G4
                                           solo cuando status=Developed
```

> En realidad las transiciones de gate usan status, no blocks. Pero si hay dependencias entre User Stories de distintos features, `blocks` es el mecanismo correcto.

### Patrón 3: Dependencia cross-project

```
[sentinels-lighthouse] WP#100 "Policy v2.0"
        │
        └── requires ──→ [agents-sak] WP#200 "Update catalog"
                              │
                              └── No se puede actualizar SAK hasta
                                  que la policy esté cerrada
```

### Patrón 4: Detección de ciclos

Antes de crear una relación, verificar que no se cree un ciclo:
```
A blocks B, B blocks C, C blocks A  ← CICLO → OP lo rechaza con error 422
```

## Grafo de dependencias

Para un proyecto complejo, las relaciones forman un **DAG** (Directed Acyclic Graph):

```
Epic#1837
├── Feature#1881
│   └── US#1889 ──blocks──→ US#1891 (landing necesita theme primero)
│       ├── Task#1897 ──precedes(0d)──→ Task#1899
│       ├── Task#1899 ──precedes(0d)──→ Task#1901
│       └── Task#1901 ──requires──→ Task#1903
└── Feature#1883
    └── US#1891 ──blocked by US#1889
        ├── Task#1907
        └── Task#1909 ──precedes(1d)──→ Task#1911
```

Un agente puede recorrer este grafo para encontrar el **critical path** (la secuencia más larga) y priorizar en consecuencia.

## Reglas

1. **Verificar `blocked` antes de actuar** — siempre consultar relaciones antes de tomar un WP
2. **Usar `precedes/follows` para secuencia temporal** — OP ajusta dates automáticamente
3. **Usar `blocks/blocked` para dependencias duras** — el agente no puede avanzar
4. **Usar `requires/required` para dependencias técnicas** — semántico, no bloquea scheduling
5. **Documentar relaciones con `description`** — explicar POR QUÉ existe la dependencia
6. **No crear ciclos** — OP rechaza con 422, pero validar antes de enviar
7. **Cross-project relations son válidas** — OP las soporta entre cualquier WP accesible
