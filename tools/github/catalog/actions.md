# GitHub — Actions (CI/CD)

## Workflows Sentinels

### Workflow base recomendado

```yaml
# .github/workflows/ci.yml
name: CI
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        run: echo "lint step"

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: echo "test step"

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Security scan
        run: echo "security scan"
```

## Operaciones

### Listar workflows

```bash
gh workflow list --repo sentinels-hub/<repo>
```

### Ver runs recientes

```bash
gh run list --repo sentinels-hub/<repo> --limit 10
```

### Ver status de un run

```bash
gh run view <RUN_ID> --repo sentinels-hub/<repo>
```

### Checks de un PR

```bash
gh pr checks <PR_NUMBER> --repo sentinels-hub/<repo>
```

### Trigger manual de un workflow

```bash
gh workflow run ci.yml --repo sentinels-hub/<repo> --ref main
```

## Status checks y gates

| Gate | Check requerido | Agente |
|------|----------------|--------|
| G3 | `ci/lint`, `ci/test` | @gtd |
| G4 | `security/scan` | @morpheus |
| G5 | `review/approved` | @agent-smith |
| G6 | `qa/pass` | @oracle |

Los status checks se configuran como branch protection rules:

```bash
gh api repos/sentinels-hub/<repo>/branches/main/protection \
  -X PUT \
  -f required_status_checks='{"strict":true,"contexts":["ci/lint","ci/test","security/scan"]}'
```

## Deployment

### Deploy via GitHub Actions (G7 — @pepper)

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: echo "deploy step"
```

### Environments

```bash
# Crear environment con protection
gh api repos/sentinels-hub/<repo>/environments/production \
  -X PUT \
  -f wait_timer=0 \
  -f reviewers='[{"type":"User","id":12345}]'
```
