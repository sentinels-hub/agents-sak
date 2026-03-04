# Evidence — Redacción

## Concepto

Antes de crear un bundle de evidencia, la información sensible debe **redactarse**. La redacción reemplaza datos sensibles con placeholders mientras mantiene la estructura del documento.

## Qué redactar

| Tipo | Patrón | Reemplazo |
|------|--------|-----------|
| API keys | `api_key=...`, `api_token=...` | `[REDACTED:api_key]` |
| Tokens | `Bearer ...`, `token: ...` | `[REDACTED:token]` |
| Emails | `user@domain.com` | `[REDACTED:email]` |
| IPs privadas | `10.x.x.x`, `192.168.x.x` | `[REDACTED:ip]` |
| Passwords | `password: ...`, `secret: ...` | `[REDACTED:secret]` |
| Rutas absolutas | `/Users/<name>/...`, `/home/<name>/...` | `[REDACTED:path]` |
| GitHub PATs | `ghp_...`, `github_pat_...` | `[REDACTED:github_pat]` |
| API keys (sk) | `sk-...` | `[REDACTED:api_key]` |

## Qué NO redactar

- SHA-256 hashes (son la base de la trazabilidad)
- URLs públicas de GitHub
- Nombres de agentes (@jarvis, @gtd, etc.)
- Contract IDs, WP IDs, Gate IDs
- Timestamps
- Nombres de archivos

## Operaciones

### Redactar un directorio de artifacts

```bash
ev-cli.sh redact <ARTIFACTS_DIR> [--patterns email,api_key,token,secret,ip,path]
```

### Redactar un archivo específico

```bash
ev-cli.sh redact-file <FILE> [--patterns email,token]
```

### Ver qué se redactaría (dry-run)

```bash
ev-cli.sh redact <ARTIFACTS_DIR> --dry-run
ev-cli.sh redact-file <FILE> --dry-run
```

### Redactar al crear un bundle

```bash
ev-cli.sh bundle create CTR-xxx ./artifacts/ --redaction-patterns email,api_key,token
```

Esto aplica la redacción a los artifacts antes de calcular los hashes y registra automáticamente los patrones en el campo `redaction` del manifest.

## Registro de redacción

Cada bundle incluye un campo `redaction` en el manifest:

```json
{
  "redaction": {
    "patterns_applied": ["ghp_", "github_pat_", "api_key", "password"],
    "replacements": 7
  }
}
```

Esto permite a los auditores saber que se aplicó redacción y cuántos reemplazos se hicieron.

## Reglas

1. **Redactar ANTES de hashear** — los hashes son de los artifacts ya redactados
2. **Registrar patrones** — siempre documentar qué patrones se aplicaron en el manifest
3. **No redactar hashes** — los SHA-256 son intocables
4. **Idempotente** — aplicar redacción dos veces produce el mismo resultado
5. **Backup opcional** — mantener originales en ubicación segura (nunca en el journal)
