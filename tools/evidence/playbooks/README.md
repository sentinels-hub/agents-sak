# Evidence Playbooks

Guías operativas para los agentes que interactúan con la Evidence Tool.

## Índice

| Playbook | Agente | Gate | Descripción |
|----------|--------|------|-------------|
| [ariadne.md](ariadne.md) | @ariadne | G8 | Evidence Export: redactar, crear bundle, append ledger, verificar, push |
| [jarvis.md](jarvis.md) | @jarvis | G8/G9 | G8 co-owner (campos OP) + G9 verificación completa y cierre |

## Cuándo usar cada playbook

### @ariadne — G8 Evidence Export

Ejecutar cuando un contrato llega a G8 (Evidence). Ariadne es responsable de:
- Recopilar y redactar artifacts
- Crear el bundle con hash canónico
- Registrar en el ledger
- Verificar integridad
- Push al journal repo

### @jarvis — G8 Co-owner + G9 Closure

Ejecutar después de que Ariadne complete G8:
- **G8**: Escribir campos de trazabilidad en OpenProject (evidence_url, evidence_sha256, ledger_entry)
- **G9**: Verificación completa de la cadena, cross-check con OP, cierre del contrato

## Pre-requisitos

1. Journal repo clonado y accesible
2. Dependencias instaladas: `ev-setup.sh --check-only <JOURNAL_PATH>`
3. Acceso git al journal repo (push)
4. Para @jarvis G8: acceso a OpenProject API
