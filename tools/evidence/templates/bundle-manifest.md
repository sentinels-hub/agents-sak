# Bundle Manifest Template

## Campos requeridos

```json
{
  "protocol_version": "1.0",
  "bundle_id": "bundle-{COMPACT_TIMESTAMP}-{CONTRACT_ID_LOWER}",
  "contract_id": "{CONTRACT_ID}",
  "generated_at": "{ISO_8601_TIMESTAMP}",
  "format": "json",
  "artifacts": [
    {
      "path": "{FILENAME}",
      "sha256": "{64_HEX_CHARS}",
      "size_bytes": "{SIZE}",
      "redacted": true
    }
  ],
  "bundle_sha256": "{CANONICAL_SHA256}",
  "previous_bundle_sha256": "{PREVIOUS_OR_NULL}",
  "sources": {
    "openproject": { "status": "skipped" },
    "github": { "status": "available", "detail": "..." },
    "opencode": { "status": "unavailable" }
  },
  "redaction": {
    "patterns_applied": ["email", "api_key"],
    "replacements": 3
  }
}
```

## Generar con ev-cli.sh

```bash
ev-cli.sh bundle create CTR-sentinels-hub-20260302 ./artifacts/ \
  --journal-path ~/journal \
  --sources-gh available \
  --redaction-patterns email,api_key
```

## Naming convention

```
bundle-<YYYYMMDDTHHMMSSz>-<contract_id_lower>
```

- `YYYYMMDDTHHMMSSz`: timestamp UTC compacto
- `contract_id_lower`: contract ID en minúsculas

Ejemplo: `bundle-20260310T143000Z-ctr-sentinels-hub-20260302`

## Calcular bundle_sha256 (algoritmo canónico de Lighthouse)

1. Ordenar artifacts por `path`
2. Para cada artifact: `path:sha256:size_bytes`
3. Si `previous_bundle_sha256` no es null: `previous:<hash>`
4. Unir con `\n`
5. SHA-256 del resultado

Este algoritmo es reproducible independientemente del formato JSON del manifest.

## Estructura en el journal

```
bundles/<yyyy>/<mm>/bundle-<ts>-<contract>/
  bundle-manifest.json
  contract.json
  git-metadata.json
  github-evidence.json
  session-transcript.jsonl
  bundle-events.jsonl
```
