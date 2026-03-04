# Compliance — Controles

## Controles definidos en Lighthouse

Extraídos de `policy.yaml → compliance_controls`:

### ENS Alta

| Control | Descripción | Gate(s) |
|---------|-------------|---------|
| `change_control` | Todo cambio es trazable y aprobado | G2, G3, G5 |
| `traceability` | Cadena completa Contract→WP→Git→Evidence | G0–G9 |
| `least_privilege` | Identidad verificada, mínimo privilegio | G1 |
| `risk_management` | Riesgos identificados y mitigados | G2, G4 |

### ISO 27001

| Control | Descripción | Gate(s) |
|---------|-------------|---------|
| `access_control` | Control de acceso basado en identidad | G1 |
| `secure_change_management` | Cambios con review de seguridad | G4, G5 |
| `incident_learning` | Aprendizaje de incidentes y no conformidades | G6, G9 |

### ISO 9001

| Control | Descripción | Gate(s) |
|---------|-------------|---------|
| `process_standardization` | Procesos estandarizados y repetibles | G0–G9 |
| `evidence_based_decisions` | Decisiones basadas en datos y evidencia | G2, G6 |
| `continuous_improvement` | Mejora continua documentada | G9 |

### SOC 2 Type II

| Control | Descripción | Gate(s) |
|---------|-------------|---------|
| `soc2_cc6` | Control de acceso lógico y físico | G1, G4 |
| `soc2_cc7` | Operaciones del sistema monitoreadas | G6, G7 |
| `soc2_cc8` | Gestión de cambios controlada | G2, G3, G4, G5 |
| `soc2_pi1` | Integridad de procesamiento verificada | G6, G8 |

## Controles derivados (Sentinels-specific)

Controles adicionales que surgen del protocolo de gates:

| Control ID | Control | Descripción | Gate | Agente |
|-----------|---------|-------------|------|--------|
| `SEN-001` | Identity verification | Actor identidad verificada en OP y Git | G1 | @jarvis |
| `SEN-002` | Planning completeness | WP con estimación, scope, AC | G2 | @inception |
| `SEN-003` | Implementation traceability | Branch+commits vinculados a WP | G3 | @gtd |
| `SEN-004` | Security analysis | Scan de vulnerabilidades | G4 | @morpheus |
| `SEN-005` | Code review | Review con scoring 4 capas | G5 | @agent-smith |
| `SEN-006` | QA verification | Tests funcionales + compliance | G6 | @oracle |
| `SEN-007` | Deployment controlled | Deploy con health check | G7 | @pepper |
| `SEN-008` | Evidence integrity | Bundle SHA-256, ledger chain | G8 | @ariadne |
| `SEN-009` | Closure completeness | Todos los gates PASS | G9 | @jarvis |
| `SEN-010` | Hash chain integrity | Ledger append-only sin breaks | G8, G9 | @ariadne, @jarvis |

## Evidencia requerida por control

| Control | Evidencia | Dónde |
|---------|-----------|-------|
| `SEN-001` | Actor mapping, OP `me`, Git config | Contract |
| `SEN-002` | WP con campos completos | OpenProject |
| `SEN-003` | Branch name, commit messages, PR | GitHub + OP |
| `SEN-004` | Security scan report | Bundle artifact |
| `SEN-005` | Review comments, approval | GitHub PR |
| `SEN-006` | Test report, QA checklist | Bundle artifact |
| `SEN-007` | Deployment log, health check | Bundle artifact |
| `SEN-008` | Bundle manifest, ledger entry | Journal |
| `SEN-009` | All gates PASS, governance comments | OP |
| `SEN-010` | Ledger verification report | Journal |
