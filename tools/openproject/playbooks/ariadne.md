# Playbook: @ariadne — Evidence + Release

**Gate**: G8 (Evidence Exported) — co-owner con @jarvis
**Rol**: CHANGELOG, release notes, bundle manifest, ledger.

## Query principal

### Q1: Pendiente de evidence
```json
{
  "name": "@ariadne — Pendiente de evidence",
  "filters": [
    { "field": "status", "operator": "=", "values": ["Deployed"] },
    { "field": "customField:evidence_url", "operator": "!*", "values": [] }
  ],
  "sortBy": [["updatedAt", "asc"]]
}
```

## Flujo G8 — Evidence Exported (con @jarvis)

```
1. Ejecutar Q1 → WPs Deployed sin evidence registrada
2. Para cada WP:
   a. RECOPILAR artefactos:
      - Contract JSON
      - Gate reports (G0-G7)
      - Code review report
      - QA report
      - Deployment evidence

   b. GENERAR:
      - bundle-manifest.json (SHA-256 por artefacto)
      - bundle_sha256 (hash canónico)
      - previous_bundle_sha256 (chain link)
      - CHANGELOG.md entry
      - Release notes

   c. REDACTAR (security):
      - Eliminar API tokens, bearer values
      - Eliminar private keys, secrets
      - Solo artefactos redactados al journal

   d. PUBLICAR:
      - Bundle al journal repo
      - Entry al ledger
      - @jarvis actualiza OP con evidence_url, SHA256, ledger_entry

   e. COMENTARIO governance:
      "[@ariadne@{V}] | contract: {CTR} | gate: G8 | Evidence exported — bundle SHA256: {HASH}..., changelog updated"

   f. REGISTRAR tiempo con actividad "Management"
```

## Campos que @ariadne lee/escribe

| Campo | Lee | Escribe |
|-------|-----|---------|
| Todos los campos de trazabilidad | ✓ | |
| Comentarios de gates previos | ✓ | |
| Gate Current | | ✓ (→ G8) |
| Time entries | | ✓ |

> @jarvis es quien escribe evidence_url, evidence_sha256 y ledger_entry en OP. @ariadne genera el contenido.
