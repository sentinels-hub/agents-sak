# OpenProject — Time Tracking

Guía para registro de tiempo y actividades en OpenProject.

## Concepto

El **time tracking** en Sentinels es **obligatorio para todos los WPs ejecutables**. Permite:

- Medir velocidad real vs. estimada
- Calcular progreso basado en trabajo (work-based)
- Trazabilidad de esfuerzo por actividad
- Compliance con ISO 9001 (process standardization)

## Actividades disponibles

| Actividad | Uso típico | Agente |
|-----------|-----------|--------|
| Management | Gestión de proyecto, planificación | @jarvis, @inception |
| Specification | Definición de requisitos, análisis | @inception |
| Development | Implementación de código | @gtd |
| Installation | Setup de infraestructura, deploy | @pepper |
| Integration | Integración de componentes | @gtd |
| Testing | QA, verificación funcional | @oracle |
| Support | Soporte, resolución de incidentes | Cualquiera |
| Other | Actividades no clasificadas | Cualquiera |

> Se pueden crear actividades custom, e.g., "Compliance/Evidence" para @oracle/@ariadne.

## Operaciones

### Registrar tiempo

```bash
# Registro básico
openproject-sync.sh log-time <WP_ID> <HOURS> ["comment"] [ACTIVITY_NAME]

# Ejemplos
openproject-sync.sh log-time 1897 0.5 "File structure created" "Development"
openproject-sync.sh log-time 1889 1.0 "Plan review and approval" "Specification"
openproject-sync.sh log-time 1837 0.25 "Security scan completed" "Testing"
```

### Transición + log combinado

```bash
# Transiciona estado Y registra tiempo en un solo paso
openproject-sync.sh transition-and-log <WP_ID> <STATUS_NAME> [AGENT] [COMMENT]
```

### Consultar actividades

```bash
# Listar todas las actividades disponibles
openproject-sync.sh list-activities

# Resolver nombre de actividad a ID
openproject-sync.sh resolve-activity <ACTIVITY_NAME>
```

## Estimación vs. Tiempo real

| Campo | Significado | Cuándo se rellena |
|-------|-------------|-------------------|
| `estimatedTime` | Horas planificadas | G2 (@inception) |
| Tiempo registrado | Horas reales trabajadas | Durante ejecución |
| Remaining work | Derivado: estimado - registrado | Automático |

### Formato de estimatedTime

OpenProject usa formato ISO 8601 duration:
- `PT0.5H` = 30 minutos
- `PT1H` = 1 hora
- `PT2.5H` = 2 horas 30 minutos

```bash
# Estimar un WP
openproject-sync.sh estimate <WP_ID> <HOURS>

# Ejemplo: 2 horas
openproject-sync.sh estimate 1897 2
```

## Patrones por gate

| Gate | Agente | Actividad típica | Horas típicas |
|------|--------|-------------------|---------------|
| G0 | @jarvis | Management | 0.25 - 0.5 |
| G1 | @jarvis | Management | 0.1 - 0.25 |
| G2 | @inception | Specification | 1 - 4 |
| G3 | @gtd | Development | Variable |
| G4 | @morpheus | Testing | 0.5 - 2 |
| G5 | @agent-smith | Testing | 0.5 - 2 |
| G6 | @oracle | Testing | 1 - 3 |
| G7 | @pepper | Installation | 0.5 - 2 |
| G8 | @jarvis + @ariadne | Management | 0.5 - 1 |
| G9 | @jarvis | Management | 0.25 - 0.5 |

## Reglas

1. **Toda hora trabajada se registra** — no hay trabajo "gratis"
2. **Actividad obligatoria** — cada entry debe clasificarse
3. **Comentario descriptivo** — qué se hizo, no solo cuánto
4. **Consistencia agente↔actividad** — @gtd registra Development, no Management
5. **estimatedTime antes de empezar** — no se inicia sin estimación previa
