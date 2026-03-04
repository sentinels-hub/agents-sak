# GitHub — Branches

## Naming convention

Todas las branches siguen el patrón definido en Lighthouse policy:

```
<type>/wp-<WP_ID>-<descripcion-corta>
```

### Tipos

| Tipo | Uso | Ejemplo |
|------|-----|---------|
| `feat` | Feature / User Story | `feat/wp-1897-oauth2-provider` |
| `fix` | Bugfix | `fix/wp-1905-contrast-ratio` |
| `chore` | Mantenimiento | `chore/wp-2001-update-deps` |
| `docs` | Documentación | `docs/wp-2010-api-reference` |
| `refactor` | Refactoring sin cambio funcional | `refactor/wp-2015-auth-module` |
| `test` | Tests | `test/wp-2020-e2e-login` |

### Reglas

1. **Siempre incluir WP ID** — sin WP no hay trazabilidad
2. **Lowercase con guiones** — no underscores, no CamelCase
3. **Descripción corta** — máximo 5 palabras
4. **Un WP por branch** — si son múltiples WPs, usar el padre

## Operaciones

### Crear branch desde main

```bash
# Asegurarse de estar en main actualizado
git checkout main && git pull origin main

# Crear branch
git checkout -b feat/wp-<WP_ID>-<descripcion>
```

### Crear branch y vincular en OP

```bash
# Crear branch
git checkout -b feat/wp-1897-oauth2-provider

# Registrar en OP (via openproject-sync.sh o op-cli.sh)
# El branch se registra al crear el primer commit o PR
```

### Listar branches activas

```bash
# Branches remotas
gh api repos/sentinels-hub/<repo>/branches --jq '.[].name'

# Branches con PR abierto
gh pr list --json headRefName,number,title
```

### Protección de branches

```bash
# Proteger main
gh api repos/sentinels-hub/<repo>/branches/main/protection \
  -X PUT \
  -f required_status_checks='{"strict":true,"contexts":["ci"]}' \
  -f enforce_admins=false \
  -f required_pull_request_reviews='{"required_approving_review_count":1}'
```

### Cleanup de branches mergeadas

```bash
# Ver branches ya mergeadas en main
git branch -r --merged main | grep -v main

# Eliminar branch remota
git push origin --delete feat/wp-1897-oauth2-provider

# Eliminar branches locales mergeadas
git branch --merged main | grep -v main | xargs git branch -d
```

## Validación

Un nombre de branch es válido si:

```regex
^(feat|fix|chore|docs|refactor|test)/wp-[0-9]+-[a-z0-9-]+$
```

Ejemplos válidos:
- `feat/wp-1897-oauth2-provider`
- `fix/wp-1905-contrast-ratio`

Ejemplos inválidos:
- `feature/oauth2` (falta WP ID)
- `feat/WP-1897-OAuth` (debe ser lowercase)
- `feat/1897` (falta tipo y descripción)
