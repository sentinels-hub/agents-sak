# Control Checklist — Release Compliance

## Contract: `{CONTRACT_ID}`
## Date: `{DATE}`
## Auditor: `{AGENT}`

---

## ENS Alta

| # | Control | Gate(s) | Evidence | Result |
|---|---------|---------|----------|--------|
| 1 | `change_control` — Todo cambio trazable y aprobado | G2, G3, G5 | | [ ] PASS / [ ] FAIL |
| 2 | `traceability` — Cadena Contract→WP→Git→Evidence | G0–G9 | | [ ] PASS / [ ] FAIL |
| 3 | `least_privilege` — Identidad verificada, mínimo privilegio | G1 | | [ ] PASS / [ ] FAIL |
| 4 | `risk_management` — Riesgos identificados y mitigados | G2, G4 | | [ ] PASS / [ ] FAIL |

## ISO 27001

| # | Control | Gate(s) | Evidence | Result |
|---|---------|---------|----------|--------|
| 5 | `access_control` — Control de acceso basado en identidad | G1 | | [ ] PASS / [ ] FAIL |
| 6 | `secure_change_management` — Cambios con review de seguridad | G4, G5 | | [ ] PASS / [ ] FAIL |
| 7 | `incident_learning` — Aprendizaje de incidentes | G6, G9 | | [ ] PASS / [ ] FAIL |

## ISO 9001

| # | Control | Gate(s) | Evidence | Result |
|---|---------|---------|----------|--------|
| 8 | `process_standardization` — Procesos estandarizados | G0–G9 | | [ ] PASS / [ ] FAIL |
| 9 | `evidence_based_decisions` — Decisiones basadas en datos | G2, G6 | | [ ] PASS / [ ] FAIL |
| 10 | `continuous_improvement` — Mejora continua documentada | G9 | | [ ] PASS / [ ] FAIL |

## SOC 2 Type II

| # | Control | Gate(s) | Evidence | Result |
|---|---------|---------|----------|--------|
| 11 | `soc2_cc6` — Control de acceso lógico y físico | G1, G4 | | [ ] PASS / [ ] FAIL |
| 12 | `soc2_cc7` — Operaciones del sistema monitoreadas | G6, G7 | | [ ] PASS / [ ] FAIL |
| 13 | `soc2_cc8` — Gestión de cambios controlada | G2, G3, G4, G5 | | [ ] PASS / [ ] FAIL |
| 14 | `soc2_pi1` — Integridad de procesamiento verificada | G6, G8 | | [ ] PASS / [ ] FAIL |

## Sentinels-specific

| # | Control ID | Control | Gate | Agent | Evidence | Result |
|---|-----------|---------|------|-------|----------|--------|
| 15 | `SEN-001` | Identity verification | G1 | @jarvis | | [ ] PASS / [ ] FAIL |
| 16 | `SEN-002` | Planning completeness | G2 | @inception | | [ ] PASS / [ ] FAIL |
| 17 | `SEN-003` | Implementation traceability | G3 | @gtd | | [ ] PASS / [ ] FAIL |
| 18 | `SEN-004` | Security analysis | G4 | @morpheus | | [ ] PASS / [ ] FAIL |
| 19 | `SEN-005` | Code review | G5 | @agent-smith | | [ ] PASS / [ ] FAIL |
| 20 | `SEN-006` | QA verification | G6 | @oracle | | [ ] PASS / [ ] FAIL |
| 21 | `SEN-007` | Deployment controlled | G7 | @pepper | | [ ] PASS / [ ] FAIL |
| 22 | `SEN-008` | Evidence integrity | G8 | @ariadne | | [ ] PASS / [ ] FAIL |
| 23 | `SEN-009` | Closure completeness | G9 | @jarvis | | [ ] PASS / [ ] FAIL |
| 24 | `SEN-010` | Hash chain integrity | G8, G9 | @ariadne, @jarvis | | [ ] PASS / [ ] FAIL |

---

## Summary

| Metric | Value |
|--------|-------|
| Total controls | 24 |
| PASS | |
| FAIL | |
| Coverage | % |

## Non-conformities

| # | Control | Issue | Corrective Action | Status |
|---|---------|-------|--------------------|--------|
| | | | | |

## Sign-off

- [ ] All controls verified
- [ ] No unresolved FAIL results
- [ ] Evidence chain complete (ledger verified)
- [ ] Audit trail entries generated

**Auditor**: _______________  **Date**: _______________
