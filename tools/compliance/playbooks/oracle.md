# Playbook: @oracle — G6 QA Compliance Check

## Contexto

Al completar QA (G6), @oracle registra los controles de calidad y compliance verificados durante testing. Esto incluye `evidence_based_decisions`, `incident_learning` y `SEN-006`.

## Variables de entrada

| Variable | Ejemplo |
|----------|---------|
| `CONTRACT_ID` | `CTR-sentinels-hub-20260302` |
| `JOURNAL_PATH` | `~/GitHub/sentinels-hub/sentinels-agents-journal` |

---

## Paso 1 — Verificar estado actual

```bash
co-cli.sh audit list --contract $CONTRACT_ID --journal-path $JOURNAL_PATH
co-cli.sh control check --contract $CONTRACT_ID --journal-path $JOURNAL_PATH
```

**Esperar**: Entries de gates anteriores (G0-G5) y score parcial.

## Paso 2 — Registrar controles G6

Si QA pasa:

```bash
co-cli.sh audit append --contract $CONTRACT_ID --gate G6 --agent @oracle \
  --action control_verified \
  --controls evidence_based_decisions,incident_learning,SEN-006 \
  --evidence-ref "QA test report — all tests passed" \
  --result PASS \
  --journal-path $JOURNAL_PATH
```

Si QA falla:

```bash
co-cli.sh audit append --contract $CONTRACT_ID --gate G6 --agent @oracle \
  --action control_failed \
  --controls SEN-006 \
  --evidence-ref "QA test report — failures detected" \
  --result FAIL \
  --notes "Tests fallidos: [detallar tests]" \
  --journal-path $JOURNAL_PATH
```

## Paso 3 — Registrar non-conformities si aplica

Si se detectan no-conformidades durante QA:

```bash
co-cli.sh audit append --contract $CONTRACT_ID --gate G6 --agent @oracle \
  --action non_conformity \
  --controls SEN-006 \
  --evidence-ref "QA report — non-conformity detected" \
  --result FAIL \
  --notes "NC: [descripción de la no-conformidad]" \
  --journal-path $JOURNAL_PATH
```

Tras corrección:

```bash
co-cli.sh audit append --contract $CONTRACT_ID --gate G6 --agent @oracle \
  --action corrective_action \
  --controls SEN-006 \
  --evidence-ref "Fix applied and re-tested" \
  --result PASS \
  --journal-path $JOURNAL_PATH
```

## Paso 4 — Verificar score parcial

```bash
co-cli.sh control check --contract $CONTRACT_ID --journal-path $JOURNAL_PATH
```

**Esperar**: Coverage actualizada con controles G6 incluidos.

## Paso 5 — Push journal repo

```bash
cd $JOURNAL_PATH
git add -A
git commit -m "compliance: G6 QA compliance check for $CONTRACT_ID"
git push origin main
```

---

## Checklist final

- [ ] Controles G6 registrados (PASS o FAIL)
- [ ] Non-conformities documentadas (si aplica)
- [ ] Corrective actions registradas (si aplica)
- [ ] Score parcial verificado
- [ ] Journal repo pushed
