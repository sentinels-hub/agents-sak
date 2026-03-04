# GitHub Tool — Agents SAK

Herramienta para que los agentes Sentinels gestionen GitHub con trazabilidad completa hacia OpenProject y Evidence.

## Qué incluye

### Catálogo de operaciones (`catalog/`)

| Documento | Descripción |
|-----------|-------------|
| [repos](catalog/repos.md) | Gestión de repositorios, settings, protección de ramas |
| [branches](catalog/branches.md) | Naming convention, creación, protección, cleanup |
| [pull-requests](catalog/pull-requests.md) | Ciclo de vida de PRs, reviews, merge strategies |
| [commits](catalog/commits.md) | Formato de mensajes, signing, vinculación con WPs |
| [issues](catalog/issues.md) | Issues como canal de feedback, labels, milestones |
| [actions](catalog/actions.md) | CI/CD workflows, status checks, deployment |

### Schemas de validación (`schemas/`)

| Schema | Valida |
|--------|--------|
| [branch.schema.json](schemas/branch.schema.json) | Naming convention de branches |
| [commit.schema.json](schemas/commit.schema.json) | Formato de commit messages |
| [pr.schema.json](schemas/pr.schema.json) | PR con campos de governance |

### Templates (`templates/`)

| Template | Uso |
|----------|-----|
| [pr-description](templates/pr-description.md) | Body de Pull Requests |
| [commit-message](templates/commit-message.md) | Formato de commits |

### Scripts (`scripts/`)

| Script | Uso |
|--------|-----|
| [gh-core.sh](scripts/gh-core.sh) | Funciones compartidas (requiere `gh` CLI) |
| [gh-cli.sh](scripts/gh-cli.sh) | CLI modular: branches, PRs, trazabilidad |

## Cómo usa esto un agente

```
1. Lee el catálogo → Entiende convenciones Git de Sentinels
2. Usa gh-cli.sh branch create → Crea branch con naming correcto
3. Hace commits → Formato type(scope): desc [WP#ID]
4. Usa gh-cli.sh pr create → PR con governance, vincula WP
5. Usa gh-cli.sh pr link-wp → Registra PR URL en OpenProject
```

## Requisitos

- `gh` — GitHub CLI (autenticado)
- `git` — Git configurado con identidad correcta
- `jq` — Para parsing JSON
- Acceso al repositorio en la org `sentinels-hub`

## Alineación con Lighthouse

- Branch naming: `policy.yaml` → `commit_format`
- Commit format: `type(scope): description [WP#ID]`
- PR governance: contract_id, gate, WP references
- Identity: actor en Git debe coincidir con OP (G1)
