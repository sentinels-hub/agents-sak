# GitHub — Repositorios

## Convenciones de repositorio Sentinels

### Naming

```
sentinels-<nombre>           # Código fuente
sentinels-<nombre>-journal   # Journal de evidencia (companion repo)
```

Ejemplos:
- `sentinels-hub` / `sentinels-hub-journal`
- `sentinels-lighthouse` (source of truth, sin journal)
- `agents-sak` (este repo)

### Organización

Todos los repos bajo la org `sentinels-hub` en GitHub.

## Operaciones

### Listar repos de la org

```bash
gh repo list sentinels-hub --limit 50 --json name,description,isPrivate
```

### Crear repositorio

```bash
gh repo create sentinels-hub/<nombre> \
  --private \
  --description "Descripción corta" \
  --clone
```

### Configurar protección de rama main

```bash
gh api repos/sentinels-hub/<repo>/branches/main/protection \
  -X PUT \
  -f required_status_checks='{"strict":true,"contexts":[]}' \
  -f enforce_admins=true \
  -f required_pull_request_reviews='{"required_approving_review_count":1}' \
  -f restrictions=null
```

### Settings recomendados

| Setting | Valor | Razón |
|---------|-------|-------|
| Default branch | `main` | Consistencia |
| Allow merge commits | No | Solo squash o rebase |
| Allow squash merging | Sí | Un commit limpio por PR |
| Allow rebase merging | Sí | Historial lineal |
| Auto-delete head branches | Sí | Cleanup automático |
| Allow auto-merge | Sí | Agentes pueden activarlo |

```bash
gh api repos/sentinels-hub/<repo> -X PATCH \
  -f allow_squash_merge=true \
  -f allow_merge_commit=false \
  -f allow_rebase_merge=true \
  -f delete_branch_on_merge=true \
  -f allow_auto_merge=true
```

## Journal repos

Los journals son repos companion que almacenan evidencia:

```
sentinels-hub/
  src/
  ...
sentinels-hub-journal/
  evidence/
    CTR-xxx/
      bundle-manifest.json
      artifacts/
  ledger/
    ledger.jsonl
```

### Crear journal

```bash
gh repo create sentinels-hub/<nombre>-journal \
  --private \
  --description "Evidence journal for <nombre>"

# Estructura inicial
mkdir -p evidence ledger
echo '[]' > ledger/ledger.jsonl
git add . && git commit -m "chore: init journal structure"
```
