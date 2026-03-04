# Playbook: @jarvis — G8 Co-owner + G9 Verification

## Contexto

Jarvis tiene dos roles en el flujo de evidence:
- **G8 Co-owner**: Después de que Ariadne crea el bundle y el ledger entry, Jarvis escribe los campos de trazabilidad en OpenProject.
- **G9 Verification**: Jarvis ejecuta la verificación completa de la cadena y cierra el contrato.

## G8: Escribir campos en OpenProject

### Pre-requisitos

- Ariadne completó G8 (bundle + ledger entry creados)
- Acceso a OpenProject API (`OPENPROJECT_URL`, `OPENPROJECT_API_TOKEN`)
- WP ID del Work Package del contrato

### Paso 1: Obtener datos del bundle

```bash
JOURNAL_PATH=~/GitHub/sentinels-hub/sentinels-agents-journal

# Último ledger entry
ev-cli.sh ledger last --journal-path "$JOURNAL_PATH"

# Extraer datos
BUNDLE_SHA256=$(ev-cli.sh ledger last --journal-path "$JOURNAL_PATH" | jq -r '.bundle_sha256')
EVIDENCE_URL=$(ev-cli.sh ledger last --journal-path "$JOURNAL_PATH" | jq -r '.evidence_url')
ENTRY_ID=$(ev-cli.sh ledger last --journal-path "$JOURNAL_PATH" | jq -r '.entry_id')
```

### Paso 2: Escribir en OpenProject

Usando la OP CLI (op-cli.sh):

```bash
op-cli.sh wp update <WP_ID> \
  --field "Evidence URL" "$EVIDENCE_URL" \
  --field "Evidence SHA256" "$BUNDLE_SHA256" \
  --field "Ledger Entry" "$ENTRY_ID"
```

### Paso 3: Verificar campos en OP

```bash
op-cli.sh wp get <WP_ID> --fields "Evidence URL,Evidence SHA256,Ledger Entry"
```

## G9: Verificación completa y cierre

### Paso 1: Verificar bundle integrity

```bash
ev-cli.sh bundle verify "$JOURNAL_PATH/bundles/2026/03/bundle-xxx/bundle-manifest.json"
```

### Paso 2: Verificar ledger chain

```bash
ev-cli.sh ledger verify --journal-path "$JOURNAL_PATH"
```

### Paso 3: Cross-check híbrido

```bash
ev-cli.sh verify cross-check \
  --journal-path "$JOURNAL_PATH" \
  --manifest "$JOURNAL_PATH/bundles/2026/03/bundle-xxx/bundle-manifest.json"
```

Completar la checklist manual:
- [ ] `evidence_url` en OP apunta a bundle existente
- [ ] `evidence_sha256` en OP coincide con `bundle_sha256`
- [ ] `ledger_entry` en OP corresponde a entry válido
- [ ] GitHub PR referenciado existe y está merged
- [ ] Git commits referenciados existen en el repo

### Paso 4: Cierre del contrato

Si todas las verificaciones pasan:
1. Actualizar estado del WP en OP a "Done" / "Closed"
2. Registrar fecha de cierre
3. Documentar resultado de verificación en notas del WP

## Checklist G9

- [ ] Bundle integrity: PASS
- [ ] Ledger chain: UNBROKEN
- [ ] OP cross-reference: todos los campos coinciden
- [ ] GitHub PR: merged
- [ ] Contrato cerrado en OP
- [ ] Resultado documentado
