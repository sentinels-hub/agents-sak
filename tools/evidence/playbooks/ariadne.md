# Playbook: @ariadne — G8 Evidence Export

## Contexto

Ariadne es el agente responsable de G8 (Evidence). Su trabajo es recopilar la evidencia generada durante el ciclo de vida del contrato, redactarla, empaquetarla en un bundle verificable, y registrarla en el ledger del journal.

## Pre-requisitos

- Journal repo clonado: `JOURNAL_PATH=~/GitHub/sentinels-hub/sentinels-agents-journal`
- Contract ID conocido: `CONTRACT_ID=CTR-xxx-YYYYMMDD`
- Artifacts recopilados en un directorio temporal
- `ev-setup.sh --check-only $JOURNAL_PATH` pasa sin errores

## Flujo completo

### Paso 1: Preparar artifacts

Recopilar todos los artifacts relevantes del contrato en un directorio temporal:

```bash
WORK_DIR=$(mktemp -d)

# Contract snapshot
cp contract.json "$WORK_DIR/"

# Git metadata
git log --oneline -20 --format='{"hash":"%H","subject":"%s","date":"%aI"}' > "$WORK_DIR/git-metadata.json"

# GitHub evidence (PR, issues, checks)
gh pr view <N> --json number,title,body,state,commits,reviews > "$WORK_DIR/github-evidence.json"

# Session transcript (si existe)
cp session-transcript.jsonl "$WORK_DIR/" 2>/dev/null || true

# Identity/actor mapping (si existe)
cp identity-actor-mapping.json "$WORK_DIR/" 2>/dev/null || true
```

### Paso 2: Redactar información sensible

```bash
# Dry-run primero para ver qué se redactaría
ev-cli.sh redact "$WORK_DIR" --dry-run

# Aplicar redacción
ev-cli.sh redact "$WORK_DIR" --patterns email,api_key,token,secret,ip,path,ghp,github_pat,sk
```

### Paso 3: Crear bundle

```bash
ev-cli.sh bundle create "$CONTRACT_ID" "$WORK_DIR" \
  --journal-path "$JOURNAL_PATH" \
  --sources-op skipped \
  --sources-gh available \
  --sources-oc unavailable \
  --redaction-patterns email,api_key,token,secret,ip,path,ghp,github_pat,sk
```

Output esperado:
```
Bundle creado: bundle-20260310T143000Z-ctr-xxx-20260302
  Manifest: ~/journal/bundles/2026/03/bundle-xxx/bundle-manifest.json
  Artifacts: 5
  SHA-256: abcdef123456...
  Previous: 789012fedcba...
```

### Paso 4: Verificar bundle

```bash
# Obtener path del manifest del output anterior
MANIFEST_PATH="$JOURNAL_PATH/bundles/2026/03/bundle-xxx/bundle-manifest.json"

ev-cli.sh bundle verify "$MANIFEST_PATH"
```

Debe mostrar `Status: PASS`.

### Paso 5: Append al ledger

```bash
BUNDLE_ID=$(jq -r '.bundle_id' "$MANIFEST_PATH")

ev-cli.sh ledger append \
  --contract "$CONTRACT_ID" \
  --manifest "bundles/2026/03/$BUNDLE_ID/bundle-manifest.json" \
  --journal-path "$JOURNAL_PATH" \
  --repo sentinels-agents \
  --evidence-url "https://github.com/sentinels-hub/sentinels-agents-journal/tree/main/bundles/2026/03/$BUNDLE_ID" \
  --notes "bundle_id=$BUNDLE_ID"
```

### Paso 6: Verificar ledger

```bash
ev-cli.sh ledger verify --journal-path "$JOURNAL_PATH"
```

Debe mostrar `Status: PASS` y `Chain: UNBROKEN`.

### Paso 7: Push al journal repo

```bash
cd "$JOURNAL_PATH"
git push origin main
```

### Paso 8: Limpiar

```bash
rm -rf "$WORK_DIR"
```

## Checklist de verificación post-export

- [ ] Bundle creado en `bundles/<yyyy>/<mm>/`
- [ ] `bundle_sha256` verificado con algoritmo canónico
- [ ] Todos los artifacts verificados (hash + size)
- [ ] Ledger entry añadida con `previous_bundle_sha256` correcto
- [ ] Ledger chain UNBROKEN
- [ ] Journal repo pushed
- [ ] Notificar a @jarvis para G8 co-owner (campos OP)
