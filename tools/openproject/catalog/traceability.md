# OpenProject — Trazabilidad

Guía completa de trazabilidad entre Git, OpenProject y Evidence.

## La cadena de trazabilidad

```
Contract (G0)
  │
  ├── OpenProject Work Package
  │     ├── contract_id         → Liga WP con contrato
  │     ├── version             → Liga WP con iteración
  │     ├── Github (PR URL)     → Liga WP con PR
  │     ├── Github Commit       → Liga WP con commit
  │     ├── Evidence URL        → Liga WP con bundle de evidencia
  │     ├── Evidence SHA256     → Integridad del bundle
  │     └── Ledger Entry        → Posición en el ledger inmutable
  │
  ├── Git
  │     ├── Branch: feat/wp-<ID>-<desc>
  │     ├── Commits: type(scope): desc [WP#ID]
  │     └── PR: refs WP en título/body
  │
  └── Evidence
        ├── Bundle manifest (SHA-256)
        ├── previous_bundle_sha256 (hash chain)
        ├── Artifacts con hash individual
        └── Ledger entry (append-only)
```

## Campos de trazabilidad requeridos

Según `required_traceability` de policy.yaml:

| Campo | Fuente | Cuándo se completa |
|-------|--------|-------------------|
| `contract_id` | Contrato | G0 |
| `openproject_work_package_id` | OP | G0 |
| `openproject_version_id` | OP | G2 |
| `openproject_status` | OP | Cada transición |
| `openproject_estimatedTime` | OP | G2 |
| `identity_actor_mapping` | Contrato | G1 |
| `git_branch` | Git | G3 |
| `git_commits` | Git | G3 |
| `git_pr_url` | GitHub | G3/G5 |
| `git_commit_url` | GitHub | G3 |
| `documentation_reference` | Docs | G8 |
| `verification_evidence` | QA | G6 |
| `evidence_bundle_manifest` | Journal | G8 |
| `evidence_bundle_sha256` | Journal | G8 |
| `previous_bundle_sha256` | Journal | G8 |
| `risks_and_mitigations` | Plan | G2 |

## Convenciones Git

### Branch naming

```
feat/wp-<WP_ID>-<descripcion-corta>     # Feature/User Story
fix/wp-<WP_ID>-<descripcion-corta>      # Bugfix
chore/wp-<WP_ID>-<descripcion-corta>    # Mantenimiento
docs/wp-<WP_ID>-<descripcion-corta>     # Documentación
```

### Commit message format

```
type(scope): description [WP#ID]
```

Tipos: `feat`, `fix`, `chore`, `docs`, `build`, `refactor`, `test`

Ejemplos:
```
feat(auth): implement OAuth2 provider [WP#1897]
fix(hud): correct contrast ratio for WCAG [WP#1899]
docs(readme): update setup instructions [WP#1901]
```

## Governance Comments

Cada acción significativa de un agente en OP genera un comentario estructurado:

```
[@<AGENT>@<VERSION>] | contract: <CONTRACT_ID> | gate: <GATE> | <MESSAGE>
```

Ejemplos:
```
[@gtd@0.3.0] | contract: CTR-sentinels-hub-20260302 | gate: G3 | Implementation complete — 8 commits
[@oracle@0.3.0] | contract: CTR-sentinels-hub-20260302 | gate: G6 | QA PASS — 30/30 tests, 5 AC verified
[@pepper@2.0.0] | contract: CTR-sentinels-hub-20260302 | gate: G7 | Deployed — health OK, rollback ready
```

### Operaciones de comentario

```bash
# Comentario governance estructurado
openproject-sync.sh comment-step <WP_ID> <CONTRACT_ID> <GATE> "Message"

# Comentario de aprobación humana
openproject-sync.sh comment-human <WP_ID> <CONTRACT_ID> <GATE> <HUMAN_NAME>

# Comentario libre
openproject-sync.sh comment <WP_ID> "Free text comment"
```

## Operaciones de trazabilidad

```bash
# Vincular PR
openproject-sync.sh set-github-pr <WP_ID> <PR_URL>

# Vincular commit
openproject-sync.sh set-github-commit <WP_ID> <COMMIT_URL>

# Vincular contrato
openproject-sync.sh set-contract-id <WP_ID> <CONTRACT_ID>

# Vincular evidencia
openproject-sync.sh set-evidence-url <WP_ID> <EVIDENCE_URL>
openproject-sync.sh set-evidence-sha256 <WP_ID> <SHA256>
openproject-sync.sh set-ledger-entry <WP_ID> <LEDGER_VALUE>

# Validar trazabilidad completa
openproject-sync.sh validate <WP_ID>
```

## Verificación de integridad

### Hash chain (Evidence)

```
Bundle N-1                    Bundle N
  bundle_sha256: abc123  ←──  previous_bundle_sha256: abc123
                              bundle_sha256: def456
```

Si `previous_bundle_sha256` no coincide → la cadena está rota → no se puede cerrar (G9 falla).

### Identidad (G1)

```bash
# Verificar identidad OP
openproject-sync.sh me

# Cross-check con Git
git config user.name
git config user.email
```

El actor declarado DEBE coincidir en OP y GitHub. Mismatch = G1 falla.

## Diagrama de trazabilidad completa

```
    OpenProject                    Git                    Evidence
    ───────────                    ───                    ────────
    WP#1837 ──────────────────── branch feat/wp-1837
       │                              │
       ├── contract_id ◄──── contract.json (G0)
       ├── version v0.1.0              │
       ├── status: Developed           │
       │                          commit abc123 [WP#1837]
       ├── Github Commit ◄────── commit URL
       │                              │
       │                          PR #42
       ├── Github PR ◄────────── PR URL
       │                              │
       │                                            bundle-manifest.json
       ├── Evidence URL ◄────────────────────────── bundle path
       ├── Evidence SHA256 ◄─────────────────────── bundle_sha256
       └── Ledger Entry ◄───────────────────────── ledger entry line
```
