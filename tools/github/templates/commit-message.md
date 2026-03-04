# Commit Message Template

## Formato

```
type(scope): description [WP#ID]

Body opcional: explicación detallada del cambio.

Contract: CTR-xxx
Gate: Gn
Co-Authored-By: @agent <noreply@sentinels.dev>
```

## Tipos disponibles

| Type | Cuándo usar |
|------|------------|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `chore` | Mantenimiento, limpieza |
| `docs` | Solo documentación |
| `build` | Build system, CI/CD |
| `refactor` | Refactoring sin cambio funcional |
| `test` | Solo tests |

## Reglas

1. Primera línea: máximo 120 caracteres
2. Scope: módulo afectado en lowercase
3. Siempre incluir `[WP#ID]` al final
4. Body separado por línea en blanco
5. Un commit = un cambio lógico

## Ejemplo completo

```
feat(auth): implement OAuth2 authorization code flow [WP#1897]

Adds complete OAuth2 implementation with PKCE support.
Includes token refresh logic and secure session management.

- OAuthProvider class with configurable providers
- Token storage with AES-256 encryption
- Session middleware with CSRF protection

Contract: CTR-sentinels-hub-20260302
Gate: G3
Co-Authored-By: @gtd <noreply@sentinels.dev>
```
