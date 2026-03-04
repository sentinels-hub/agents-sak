# Playbook: @jarvis — G9 Compliance Audit

## Contexto

Al cerrar un contrato (G9), @jarvis ejecuta una auditoría completa de compliance verificando que todos los controles están cubiertos, no hay no-conformidades sin resolver, y genera el reporte final.

## Variables de entrada

| Variable | Ejemplo |
|----------|---------|
| `CONTRACT_ID` | `CTR-sentinels-hub-20260302` |
| `JOURNAL_PATH` | `~/GitHub/sentinels-hub/sentinels-agents-journal` |
| `REPO` | `sentinels-hub` |

---

## Paso 1 — Verificar estado del audit trail

```bash
co-cli.sh audit list --contract $CONTRACT_ID --journal-path $JOURNAL_PATH
co-cli.sh audit verify --contract $CONTRACT_ID --journal-path $JOURNAL_PATH
```

**Esperar**: Lista de entries, 4 checks del verify.
**Si FAIL**: Identificar gates o controles faltantes antes de continuar.

## Paso 2 — Verificar controles por framework

```bash
co-cli.sh control check --contract $CONTRACT_ID --journal-path $JOURNAL_PATH
```

**Esperar**: Tabla con score por framework (ens_alto, iso_27001, iso_9001, sentinels).
**Si coverage < 100%**: Revisar controles pendientes y coordinar con agentes responsables.

## Paso 3 — Verificar no-conformidades

```bash
co-cli.sh verify non-conformities --contract $CONTRACT_ID --journal-path $JOURNAL_PATH
```

**Esperar**: Status PASS (todas resueltas) o listado de NCs abiertas.
**Si FAIL**: Registrar corrective_action o risk_accepted para cada NC abierta.

## Paso 4 — Generar audit report

```bash
co-cli.sh report audit --contract $CONTRACT_ID --journal-path $JOURNAL_PATH \
  --repo $REPO --agent @jarvis \
  --output $JOURNAL_PATH/audit/$CONTRACT_ID/audit-report.md
```

**Esperar**: Archivo audit-report.md generado con scores y estado de gates.

## Paso 5 — Registrar audit_completed

```bash
co-cli.sh audit append --contract $CONTRACT_ID --gate G9 --agent @jarvis \
  --action audit_completed \
  --controls continuous_improvement,SEN-009 \
  --evidence-ref "Audit report generated, all controls verified" \
  --result PASS \
  --journal-path $JOURNAL_PATH
```

**Nota**: Solo si todos los pasos anteriores resultaron satisfactorios.
Si hay NCs no resueltas, usar `--result PARTIAL` y documentar en `--notes`.

## Paso 6 — Escribir resultado en OpenProject

```bash
op-cli.sh wp update $WP_ID \
  --field compliance_status --value "APPROVED" \
  --field compliance_date --value "$(date -u +%Y-%m-%d)" \
  --field compliance_report --value "$JOURNAL_PATH/audit/$CONTRACT_ID/audit-report.md"
```

**Nota**: Requiere acceso a OpenProject API. Adaptar campos según configuración del WP.

## Paso 7 — Push journal repo

```bash
cd $JOURNAL_PATH
git add -A
git commit -m "compliance: G9 audit completed for $CONTRACT_ID"
git push origin main
```

---

## Checklist final

- [ ] Audit trail verify: PASS
- [ ] Control check: 100% coverage
- [ ] Non-conformities: todas resueltas
- [ ] Audit report generado
- [ ] Entry `audit_completed` registrada
- [ ] OpenProject actualizado
- [ ] Journal repo pushed
