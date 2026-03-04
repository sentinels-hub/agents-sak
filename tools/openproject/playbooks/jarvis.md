# Playbook: @jarvis — Orquestador

**Gates**: G0 (Contract Init), G1 (Identity), G8 (Evidence Export), G9 (Closure)
**Rol**: Ciclo de vida completo del contrato. Primer y último agente en actuar.

## Queries principales

### Q1: Contratos pendientes de inicialización (G0)
```json
{
  "name": "@jarvis — Contratos por inicializar",
  "filters": [
    { "field": "type", "operator": "=", "values": ["User story"] },
    { "field": "status", "operator": "=", "values": ["New"] },
    { "field": "customField:contract_id", "operator": "!*", "values": [] }
  ],
  "sortBy": [["createdAt", "asc"]]
}
```

### Q2: Pendiente de cierre (G9)
```json
{
  "name": "@jarvis — Pendiente de cierre",
  "filters": [
    { "field": "status", "operator": "=", "values": ["Deployed"] },
    { "field": "customField:evidence_url", "operator": "*", "values": [] }
  ],
  "sortBy": [["priority", "desc"]]
}
```

### Q3: Health check de proyectos
```json
{
  "name": "@jarvis — Proyectos at risk",
  "filters": [
    { "field": "project_status_code", "operator": "=", "values": ["at_risk", "in_trouble"] }
  ]
}
```

## Flujo G0 — Contract Initialized

```
1. Ejecutar Q1 → WPs sin contract_id
2. Para cada WP:
   a. Crear contract.json con scope, plan summary
   b. Registrar WP en OP:
      - set-contract-id <WP_ID> <CONTRACT_ID>
      - Verificar campos requeridos existen
   c. Comentario governance:
      "[@jarvis@{V}] | contract: {CTR} | gate: G0 | Contract initialized — WP#{ID} registered"
   d. Status queda en New (no transicionar)
```

## Flujo G1 — Identity Verified

```
1. Para WPs con contract_id y G0 passed:
   a. Ejecutar: openproject-sync.sh me → obtener OP user
   b. Ejecutar: git config user.name/email → obtener Git user
   c. Cross-check: OP user == Git user declarado en contract
   d. Si match:
      - Comentario: "[@jarvis@{V}] | contract: {CTR} | gate: G1 | Identity verified"
   e. Si mismatch:
      - Gate FAIL → no continuar
      - Comentario con detalle del mismatch
```

## Flujo G8 — Evidence Exported (con @ariadne)

```
1. Ejecutar query: WPs con status=Deployed, gate G7 passed
2. Para cada WP:
   a. Generar bundle manifest (SHA-256 de artefactos)
   b. Computar bundle_sha256 y previous_bundle_sha256
   c. Actualizar CHANGELOG.md
   d. Generar release notes
   e. Publicar en ledger
   f. Escribir en OP:
      - set-evidence-url <WP_ID> <URL>
      - set-evidence-sha256 <WP_ID> <HASH>
      - set-ledger-entry <WP_ID> <ENTRY>
   g. Comentario governance G8
```

## Flujo G9 — Closure Complete

```
1. Ejecutar Q2 → WPs con evidence registrada
2. Para cada WP:
   a. Verificar cadena completa: contract → WP → branch → commits → PR → evidence → ledger
   b. Verificar todos los gates G0-G8 passed
   c. Si completo:
      - Transicionar a Closed (requiere rol project manager)
      - Merge PR en GitHub
      - Comentario governance G9
      - Actualizar project status + statusExplanation
   d. Si incompleto:
      - Listar campos faltantes
      - No cerrar — reportar gaps
```

## Flujo periódico — Health Check de Proyectos

```
Cada ciclo (diario o por trigger):
1. Listar todos los proyectos activos
2. Para cada proyecto:
   a. Contar WPs por estado
   b. Calcular % bloqueados, % vencidos
   c. Evaluar:
      - bloqueados > 20% → at_risk
      - vencidos > 10% → at_risk
      - bloqueados > 40% → in_trouble
      - Todo OK → on_track
   d. Actualizar project status y statusExplanation con métricas
```

## Campos que @jarvis lee/escribe

| Campo | Lee | Escribe | Cuándo |
|-------|-----|---------|--------|
| contract_id | ✓ | ✓ | G0 |
| evidence_url | ✓ | ✓ | G8 |
| evidence_sha256 | | ✓ | G8 |
| ledger_entry | | ✓ | G8 |
| status | ✓ | ✓ | G9 (→Closed) |
| project.status | ✓ | ✓ | Health check |
| project.statusExplanation | | ✓ | Health check |
| All gate fields | ✓ | | G9 (verificación) |
