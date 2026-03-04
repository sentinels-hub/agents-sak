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
│   ├── openproject/          # Gestión de Work Packages, orquestación
│   │   ├── catalog/          # Catálogo de operaciones
│   │   ├── schemas/          # Schemas de validación JSON
│   │   ├── templates/        # Templates para agentes
│   │   ├── playbooks/        # Playbooks por agente
│   │   └── scripts/          # CLI modular (op-core, op-cli, op-setup)
│   ├── github/               # GitHub: branches, PRs, commits, CI/CD
│   │   ├── catalog/          # repos, branches, PRs, commits, issues, actions
│   │   ├── schemas/          # branch, commit, PR schemas
│   │   ├── templates/        # PR description, commit message
│   │   └── scripts/          # CLI modular (gh-core, gh-cli)
│   ├── evidence/             # Bundles de evidencia, ledger, verificación
│   │   ├── catalog/          # bundles, ledger, verification, redaction
│   │   ├── schemas/          # bundle, ledger-entry schemas (espejo Lighthouse)
│   │   ├── templates/        # bundle manifest, release notes
│   │   ├── playbooks/        # Guías operativas: ariadne (G8), jarvis (G8/G9)
│   │   └── scripts/          # CLI modular (ev-core, ev-cli, ev-setup)
│   └── compliance/           # Compliance: frameworks, controles, auditoría
│       ├── catalog/          # frameworks, controls, mapping, audit-trail
│       ├── schemas/          # control, audit-entry schemas
│       ├── templates/        # control checklist, audit report
│       ├── playbooks/        # Guías operativas: jarvis (G9), oracle (G6)
│       └── scripts/          # CLI modular (co-core, co-cli, co-setup)
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
| `openproject` | v0.5.0 | Gestión de Work Packages, orquestación, saved queries, CLI modular |
| `github` | v0.4.0 | Branches, PRs, commits, labels de governance, trazabilidad Git↔OP |
| `evidence` | v0.6.0 | Bundles SHA-256, ledger append-only, verificación de cadena, redaction |
| `compliance` | v0.6.0 | ISO 27001, ISO 9001, SOC 2, ENS Alta — controles, mapping, audit trail |
| `sak-core` | v0.6.0 | Funciones compartidas cross-tool (timestamps, validators, output helpers) |
| `sak-cli` | v0.6.0 | CLI unificado: `sak op\|gh\|ev\|co\|trace\|gates\|metrics` |
| `sak-trace` | v0.6.0 | Verificación E2E traceability (10 checks offline) |
| `sak-gates` | v0.7.0 | Gate validation: check-ready, check-complete, status, next |
| `sak-metrics` | v0.8.0 | Analytics cross-tool: summary, gaps, coverage |

## Relación con el ecosistema

```
sentinels-lighthouse  →  Define políticas y governance (la constitución)
agents-sak            →  Provee herramientas para ejecutar (el toolkit)
sentinels-agents      →  Ejecuta workflows usando lighthouse + sak (el runtime)
```

**Agents SAK NO reemplaza** Lighthouse (governance) ni Agents (runtime). Es la capa de herramientas que ambos consumen.

## Requisitos

- `bash` 4+, `curl`, `jq`
- `gh` (GitHub CLI) — para tool GitHub
- `sha256sum` o `shasum` — para tool Evidence
- Variables de entorno: `OPENPROJECT_URL`, `OPENPROJECT_API_TOKEN`
- Sin dependencias externas para la UI (HTML/CSS/JS puro)

## Documentación

- [Architecture](docs/architecture.md) — Principios de diseño y capas del sistema
- [API Reference](docs/api-reference.md) — Referencia completa de funciones y comandos
- [Roadmap](docs/roadmap.md) — Versiones completadas y planificadas
- [Changelog](docs/changelog.md) — Historial de cambios

## Licencia

Uso interno — Sentinels Hub.
