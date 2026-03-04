# Evidence — Ledger

## Concepto

El **ledger** es un registro inmutable (append-only) de todos los bundles de evidencia. Funciona como una cadena de bloques simplificada:

```
Entry 0                    Entry 1                    Entry 2
  bundle_sha256: aaa  ←──  previous: aaa              previous: bbb
                           bundle_sha256: bbb  ←────  bundle_sha256: ccc
```

Si `previous_bundle_sha256` de la Entry N no coincide con `bundle_sha256` de la Entry N-1, la cadena está rota → G9 (Closure) falla.

## Estructura (particionado mensual)

El ledger vive en el journal repo, particionado por año/mes:

```
journal-repo/
  ledger/
    2026/
      02/
        entries.jsonl     ← entries de febrero
      03/
        entries.jsonl     ← entries de marzo
```

### Formato JSONL

Cada línea es un JSON completo (no array, no trailing comma):

```jsonl
{"protocol_version":"1.0","entry_id":"ledger-20260301042236-CTR-sentinels-toolkit-20260301","recorded_at":"2026-03-01T04:22:36Z","repository":"sentinels-toolkit","contract_id":"CTR-sentinels-toolkit-20260301","bundle_manifest_path":"bundles/2026/03/bundle-20260301T042233Z-ctr-sentinels-toolkit-20260301/bundle-manifest.json","bundle_sha256":"5c073823e2a0...","previous_bundle_sha256":"e22de008a239...","evidence_url":"https://github.com/sentinels-hub/sentinels-agents-journal/tree/main/bundles/2026/03/bundle-xxx","notes":"bundle_id=bundle-20260301T042233Z-ctr-sentinels-toolkit-20260301"}
```

## Campos de una entrada

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `protocol_version` | string | Sí | Siempre `"1.0"` |
| `entry_id` | string | Sí | `ledger-<YYYYMMDDHHmmss>-<contract_id>` |
| `recorded_at` | string | Sí | ISO 8601 timestamp |
| `repository` | string | Sí | Nombre del repo (`sentinels-*`) |
| `contract_id` | string | Sí | Contract ID |
| `bundle_manifest_path` | string | Sí | Path relativo al manifest en el journal |
| `bundle_sha256` | string | Sí | SHA-256 canónico del bundle (64 hex) |
| `previous_bundle_sha256` | string/null | Sí | Hash anterior (null si es el primero) |
| `actor_mapping_path` | string | No | Path al actor mapping |
| `evidence_url` | string | No | URL pública del evidence en GitHub |
| `notes` | string | No | Notas libres |

## Operaciones

### Añadir entrada al ledger

```bash
ev-cli.sh ledger append \
  --contract CTR-sentinels-hub-20260302 \
  --manifest bundles/2026/03/bundle-xxx/bundle-manifest.json \
  --journal-path ~/journal \
  --repo sentinels-hub \
  --evidence-url "https://github.com/sentinels-hub/..." \
  --notes "bundle_id=bundle-xxx"
```

Por defecto, `ledger append` hace git commit automático. Usar `--no-git-commit` para desactivar.

### Leer última entrada

```bash
ev-cli.sh ledger last --journal-path ~/journal
```

### Verificar integridad del ledger

```bash
ev-cli.sh ledger verify --journal-path ~/journal
```

### Listar entradas

```bash
ev-cli.sh ledger list --journal-path ~/journal [--contract CTR-xxx]
```

## Particionado

El ledger se particiona mensualmente (`ledger/<yyyy>/<mm>/entries.jsonl`). Las operaciones de verificación y lectura concatenan todas las particiones en orden cronológico.

Para compatibilidad con legacy, también se escanea `ledger/ledger.jsonl` si existe.

## Reglas

1. **Append-only**: NUNCA borrar ni modificar entradas existentes
2. **Hash chain**: `previous_bundle_sha256` debe coincidir exactamente
3. **Primera entrada**: `previous_bundle_sha256` es `null`
4. **Particionado**: entries van en `ledger/<yyyy>/<mm>/entries.jsonl`
5. **Git commit**: cada append se commitea inmediatamente en el journal
6. **Repository**: debe seguir el patrón `sentinels-*`
