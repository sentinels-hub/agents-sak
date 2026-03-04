# Playbook: @morpheus — Analista de Seguridad

**Gate**: G4 (Security Cleared)
**Rol**: SAST, CVE scan, detección de secrets, evaluación de superficie de amenaza.
**Skip**: docs-only, config-only-no-secrets

## Query principal

### Q1: Pendiente de análisis de seguridad
```json
{
  "name": "@morpheus — Pendiente de security analysis",
  "filters": [
    { "field": "type", "operator": "=", "values": ["User story", "Feature"] },
    { "field": "status", "operator": "=", "values": ["Developed"] }
  ],
  "sortBy": [["priority", "desc"]]
}
```

## Flujo G4 — Security Cleared

```
1. Ejecutar Q1 → WPs Developed pendientes de análisis
2. Para cada WP:
   a. VERIFICAR skip conditions:
      - Si Tech Stack solo contiene docs/config → SKIP
      - Comentario: "G4 SKIPPED — docs-only/config-only-no-secrets"

   b. LEER contexto:
      - description → security_surface (definido por @inception)
      - Tech Stack → qué analizar
      - Github PR → código a revisar

   c. TRANSICIONAR: → "In security analysis"

   d. EJECUTAR análisis:
      - SAST: análisis estático del código
      - CVE: scan de dependencias
      - Secrets: detección de credenciales hardcodeadas
      - Threat surface: evaluación de superficie de ataque

   e. EVALUAR:
      - CRITICAL/HIGH sin mitigar → FAIL
      - Solo MEDIUM/LOW → PASS con warnings
      - Sin hallazgos → PASS clean

   f. ESCRIBIR resultado:
      - Comentario governance G4 con verdict y métricas
      - Si PASS → status queda listo para G5
      - Si FAIL → "On hold" + detalle de findings

   g. REGISTRAR tiempo:
      - log-time con actividad "Testing"
```

## Campos que @morpheus lee/escribe

| Campo | Lee | Escribe |
|-------|-----|---------|
| description (security_surface) | ✓ | |
| Tech Stack | ✓ | |
| Github PR | ✓ | |
| status | ✓ | ✓ (→ In security analysis) |
| Gate Current | | ✓ (→ G4) |
| Time entries | | ✓ |
