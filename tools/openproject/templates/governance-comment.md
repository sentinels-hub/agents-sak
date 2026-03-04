# Template: Governance Comment

Formato estándar para comentarios de agentes en Work Packages de OpenProject.

## Formato

```
[@<AGENT>@<VERSION>] | contract: <CONTRACT_ID> | gate: <GATE> | <MESSAGE>
```

## Campos

| Campo | Formato | Ejemplo |
|-------|---------|---------|
| AGENT | nombre sin @ | gtd, inception, oracle |
| VERSION | SemVer | 0.3.0, 2.0.0 |
| CONTRACT_ID | CTR-<proyecto>-<fecha> | CTR-sentinels-hub-20260302 |
| GATE | G0-G9 | G3, G6 |
| MESSAGE | Texto libre descriptivo | Implementation complete — 8 commits |

## Templates por gate

### G0 — Contract Initialized (@jarvis)
```
[@jarvis@{VERSION}] | contract: {CONTRACT_ID} | gate: G0 | Contract initialized — WP#{WP_ID} registered, scope defined
```

### G1 — Identity Verified (@jarvis)
```
[@jarvis@{VERSION}] | contract: {CONTRACT_ID} | gate: G1 | Identity verified — OP user {USER_ID} matches GitHub {GH_USER}
```

### G2 — Plan Approved (@inception)
```
[@inception@{VERSION}] | contract: {CONTRACT_ID} | gate: G2 | Plan approved — {N_TASKS} tasks, {TOTAL_HOURS}h estimated, version {VERSION_NAME}
```

### G3 — Implementation Tracked (@gtd)
```
[@gtd@{VERSION}] | contract: {CONTRACT_ID} | gate: G3 | Implementation complete — {N_COMMITS} commits, {N_TASKS}/{TOTAL_TASKS} tasks developed
```

### G4 — Security Cleared (@morpheus)
```
[@morpheus@{VERSION}] | contract: {CONTRACT_ID} | gate: G4 | Security analysis complete — SAST: {STATUS}, CVE: {STATUS}, Secrets: {STATUS}, Verdict: {VERDICT}
```

### G5 — Code Review Approved (@agent-smith)
```
[@agent-smith@{VERSION}] | contract: {CONTRACT_ID} | gate: G5 | Code review: {VERDICT} — Security {SCORE}/10, Bugs {SCORE}/10, {N_FINDINGS} findings, {N_NITS} nits
```

### G6 — Verification Passed (@oracle)
```
[@oracle@{VERSION}] | contract: {CONTRACT_ID} | gate: G6 | QA {VERDICT} — {PASS}/{TOTAL} tests, {N_AC} AC verified, compliance: {FRAMEWORKS}
```

### G7 — Deployment Verified (@pepper)
```
[@pepper@{VERSION}] | contract: {CONTRACT_ID} | gate: G7 | Deployment verified — env: {ENV}, health: HTTP {CODE}, rollback: {READY/NOT_READY}
```

### G8 — Evidence Exported (@jarvis + @ariadne)
```
[@jarvis@{VERSION}] | contract: {CONTRACT_ID} | gate: G8 | Evidence exported — bundle SHA256: {HASH_SHORT}..., changelog updated, ledger published
```

### G9 — Closure Complete (@jarvis)
```
[@jarvis@{VERSION}] | contract: {CONTRACT_ID} | gate: G9 | Contract closed — OP: Closed, GitHub: merged, ledger: published, evidence: registered
```

### Human Approval
```
[@{AGENT}@{VERSION}] | contract: {CONTRACT_ID} | gate: {GATE} | Human approval registered — reviewer: {HUMAN_NAME}
```

## Comando

```bash
# Comentario governance estructurado
openproject-sync.sh comment-step <WP_ID> <CONTRACT_ID> <GATE> "Message"

# Comentario de aprobación humana
openproject-sync.sh comment-human <WP_ID> <CONTRACT_ID> <GATE> <HUMAN_NAME>
```

## Reglas

1. **Siempre incluir los 4 campos** — agent, contract, gate, message
2. **Versión del agente** corresponde a la versión del runtime de sentinels-agents
3. **Un comentario por acción significativa** — no spam, no duplicados
4. **Idempotencia**: verificar si ya existe un comentario para el mismo gate antes de crear
5. **Mensaje descriptivo**: incluir métricas cuantificables (X commits, Y tests, Z/10 score)
