# Agents SAK — Agents Sentinels Army Knife

Toolkit de herramientas reutilizables para agentes del ecosistema Sentinels.

## Visión

Los agentes Sentinels necesitan herramientas bien definidas, documentadas y validadas para ejecutar su trabajo de forma consistente. **Agents SAK** proporciona:

- **Catálogos de operaciones**: Qué puede hacer un agente y cómo
- **Schemas de validación**: Verificación previa antes de enviar datos
- **Templates estandarizados**: Formatos consistentes entre agentes
- **Scripts modulares**: Herramientas de línea de comandos
- **UI Web**: Dashboard visual para supervisión y operación

## Estructura

```
agents-sak/
├── tools/                    # Herramientas por dominio
│   └── openproject/          # Primera herramienta: OpenProject
│       ├── catalog/          # Catálogo de operaciones
│       ├── schemas/          # Schemas de validación JSON
│       ├── templates/        # Templates para agentes
│       └── scripts/          # CLI modular
├── ui/                       # Web UI transversal (HTML/CSS/JS)
│   ├── index.html
│   ├── css/
│   └── js/
└── docs/                     # Documentación del proyecto
    ├── architecture.md
    ├── roadmap.md
    └── changelog.md
```

## Herramientas disponibles

| Herramienta | Estado | Descripción |
|-------------|--------|-------------|
| `openproject` | 🟢 v0.1.0 | Gestión de Work Packages, versiones, backlogs, roadmaps, trazabilidad |

## Relación con el ecosistema

```
sentinels-lighthouse  →  Define políticas y governance (la constitución)
agents-sak            →  Provee herramientas para ejecutar (el toolkit)
sentinels-agents      →  Ejecuta workflows usando lighthouse + sak (el runtime)
```

**Agents SAK NO reemplaza** Lighthouse (governance) ni Agents (runtime). Es la capa de herramientas que ambos consumen.

## Requisitos

- `bash` 4+, `curl`, `jq`
- Variables de entorno: `OPENPROJECT_URL`, `OPENPROJECT_API_TOKEN`
- Sin dependencias externas para la UI (HTML/CSS/JS puro)

## Licencia

Uso interno — Sentinels Hub.
