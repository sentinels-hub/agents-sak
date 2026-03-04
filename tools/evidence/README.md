# Evidence Tool — Agents SAK

Herramienta para gestionar bundles de evidencia, ledger inmutable y verificación de integridad. Alineada con **Sentinels Protocol v1.0** (Lighthouse).

## Setup rápido

```bash
# Verificar que todo está listo
./scripts/ev-setup.sh --check-only ~/journal

# Inicializar journal nuevo
./scripts/ev-setup.sh --init ~/journal
```

## Qué incluye

### Scripts (`scripts/`)

| Script | Uso |
|--------|-----|
| [ev-core.sh](scripts/ev-core.sh) | Funciones compartidas: hashing, IDs, timestamps, redacción, validación |
| [ev-cli.sh](scripts/ev-cli.sh) | CLI completo: bundle, ledger, redact, verify |
| [ev-setup.sh](scripts/ev-setup.sh) | Setup y verificación del journal repo |

### Catálogo de operaciones (`catalog/`)

| Documento | Descripción |
|-----------|-------------|
| [bundles](catalog/bundles.md) | Crear y verificar bundles con hash canónico |
| [ledger](catalog/ledger.md) | Ledger particionado append-only con hash chain |
| [verification](catalog/verification.md) | Verificación de integridad y cross-check |
| [redaction](catalog/redaction.md) | Redactar información sensible antes de export |

### Playbooks (`playbooks/`)

| Playbook | Agente | Gate |
|----------|--------|------|
| [ariadne](playbooks/ariadne.md) | @ariadne | G8 — Evidence Export |
| [jarvis](playbooks/jarvis.md) | @jarvis | G8/G9 — OP fields + Verification |

### Schemas de validación (`schemas/`)

| Schema | Valida |
|--------|--------|
| [bundle.schema.json](schemas/bundle.schema.json) | Bundle manifest (espejo de Lighthouse) |
| [ledger-entry.schema.json](schemas/ledger-entry.schema.json) | Entrada del ledger (espejo de Lighthouse) |

### Templates (`templates/`)

| Template | Uso |
|----------|-----|
| [bundle-manifest](templates/bundle-manifest.md) | Formato del manifest con hash canónico |
| [release-notes](templates/release-notes.md) | Release notes por versión |

## Flujo de evidencia

```
G8 (@ariadne)
  1. Recopilar artifacts (code, config, logs, reports)
  2. Redactar información sensible
  3. Crear bundle en bundles/<yyyy>/<mm>/<bundle_id>/
  4. Calcular bundle_sha256 con algoritmo canónico de Lighthouse
  5. Obtener previous_bundle_sha256 del último ledger entry
  6. Registrar en ledger particionado (ledger/<yyyy>/<mm>/entries.jsonl)
  7. Verificar integridad (bundle + chain)
  8. Push al journal repo

G8 (@jarvis co-owner)
  9. Escribir en OP: evidence_url, evidence_sha256, ledger_entry

G9 (@jarvis)
  10. Verificación completa: bundle + ledger + cross-check OP
  11. Cerrar contrato
```

## Estructura del journal

```
journal-repo/
  bundles/
    2026/
      03/
        bundle-20260301T042233Z-ctr-xxx/
          bundle-manifest.json
          contract.json
          git-metadata.json
          ...
  ledger/
    2026/
      03/
        entries.jsonl
```

## Requisitos

- `sha256sum` o `shasum` — Para cálculo de hashes
- `jq` — Para parsing JSON
- `python3` — Para hash canónico y redacción
- `git` — Para el journal repo
- Acceso al repo journal correspondiente

## Referencia — Protocolo Lighthouse

Los schemas y algoritmos de esta tool son espejos de:

- `sentinels-lighthouse/policy/sentinels-protocol/v1/evidence-bundle.schema.json`
- `sentinels-lighthouse/policy/sentinels-protocol/v1/ledger-entry.schema.json`
- `sentinels-lighthouse/scripts/verify-evidence-chain.sh`
- `sentinels-lighthouse/docs/JOURNAL_STANDARD.md`
