# GitHub — Commits

## Formato de commit message

Definido en `policy.yaml` como `commit_format`:

```
type(scope): description [WP#ID]
```

### Estructura

```
<type>(<scope>): <description> [WP#<id>]

<body opcional>

<footer opcional>
```

### Types

| Type | Uso | Ejemplo |
|------|-----|---------|
| `feat` | Nueva funcionalidad | `feat(auth): add OAuth2 login [WP#1897]` |
| `fix` | Corrección de bug | `fix(hud): correct button alignment [WP#1899]` |
| `chore` | Mantenimiento | `chore(deps): update dependencies [WP#2001]` |
| `docs` | Documentación | `docs(api): add endpoint reference [WP#2010]` |
| `build` | Build system | `build(ci): add test workflow [WP#2015]` |
| `refactor` | Refactoring | `refactor(auth): extract token service [WP#1897]` |
| `test` | Tests | `test(auth): add OAuth2 e2e tests [WP#1897]` |

### Scope

El scope es el módulo o componente afectado:
- `auth`, `hud`, `api`, `db`, `ui`, `ci`, `deps`, `config`
- Puede omitirse si el cambio es transversal: `chore: update license headers [WP#2001]`

### WP Tag

- **Obligatorio**: `[WP#<numeric-id>]`
- Alternativa: `[<PROJECT-CODE>-<id>]`
- Siempre al final de la primera línea

## Validación

```regex
^(feat|fix|chore|docs|build|refactor|test)(\([a-z0-9-]+\))?: .+ \[WP#[0-9]+\]$
```

## Body (opcional)

```
feat(auth): implement OAuth2 provider [WP#1897]

Adds OAuth2 authentication using the authorization code flow.
Includes token refresh, session management, and PKCE support.

- Added OAuthProvider class
- Added token storage with encryption
- Added session middleware

Contract: CTR-sentinels-hub-20260302
Gate: G3
```

## Operaciones

### Crear commit vinculado

```bash
git add .
git commit -m "feat(auth): implement OAuth2 provider [WP#1897]"
```

### Commit con body

```bash
git commit -m "feat(auth): implement OAuth2 provider [WP#1897]" \
  -m "Adds OAuth2 using authorization code flow with PKCE." \
  -m "Contract: CTR-sentinels-hub-20260302"
```

### Verificar formato de commits en un branch

```bash
# Listar commits del branch actual vs main
git log main..HEAD --oneline

# Verificar que todos tienen WP tag
git log main..HEAD --format="%s" | grep -v '\[WP#[0-9]\+\]' && echo "FAIL: commits sin WP tag" || echo "OK"
```

### Vincular commit en OP

```bash
# Obtener URL del último commit
COMMIT_URL="https://github.com/sentinels-hub/<repo>/commit/$(git rev-parse HEAD)"

# Registrar en OP
openproject-sync.sh set-github-commit <WP_ID> "$COMMIT_URL"
```

## Multi-WP commits

Si un commit afecta múltiples WPs (raro, evitar si posible):

```
feat(auth): implement shared auth module [WP#1897][WP#1899]
```

Preferir: un commit por WP, o usar el WP padre si es un cambio transversal.

## Co-Authored-By

Cuando un agente trabaja con un humano o con otro agente:

```
feat(auth): implement OAuth2 provider [WP#1897]

Co-Authored-By: @gtd <noreply@sentinels.dev>
Co-Authored-By: Jorge Cajiao <jorge@sentinels.dev>
```
