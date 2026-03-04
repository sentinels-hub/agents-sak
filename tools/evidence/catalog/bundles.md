# Evidence — Bundles

## Concepto

Un **bundle** es un paquete de evidencia que demuestra que un trabajo fue realizado correctamente. Contiene:

- **Artifacts**: archivos que constituyen la evidencia (código, configs, logs, reports)
- **Manifest**: JSON que lista todos los artifacts con sus hashes SHA-256
- **Bundle SHA-256**: hash canónico calculado desde el artifact index (algoritmo de Lighthouse)
- **Previous bundle SHA-256**: enlace al bundle anterior (hash chain)
- **Sources**: estado de disponibilidad de las fuentes (OpenProject, GitHub, OpenCode)
- **Redaction**: registro de patrones de redacción aplicados

## Estructura de un bundle

```
journal-repo/
  bundles/
    2026/
      03/
        bundle-20260310T143000Z-ctr-sentinels-hub-20260302/
          bundle-manifest.json       ← manifest con hashes
          contract.json              ← snapshot del contrato
          git-metadata.json          ← branch, commits, remote
          github-evidence.json       ← PR/issues evidence
          session-transcript.jsonl   ← transcript de la sesión
          bundle-events.jsonl        ← log de registro de artifacts
```

## Bundle manifest

```json
{
  "protocol_version": "1.0",
  "bundle_id": "bundle-20260310T143000Z-ctr-sentinels-hub-20260302",
  "contract_id": "CTR-sentinels-hub-20260302",
  "generated_at": "2026-03-10T14:30:00Z",
  "format": "json",
  "artifacts": [
    {
      "path": "contract.json",
      "sha256": "9f7f51aeb657...",
      "size_bytes": 2941,
      "redacted": true
    },
    {
      "path": "git-metadata.json",
      "sha256": "15e7b2b056f7...",
      "size_bytes": 342,
      "redacted": true
    }
  ],
  "bundle_sha256": "5c073823e2a0...",
  "previous_bundle_sha256": "e22de008a239...",
  "sources": {
    "openproject": { "status": "skipped" },
    "github": { "status": "available", "detail": "PR #42 merged" },
    "opencode": { "status": "unavailable", "detail": "no session found" }
  },
  "redaction": {
    "patterns_applied": ["ghp_", "github_pat_", "api_key", "password"],
    "replacements": 3
  }
}
```

## Hash canónico (bundle_sha256)

El `bundle_sha256` se calcula con el **algoritmo canónico de Lighthouse**, no sobre el manifest completo:

1. Ordenar artifacts por `path` (alphabetical)
2. Para cada artifact, crear la línea: `path:sha256:size_bytes`
3. Si `previous_bundle_sha256` existe, añadir: `previous:<hash>`
4. Unir todas las líneas con `\n`
5. SHA-256 del resultado

Esto garantiza reproducibilidad independiente del formato JSON.

## Crear un bundle

```bash
# Crear bundle y guardarlo en el journal
ev-cli.sh bundle create CTR-sentinels-hub-20260302 ./artifacts/ \
  --journal-path ~/journal \
  --sources-gh available \
  --redaction-patterns email,api_key,token

# Crear bundle a stdout (sin guardar)
ev-cli.sh bundle create CTR-sentinels-hub-20260302 ./artifacts/
```

## Operaciones con el CLI

```bash
# Crear bundle desde directorio de artifacts
ev-cli.sh bundle create <CONTRACT_ID> <ARTIFACTS_DIR> [--journal-path PATH]

# Verificar integridad de un bundle
ev-cli.sh bundle verify <MANIFEST_PATH>

# Listar bundles (escanea bundles/ y evidence/ legacy)
ev-cli.sh bundle list <JOURNAL_PATH> [CONTRACT_ID]
```

## Sources block

Cada bundle registra el estado de las fuentes de datos:

| Source | Status | Significado |
|--------|--------|-------------|
| `openproject` | `available` / `unavailable` / `skipped` | Estado de sincronización con OP |
| `github` | `available` / `unavailable` / `skipped` | PR, issues, checks |
| `opencode` | `available` / `unavailable` / `skipped` | Session transcript |

## Reglas

1. **Inmutabilidad**: un bundle creado NO se modifica
2. **Hash chain**: cada bundle referencia al anterior via `previous_bundle_sha256`
3. **Hash canónico**: usar algoritmo de Lighthouse (artifact index), no hash del manifest
4. **Completitud**: todos los artifacts referenciados deben existir y coincidir en hash
5. **Redacción**: información sensible debe redactarse ANTES de crear el bundle
6. **Estructura**: `bundles/<yyyy>/<mm>/<bundle_id>/` en el journal repo
7. **Sources**: siempre registrar estado de fuentes (aunque sea `skipped`)
