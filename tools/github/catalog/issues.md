# GitHub — Issues

## Rol de Issues en Sentinels

Los Issues de GitHub **no son el sistema principal de tracking** — ese rol lo tiene OpenProject. Los Issues se usan para:

1. **Feedback externo** — reportes de bugs de usuarios
2. **Discusión técnica** — debates que no encajan en OP
3. **Tracking público** — para repos open-source
4. **Escalaciones** — cuando un agente necesita intervención humana

## Convenciones

### Título

```
[WP#<ID>] Descripción corta
```

O sin WP si es feedback externo:
```
Bug: descripción del problema
```

### Labels

Usar los mismos labels de governance que en PRs:

| Label | Uso |
|-------|-----|
| `bug` | Error reportado |
| `enhancement` | Mejora solicitada |
| `question` | Pregunta / discusión |
| `gate:G*` | Vinculado a un gate |
| `agent:*` | Asignado a un agente |
| `human-required` | Necesita intervención humana |
| `blocked` | Bloqueado por dependencia |

### Milestones

Los milestones mapean a versions de OpenProject:

```bash
# Crear milestone
gh api repos/sentinels-hub/<repo>/milestones \
  -X POST \
  -f title="v0.1.0" \
  -f due_on="2026-03-14T00:00:00Z" \
  -f description="Primera versión funcional"
```

## Operaciones

### Crear issue vinculado a WP

```bash
gh issue create \
  --title "[WP#1897] OAuth2 implementation blocked" \
  --body "Bloqueado por falta de credenciales OAuth. Necesita config admin." \
  --label "blocked,human-required,gate:G3" \
  --assignee "@me"
```

### Listar issues

```bash
# Todos abiertos
gh issue list --repo sentinels-hub/<repo>

# Por label
gh issue list --repo sentinels-hub/<repo> --label "human-required"

# Por milestone
gh issue list --repo sentinels-hub/<repo> --milestone "v0.1.0"
```

### Cerrar issue con referencia

```bash
gh issue close <NUMBER> --comment "Resuelto en PR #42 [WP#1897]"
```

## Issue → WP sync

Si un issue externo genera trabajo, crear WP en OP y vincular:

```bash
# 1. Crear WP en OP
openproject-sync.sh create-task <PROJECT> "Fix from issue #<N>" "Descripción"

# 2. Comentar en el issue con referencia
gh issue comment <N> --body "Tracked in OpenProject WP#<WP_ID>"
```
