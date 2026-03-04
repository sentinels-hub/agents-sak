# Compliance — Audit Trail

## Concepto

El audit trail es el registro cronológico de todas las acciones de compliance durante el ciclo de vida de un contrato. Complementa el ledger de evidencia con contexto de cumplimiento.

## Estructura

```
<repo>-journal/
  audit/
    CTR-sentinels-hub-20260302/
      audit-trail.jsonl          ← una entrada por acción
```

## Formato de entrada

```json
{
  "timestamp": "2026-03-10T14:30:00Z",
  "contract_id": "CTR-sentinels-hub-20260302",
  "gate": "G5",
  "agent": "@agent-smith",
  "action": "control_verified",
  "controls": ["change_control", "secure_change_management", "SEN-005"],
  "evidence_ref": "PR #42 — review approved",
  "result": "PASS",
  "notes": "4-layer scoring: security 9/10, quality 8/10, design 9/10, docs 7/10"
}
```

## Campos

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `timestamp` | string | Sí | ISO 8601 |
| `contract_id` | string | Sí | Contract ID |
| `gate` | string | Sí | Gate (G0-G9) |
| `agent` | string | Sí | Agente que ejecuta |
| `action` | string | Sí | Tipo de acción |
| `controls` | array | Sí | Controles verificados |
| `evidence_ref` | string | Sí | Referencia a la evidencia |
| `result` | string | Sí | PASS, FAIL, PARTIAL, N/A |
| `notes` | string | No | Notas adicionales |

## Acciones válidas

| Acción | Descripción |
|--------|-------------|
| `control_verified` | Control verificado con evidencia |
| `control_failed` | Control no satisfecho |
| `non_conformity` | No conformidad detectada |
| `corrective_action` | Acción correctiva aplicada |
| `risk_accepted` | Riesgo aceptado (con justificación) |
| `audit_completed` | Auditoría de release completada |

## Generación automática

Cada agente al completar su gate genera entradas de audit trail:

```
@jarvis (G0) → control_verified: traceability, process_standardization
@jarvis (G1) → control_verified: access_control, least_privilege, SEN-001
@inception (G2) → control_verified: change_control, risk_management, SEN-002
@gtd (G3) → control_verified: change_control, traceability, SEN-003
@morpheus (G4) → control_verified: secure_change_management, SEN-004
@agent-smith (G5) → control_verified: change_control, SEN-005
@oracle (G6) → control_verified: evidence_based_decisions, SEN-006
@pepper (G7) → control_verified: process_standardization, SEN-007
@ariadne (G8) → control_verified: traceability, SEN-008, SEN-010
@jarvis (G9) → audit_completed: all controls verified
```

## Verificación de completitud

Al cerrar un contrato (G9), verificar que:

1. Todos los gates tienen al menos una entrada `control_verified`
2. No hay entradas `control_failed` sin `corrective_action` posterior
3. Todos los controles del framework aparecen al menos una vez como `PASS`
4. Las `non_conformity` tienen resolución documentada
