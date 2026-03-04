# GitHub — Pull Requests

## Ciclo de vida de un PR en Sentinels

```
Branch creada (G3)
  → PR abierto (Draft o Ready)
    → Security scan (G4 — @morpheus)
      → Code review (G5 — @agent-smith)
        → QA check (G6 — @oracle)
          → Merge a main
            → Deploy (G7 — @pepper)
```

## Crear PR

### Formato del título

```
type(scope): description [WP#ID]
```

Ejemplo: `feat(auth): implement OAuth2 provider [WP#1897]`

### Formato del body

Usar template de `templates/pr-description.md`:

```markdown
## Contrato
- **Contract ID**: CTR-sentinels-hub-20260302
- **Work Package**: WP#1897
- **Gate actual**: G3 → G4

## Resumen
Breve descripción de los cambios.

## Cambios
- Archivo 1: qué se hizo
- Archivo 2: qué se hizo

## Trazabilidad
- Branch: `feat/wp-1897-oauth2-provider`
- Commits: N commits
- WP Status: Developed

## Verificación
- [ ] Tests pasan
- [ ] Sin secretos expuestos
- [ ] Lint OK
- [ ] Funcionalidad verificada

## Governance
[@gtd@0.3.0] | contract: CTR-sentinels-hub-20260302 | gate: G3 | PR ready for review
```

### Crear PR via CLI

```bash
gh pr create \
  --title "feat(auth): implement OAuth2 provider [WP#1897]" \
  --body-file pr-body.md \
  --base main \
  --head feat/wp-1897-oauth2-provider \
  --label "gate:G3,agent:gtd" \
  --assignee "@me"
```

## Labels de governance

| Label | Color | Uso |
|-------|-------|-----|
| `gate:G3` | `#7B61FF` | Implementation |
| `gate:G4` | `#FFD700` | Security scan |
| `gate:G5` | `#FF4444` | Code review |
| `gate:G6` | `#00C9FF` | QA |
| `gate:G7` | `#00FF88` | Deploy |
| `agent:gtd` | `#7B61FF` | Agente asignado |
| `agent:morpheus` | `#FFD700` | Agente asignado |
| `agent:agent-smith` | `#FF4444` | Agente asignado |
| `priority:high` | `#FF0000` | Prioridad |
| `priority:normal` | `#0075CA` | Prioridad |

### Crear labels en un repo

```bash
gh label create "gate:G3" --color "7B61FF" --description "Implementation tracked"
gh label create "gate:G4" --color "FFD700" --description "Security analysis"
gh label create "gate:G5" --color "FF4444" --description "Code review"
gh label create "gate:G6" --color "00C9FF" --description "QA verification"
gh label create "gate:G7" --color "00FF88" --description "Deployment"
gh label create "agent:gtd" --color "7B61FF" --description "Agent @gtd"
gh label create "agent:morpheus" --color "FFD700" --description "Agent @morpheus"
gh label create "agent:agent-smith" --color "FF4444" --description "Agent @agent-smith"
gh label create "agent:oracle" --color "00C9FF" --description "Agent @oracle"
gh label create "agent:pepper" --color "00FF88" --description "Agent @pepper"
```

## Review process

### @morpheus (G4) — Security Review

```bash
# Añadir review comment
gh pr review <PR_NUMBER> --comment --body "[@morpheus@1.0] Security scan: PASS — no vulnerabilities found"

# O request changes
gh pr review <PR_NUMBER> --request-changes --body "[@morpheus@1.0] Security scan: FINDINGS — 2 issues"
```

### @agent-smith (G5) — Code Review

```bash
# Aprobar
gh pr review <PR_NUMBER> --approve --body "[@agent-smith@1.0] Code review: APPROVE — quality OK"

# Request changes
gh pr review <PR_NUMBER> --request-changes --body "[@agent-smith@1.0] Code review: REQUEST_CHANGES — 3 findings"
```

## Merge

### Squash merge (recomendado)

```bash
gh pr merge <PR_NUMBER> --squash --delete-branch
```

### Vincular PR en OpenProject

```bash
# Después de crear el PR, registrar URL en OP
op-cli.sh wp set-field <WP_ID> "GitHub PR" "https://github.com/sentinels-hub/<repo>/pull/<N>"
```

## Queries útiles

```bash
# PRs abiertos en un repo
gh pr list --repo sentinels-hub/<repo> --json number,title,labels,state

# PRs pendientes de review
gh pr list --repo sentinels-hub/<repo> --search "review:required"

# PRs por label
gh pr list --repo sentinels-hub/<repo> --label "gate:G5"

# Checks de un PR
gh pr checks <PR_NUMBER>
```
