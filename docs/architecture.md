# Agents SAK — Arquitectura

## Principios de diseño

1. **Zero dependencies para UI**: HTML puro + CSS + Vanilla JS. Sin frameworks, sin build tools.
2. **Modularidad por herramienta**: Cada herramienta en `tools/<nombre>/` es autónoma.
3. **Schemas first**: Toda estructura de datos tiene un JSON Schema antes de implementación.
4. **Catálogo antes de código**: Los agentes primero entienden QUÉ pueden hacer, luego CÓMO.
5. **Consistencia con Lighthouse**: Nomenclatura, estados, campos y flujos alineados con `policy.yaml`.

## Capas del sistema

```
┌─────────────────────────────────────────────┐
│                   UI Web                     │  ← Dashboard transversal
│         (HTML/CSS/JS — zero deps)            │     para todas las herramientas
├─────────────────────────────────────────────┤
│              tools/<herramienta>/             │  ← Toolkit por dominio
│  ┌──────────┬──────────┬──────────┬────────┐│
│  │ catalog/ │ schemas/ │templates/│scripts/││
│  │  (qué)   │(validar) │ (cómo)   │(hacer) ││
│  └──────────┴──────────┴──────────┴────────┘│
├─────────────────────────────────────────────┤
│          APIs externas (OP, GitHub)          │  ← Servicios consumidos
└─────────────────────────────────────────────┘
```

## Flujo de datos

```
Agente necesita crear WP
  → Lee catalog/work-packages.md         (entiende la operación)
  → Usa templates/wp-description.md      (genera la descripción)
  → Valida contra schemas/work-package   (verifica antes de enviar)
  → Ejecuta scripts/op-cli.sh create     (envía a OpenProject API)
  → UI refleja el nuevo WP               (visibilidad)
```

## Relación con el ecosistema Sentinels

```
sentinels-lighthouse
  │
  │ define políticas, gates, schemas de protocolo
  │ (source of truth para governance)
  │
  ▼
agents-sak
  │
  │ provee herramientas operativas:
  │ - Catálogos: qué operaciones existen
  │ - Schemas: cómo validar datos
  │ - Templates: formatos estándar
  │ - Scripts: ejecución
  │ - UI: visibilidad
  │
  ▼
sentinels-agents
  │
  │ consume lighthouse (governance) + sak (tools)
  │ ejecuta workflows con agentes nombrados
  │ (@jarvis, @inception, @gtd, @morpheus, etc.)
  │
  ▼
sentinels-*-journal
  │
  │ almacena evidencia inmutable
  │ (bundles, ledger, hash-chain)
```

## Decisiones técnicas

### DR-001: UI zero dependencies
- **Contexto**: sentinels-hub ya usa HTML/CSS/JS puro con estilo HUD
- **Decisión**: Mantener el mismo patrón — consistencia visual y técnica
- **Consecuencia**: Más código manual, pero cero complejidad de build/deploy

### DR-002: Catálogo antes de scripts
- **Contexto**: Los agentes necesitan entender QUÉ hacer antes de CÓMO hacerlo
- **Decisión**: Crear documentación de operaciones (catalog/) antes de los scripts
- **Consecuencia**: Los agentes pueden operar con el script actual (openproject-sync.sh) mientras se refactoriza

### DR-003: Schemas alineados con policy.yaml
- **Contexto**: Lighthouse define campos requeridos en `openproject_required_fields`
- **Decisión**: Los schemas SAK replican exactamente los requisitos de Lighthouse
- **Consecuencia**: Si Lighthouse cambia, SAK debe actualizarse — source of truth es Lighthouse

### DR-004: Una UI para todas las herramientas
- **Contexto**: Se añadirán más herramientas (GitHub, Evidence, Compliance)
- **Decisión**: La UI es transversal, con navegación entre vistas de cada herramienta
- **Consecuencia**: El routing y layout se diseñan desde el inicio para multi-herramienta
