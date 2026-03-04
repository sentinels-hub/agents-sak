# Evidence — Verificación

## Niveles de verificación

### 1. Bundle integrity

Verificar que cada artifact en el manifest coincide con su hash declarado.

```bash
ev-cli.sh bundle verify bundles/2026/03/bundle-xxx/bundle-manifest.json
```

Checks:
- Cada artifact referenciado existe
- SHA-256 de cada archivo coincide con el declarado
- `bundle_sha256` coincide con el hash canónico (artifact index)
- `size_bytes` coincide con el tamaño real
- Detección automática de formato: `bundle-*` (canónico) vs `BDL-*` (legacy)

### 2. Ledger chain integrity

Verificar que la cadena de hashes del ledger no está rota.

```bash
ev-cli.sh ledger verify --journal-path ~/journal
```

Checks:
- `previous_bundle_sha256` de entry N == `bundle_sha256` de entry N-1
- Primera entrada tiene `previous_bundle_sha256: null`
- No hay entradas con `entry_id` duplicado
- Todas las entradas tienen campos requeridos válidos
- Verificación across all partitions (`ledger/<yyyy>/<mm>/entries.jsonl`)

### 3. Cross-check híbrido

Verificación local + checklist manual para APIs externas.

```bash
ev-cli.sh verify cross-check --journal-path ~/journal --manifest path/bundle-manifest.json
```

**Checks automáticos:**
- Bundle integrity (si se proporciona `--manifest`)
- Ledger chain integrity (si se proporciona `--journal-path`)

**Checklist manual:**
- `evidence_url` en OP apunta a un bundle que existe
- `evidence_sha256` en OP coincide con `bundle_sha256` del manifest
- `ledger_entry` en OP corresponde a una entrada válida del ledger
- GitHub PR referenciado existe y está merged
- Git commits referenciados existen en el repo

### 4. Full chain verification

Verificación completa de toda la cadena para un contrato:

```
Contract → WP (OP) → Branch (Git) → Commits → PR → Evidence Bundle → Ledger
```

## Hash canónico vs legacy

| Aspecto | Canónico (`bundle-*`) | Legacy (`BDL-*`) |
|---------|----------------------|------------------|
| Algoritmo | Artifact index sorted | Hash del manifest completo |
| Material | `path:sha256:size_bytes\nprevious:<hash>` | manifest JSON con `bundle_sha256: ""` |
| Reproducible | Sí (independiente del formato JSON) | Depende de formato JSON exacto |
| Compatible con Lighthouse | Sí | No (pero se mantiene para bundles históricos) |

## Resultado de verificación

```
=== Bundle Verification ===
Manifest: bundles/2026/03/bundle-xxx/bundle-manifest.json

  [OK] bundle_sha256 (canonical)
  [OK] 5/5 artifacts verified

Status: PASS
```

```
=== Ledger Verification ===
Journal: ~/journal

  Entries: 17
  Chain: UNBROKEN

Status: PASS
```

## Qué hacer si la verificación falla

| Fallo | Causa | Acción |
|-------|-------|--------|
| Artifact hash mismatch | Archivo fue modificado después de crear el bundle | Recrear bundle con artifacts correctos |
| bundle_sha256 mismatch | Manifest fue editado o algoritmo incorrecto | Regenerar manifest desde artifacts |
| Chain break | Ledger entry apunta a hash incorrecto | **No se puede reparar** — registrar como non-conformity |
| Duplicate entry_id | Entry ID repetido en el ledger | Investigar causa, registrar non-conformity |
| OP cross-ref fail | Datos en OP desactualizados | Actualizar campos en OP |

**IMPORTANTE**: Un chain break en el ledger es una non-conformity grave. No se puede reparar sin romper la inmutabilidad. Debe documentarse y reportarse.
