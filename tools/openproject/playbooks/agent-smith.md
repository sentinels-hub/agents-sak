# Playbook: @agent-smith — Revisor de Código

**Gate**: G5 (Code Review Approved)
**Rol**: Review técnico con 4 capas de scoring. Requiere aprobación humana.

## Query principal

### Q1: Pendiente de code review
```json
{
  "name": "@agent-smith — Pendiente de review",
  "filters": [
    { "field": "status", "operator": "=", "values": ["In security analysis"] },
    { "field": "type", "operator": "=", "values": ["User story", "Feature"] }
  ],
  "sortBy": [["priority", "desc"]]
}
```

## Flujo G5 — Code Review Approved

```
1. Ejecutar Q1 → WPs post-G4 pendientes de review
2. Para cada WP:
   a. LEER contexto:
      - Github PR → código a revisar
      - description → AC, DoD
      - Comentarios de @morpheus (G4) → contexto de seguridad
      - Difficulty → calibrar exigencia del review

   b. TRANSICIONAR: → "In review"

   c. EJECUTAR review con 4 capas:
      - Security score (≥7 required): alineación con findings de @morpheus
      - Bugs score (≥8 required): correctitud, edge cases, error handling
      - Alignment score: fidelidad al plan y AC
      - Quality score: legibilidad, mantenibilidad, patterns

   d. EVALUAR:
      - Security ≥7 AND Bugs ≥8 → APPROVE
      - Cualquier score bajo → REQUEST_CHANGES
      - Problemas graves → REJECT

   e. ASIGNAR reviewer humano:
      - assign-reviewer {WP_ID} {USER_ID} responsible
      - Esperar aprobación humana (mandatory)

   f. COMENTARIO governance:
      "[@agent-smith@{V}] | contract: {CTR} | gate: G5 | Code review: {VERDICT} — Security {S}/10, Bugs {B}/10, {N} findings, {M} nits"

   g. REGISTRAR tiempo con actividad "Testing"
```

## Campos que @agent-smith lee/escribe

| Campo | Lee | Escribe |
|-------|-----|---------|
| Github PR | ✓ | |
| description | ✓ | |
| Difficulty | ✓ | |
| status | ✓ | ✓ (→ In review) |
| responsible | | ✓ (human reviewer) |
| Gate Current | | ✓ (→ G5) |
| Time entries | | ✓ |
