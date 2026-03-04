# Playbook: @pepper — Deployment

**Gate**: G7 (Deployment Verified)
**Rol**: Build, deploy, health checks, rollback ready.
**Skip**: docs-only, library-only-no-service

## Query principal

### Q1: Pendiente de deploy
```json
{
  "name": "@pepper — Pendiente de deploy",
  "filters": [
    { "field": "status", "operator": "=", "values": ["Verification"] },
    { "field": "type", "operator": "=", "values": ["User story", "Feature"] }
  ],
  "sortBy": [["priority", "desc"]]
}
```

## Flujo G7 — Deployment Verified

```
1. Ejecutar Q1 → WPs post-G6 (QA passed) pendientes de deploy
2. Para cada WP:
   a. VERIFICAR skip conditions:
      - Si Tech Stack es docs-only o library-only → SKIP

   b. LEER contexto:
      - description → deployment_plan (definido por @inception)
      - Tech Stack → pipeline a usar
      - project → environment target

   c. TRANSICIONAR: → "In deployment"

   d. EJECUTAR pipeline:
      - Build: compilar/empaquetar según tech stack
      - Deploy: ejecutar deployment al environment target
      - Health checks: HTTP 2xx, 3 intentos con backoff
      - Rollback ready: verificar que se puede revertir

   e. EVALUAR:
      - Health OK + rollback ready → PASS
      - Health fail → rollback + FAIL

   f. TRANSICIONAR: → "Deployed" (si OK)

   g. COMENTARIO governance:
      "[@pepper@{V}] | contract: {CTR} | gate: G7 | Deployment verified — env: {ENV}, health: HTTP {CODE}, rollback: ready"

   h. REGISTRAR tiempo con actividad "Installation"
```

## Campos que @pepper lee/escribe

| Campo | Lee | Escribe |
|-------|-----|---------|
| description (deployment_plan) | ✓ | |
| Tech Stack | ✓ | |
| status | ✓ | ✓ (→ In deployment → Deployed) |
| Gate Current | | ✓ (→ G7) |
| Time entries | | ✓ |
