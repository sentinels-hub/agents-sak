# Compliance — Mapping Gate → Control → Evidencia

## Matriz completa

| Gate | Agente | Controles satisfechos | Evidencia generada |
|------|--------|----------------------|-------------------|
| **G0** | @jarvis | `traceability`, `process_standardization` | Contract JSON, WP creado en OP |
| **G1** | @jarvis | `access_control`, `least_privilege`, `SEN-001` | Actor mapping, identity cross-check |
| **G2** | @inception | `change_control`, `risk_management`, `evidence_based_decisions`, `SEN-002` | WP con plan, estimación, risk summary |
| **G3** | @gtd | `change_control`, `traceability`, `SEN-003` | Branch, commits [WP#], PR |
| **G4** | @morpheus | `secure_change_management`, `risk_management`, `SEN-004` | Security scan report |
| **G5** | @agent-smith | `change_control`, `secure_change_management`, `SEN-005` | Code review (approve/reject) |
| **G6** | @oracle | `evidence_based_decisions`, `incident_learning`, `SEN-006` | Test report, QA checklist |
| **G7** | @pepper | `process_standardization`, `SEN-007` | Deploy log, health check |
| **G8** | @ariadne | `traceability`, `SEN-008`, `SEN-010` | Bundle manifest, ledger entry |
| **G9** | @jarvis | `continuous_improvement`, `SEN-009` | Closure report, all gates PASS |

## Por framework

### ENS Alta

```
change_control     ← G2 (plan), G3 (impl), G5 (review)
traceability       ← G0-G9 (cadena completa)
least_privilege    ← G1 (identity)
risk_management    ← G2 (planning), G4 (security)
```

### ISO 27001

```
access_control              ← G1 (identity verification)
secure_change_management    ← G4 (security scan), G5 (code review)
incident_learning           ← G6 (QA), G9 (closure with learnings)
```

### ISO 9001

```
process_standardization     ← G0-G9 (protocolo estandarizado)
evidence_based_decisions    ← G2 (data-driven planning), G6 (test evidence)
continuous_improvement      ← G9 (closure review, learnings)
```

### SOC 2

```
CC6 Logical Access     ← G1 (identity), G4 (security)
CC7 System Operations  ← G7 (deployment), G6 (monitoring)
CC8 Change Management  ← G2-G5 (plan→implement→review→approve)
PI1 Processing Integrity ← G6 (QA), G8 (evidence integrity)
```

## Cómo usar esta matriz

Un agente en el gate G5 (@agent-smith):

1. Consulta esta tabla → G5 satisface `change_control`, `secure_change_management`, `SEN-005`
2. Verifica que la evidencia existe: code review con scoring
3. Genera governance comment referenciando los controles
4. El control queda cubierto para el release

Al cerrar (G9), @jarvis verifica que todos los controles de la matriz están cubiertos por la evidencia acumulada.
