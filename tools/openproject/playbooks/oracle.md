# Playbook: @oracle — QA + Compliance

**Gate**: G6 (Verification Passed)
**Rol**: Verificación funcional + auditoría de compliance contra frameworks.

## Query principal

### Q1: Pendiente de verificación
```json
{
  "name": "@oracle — Pendiente de QA",
  "filters": [
    { "field": "status", "operator": "=", "values": ["In review"] },
    { "field": "type", "operator": "=", "values": ["User story", "Feature"] }
  ],
  "sortBy": [["priority", "desc"]]
}
```

### Q2: Test failures
```json
{
  "name": "@oracle — Test failures",
  "filters": [
    { "field": "status", "operator": "=", "values": ["Test failed"] }
  ],
  "sortBy": [["updatedAt", "desc"]]
}
```

## Flujo G6 — Verification Passed

```
1. Ejecutar Q1 → WPs post-G5 (review approved) pendientes de QA
2. Para cada WP:
   a. LEER contexto:
      - description → AC, DoD, tests definidos
      - Comentarios de @agent-smith (G5) → findings del review
      - Compliance Scope del proyecto → frameworks aplicables

   b. TRANSICIONAR: → "Verification"

   c. EJECUTAR verificación funcional:
      - Test matrix: test por cada AC
      - Expected vs. Actual para cada test
      - Screenshot/evidence cuando aplique

   d. EJECUTAR auditoría de compliance:
      - ISO 27001: access control, secure change mgmt
      - ISO 9001: process standardization, evidence-based
      - ISO 42001: AI governance (si aplica)
      - SOC 2: security controls
      - ENS Alta: change control, traceability

   e. EVALUAR:
      - 100% tests pass + compliance OK → PASS
      - Tests pass con non-blocking issues → PASS_WITH_WARNINGS
      - Tests fail → FAIL → "Test failed"

   f. COMENTARIO governance:
      "[@oracle@{V}] | contract: {CTR} | gate: G6 | QA {VERDICT} — {P}/{T} tests, {AC} AC verified, compliance: {FRAMEWORKS}"

   g. REGISTRAR tiempo con actividad "Testing"
```

## Campos que @oracle lee/escribe

| Campo | Lee | Escribe |
|-------|-----|---------|
| description (AC, DoD) | ✓ | |
| project.compliance_scope | ✓ | |
| status | ✓ | ✓ (→ Verification / Test failed) |
| Gate Current | | ✓ (→ G6) |
| Time entries | | ✓ |
