# OpenProject — Status Workflow

Flujo de estados canónico para Work Packages según el protocolo Sentinels.

## Estados corporativos

```
New → In specification → In progress → Developed → In security analysis → In review → Verification → In deployment → Deployed → Closed
                                  ↘                                                        ↗
                              On hold / Test failed / Rejected  (estados de bloqueo)
```

## Mapping Sentinels → OpenProject

| Estado Sentinels | Estados OP equivalentes |
|-----------------|------------------------|
| New | New |
| Ready | Ready |
| In specification | In specification, Specified, Confirmed, To be scheduled |
| In Progress | Scheduled, In progress |
| Developed | Developed |
| In security analysis | In security analysis |
| In review | In review |
| Verification | Verification, In testing, Tested |
| In deployment | In deployment |
| Deployed | Deployed |
| Blocked | On hold, Test failed, Rejected |
| Done/Closed | Done, Closed |

## Progreso implícito por estado

| Estado | % Progreso |
|--------|-----------|
| New | 0% |
| In specification | 10% |
| In progress | 40% |
| Developed | 60% |
| In security analysis | 65% |
| In review | 70% |
| Verification | 80% |
| In deployment | 90% |
| Deployed / Closed | 100% |
| Test failed | 70% |

## Transiciones por rol

### Member (developer/agent)
Puede transicionar entre:
- New ↔ In specification ↔ In progress ↔ Developed ↔ Verification ↔ Test failed ↔ On hold

**NO puede**: transicionar a `Closed`, `Rejected`

### Project Manager (reviewer)
Puede transicionar a:
- Closed, Rejected (además de todo lo que puede Member)

> **Segregación de deberes**: Los agentes NO pueden auto-cerrar WPs. Requiere rol de project manager.

## Transiciones por gate

| Gate | Agente | Transición típica |
|------|--------|-------------------|
| G0 | @jarvis | → New |
| G2 | @inception | → In specification |
| G3 | @gtd | → In progress → Developed |
| G4 | @morpheus | → In security analysis |
| G5 | @agent-smith | → In review |
| G6 | @oracle | → Verification |
| G7 | @pepper | → In deployment → Deployed |
| G9 | @jarvis | → Closed (requiere project manager) |

## Operaciones

### Transicionar estado

```bash
# Transición simple
openproject-sync.sh transition <WP_ID> <STATUS_NAME>

# Transición + log de tiempo + comentario governance
openproject-sync.sh transition-and-log <WP_ID> <STATUS_NAME> [AGENT_NAME] [COMMENT]

# Resolver nombre de estado a ID numérico
openproject-sync.sh resolve-status <STATUS_NAME>
```

### Ejemplo de flujo completo

```bash
# @inception planifica (G2)
openproject-sync.sh transition-and-log 1837 "In specification" "inception" "Plan approved — 5 tasks, 14h estimated"

# @gtd implementa (G3)
openproject-sync.sh transition-and-log 1837 "In progress" "gtd" "Implementation started"
openproject-sync.sh transition-and-log 1837 "Developed" "gtd" "Implementation complete — 8 commits"

# @morpheus analiza seguridad (G4)
openproject-sync.sh transition-and-log 1837 "In security analysis" "morpheus" "SAST + CVE scan initiated"

# @agent-smith revisa (G5)
openproject-sync.sh transition-and-log 1837 "In review" "agent-smith" "Code review: APPROVE — Security 8/10, Bugs 9/10"

# @oracle verifica (G6)
openproject-sync.sh transition-and-log 1837 "Verification" "oracle" "QA passed — 30/30 tests, compliance verified"

# @pepper despliega (G7)
openproject-sync.sh transition-and-log 1837 "In deployment" "pepper" "Deploying to production"
openproject-sync.sh transition-and-log 1837 "Deployed" "pepper" "Health checks OK — HTTP 200, 3/3 attempts"
```

## Flow Profile: sentinels_default

### Backlog statuses (pre-ejecución)
- New, In specification, Specified, Confirmed, To be scheduled

### Roadmap statuses (ejecución)
- Scheduled, In progress, Developed, In review, Verification, Done, Closed

### Exception statuses
- On hold, Test failed, Rejected
