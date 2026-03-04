# Compliance Tool — Agents SAK

Herramienta para mapear frameworks de compliance contra el protocolo de gates Sentinels y generar evidencia de cumplimiento.

## Qué incluye

### Catálogo (`catalog/`)

| Documento | Descripción |
|-----------|-------------|
| [frameworks](catalog/frameworks.md) | Frameworks soportados: ISO 27001, ISO 9001, SOC2, ENS Alta |
| [controls](catalog/controls.md) | Controles por framework con mapeo a gates |
| [mapping](catalog/mapping.md) | Matriz gate → control → evidencia requerida |
| [audit-trail](catalog/audit-trail.md) | Cómo generar y mantener audit trails |

### Schemas (`schemas/`)

| Schema | Valida |
|--------|--------|
| [control.schema.json](schemas/control.schema.json) | Definición de un control |
| [audit-entry.schema.json](schemas/audit-entry.schema.json) | Entrada de audit trail |

### Templates (`templates/`)

| Template | Uso |
|----------|-----|
| [control-checklist](templates/control-checklist.md) | Checklist de controles por release |
| [audit-report](templates/audit-report.md) | Reporte de auditoría |

### Scripts (`scripts/`)

| Script | Descripción |
|--------|-------------|
| [co-cli.sh](scripts/co-cli.sh) | CLI principal — audit, control, report, verify |
| [co-setup.sh](scripts/co-setup.sh) | Setup y verificación del journal |
| [co-core.sh](scripts/co-core.sh) | Funciones compartidas (source-only) |

### Playbooks (`playbooks/`)

| Playbook | Agente | Gate | Descripción |
|----------|--------|------|-------------|
| [jarvis.md](playbooks/jarvis.md) | @jarvis | G9 | Compliance Audit completa |
| [oracle.md](playbooks/oracle.md) | @oracle | G6 | QA Compliance Check |

## Cómo funciona

```
1. Agente completa un gate (e.g., G5 Code Review)
2. Consulta mapping: G5 → qué controles satisface
3. Verifica que la evidencia requerida existe
4. Genera entrada en audit trail (co-cli.sh audit append)
5. Al cerrar (G9), genera reporte de compliance (co-cli.sh report audit)
```

## CLI — Uso rápido

```bash
# Setup — verificar journal
co-setup.sh --check-only ~/journal

# Controles — listar y consultar
co-cli.sh control list
co-cli.sh control list --framework sentinels
co-cli.sh control get SEN-001

# Audit trail — registrar y consultar
co-cli.sh audit append --contract CTR-xxx-20260304 --gate G5 --agent @agent-smith \
  --action control_verified --controls change_control,SEN-005 \
  --evidence-ref "PR #42 approved" --result PASS --journal-path ~/journal

co-cli.sh audit list --contract CTR-xxx-20260304 --journal-path ~/journal
co-cli.sh audit verify --contract CTR-xxx-20260304 --journal-path ~/journal

# Score y verificación
co-cli.sh control check --contract CTR-xxx-20260304 --journal-path ~/journal
co-cli.sh verify completeness --contract CTR-xxx-20260304 --journal-path ~/journal
co-cli.sh verify non-conformities --contract CTR-xxx-20260304 --journal-path ~/journal

# Reportes
co-cli.sh report checklist --contract CTR-xxx-20260304 --journal-path ~/journal
co-cli.sh report audit --contract CTR-xxx-20260304 --journal-path ~/journal
```

## Frameworks soportados

| Framework | Alcance | Retención |
|-----------|---------|-----------|
| ISO 27001 | Seguridad de la información | 6-7 años |
| ISO 9001 | Gestión de calidad | 6-7 años |
| SOC 2 Type II | Controles de servicio | 6-7 años |
| ENS Alta | Esquema Nacional de Seguridad (España) | 6-7 años |

## Alineación con Lighthouse

Los controles están definidos en `policy.yaml → compliance_controls`:
- `ens_alto`: change_control, traceability, least_privilege, risk_management
- `iso_27001`: access_control, secure_change_management, incident_learning
- `iso_9001`: process_standardization, evidence_based_decisions, continuous_improvement
