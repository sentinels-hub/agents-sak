# Compliance Playbooks

Playbooks para agentes que ejecutan operaciones de compliance.

## Playbooks disponibles

| Playbook | Agente | Gate | Descripción |
|----------|--------|------|-------------|
| [jarvis.md](jarvis.md) | @jarvis | G9 | Compliance Audit — auditoría completa de release |
| [oracle.md](oracle.md) | @oracle | G6 | QA Compliance Check — verificación de controles G6 |

## Pre-requisitos

- Journal repo clonado y accesible
- Dependencias instaladas (verificar con `co-setup.sh --check-only`)
- Git push access al journal repo
- OpenProject API access (para @jarvis G9)

## Herramientas

| Script | Uso |
|--------|-----|
| `co-cli.sh` | CLI principal — audit, control, report, verify |
| `co-setup.sh` | Setup y verificación del journal |
| `co-core.sh` | Funciones compartidas (source-only) |

## Flujo general

```
1. Agente completa su gate
2. Registra controles verificados en audit trail (co-cli.sh audit append)
3. Al cerrar (G9), @jarvis ejecuta auditoría completa
4. Genera reportes y verifica completitud
5. Push al journal repo
```
