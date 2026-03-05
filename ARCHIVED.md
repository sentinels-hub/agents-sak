# agents-sak — ARCHIVED

> **Status:** Archived — All valuable content migrated to [sentinels-labyrinth](https://github.com/sentinels-hub/sentinels-labyrinth)
> **Date:** 2026-03-06
> **Migrated by:** Claude Opus 4.6

## Migration Summary

agents-sak was the exploratory toolkit that validated tooling ideas for Sentinels agents. Its value has been absorbed into sentinels-labyrinth:

- **MCP Plugin System** replaces all CLI scripts
- **Labyrinth fixtures** contain all catalogs and templates
- **5 new MCP tools** port the cross-tool intelligence

## What Went Where

### Catalogs → `sentinels-labyrinth/backend/fixtures/governance/`

| Source | Destination | Files |
|---|---|---|
| `tools/openproject/catalog/*.md` | `playbooks/openproject/catalog/` | 11 files |
| `tools/github/catalog/*.md` | `playbooks/github/catalog/` | 6 files |

### Templates → `sentinels-labyrinth/backend/fixtures/governance/templates/`

| Source | Destination | Files |
|---|---|---|
| `tools/openproject/templates/*.md` | `templates/openproject/` | 3 files |
| `tools/github/templates/*.md` | `templates/github/` | 2 files |
| `tools/evidence/templates/*.md` | `templates/evidence/` | 2 files |
| `tools/compliance/templates/*.md` | `templates/compliance/` | 9 files total |

### Script Logic → `sentinels-labyrinth/backend/apps/mcp/handlers/`

| Source Script | New MCP Tool | Handler |
|---|---|---|
| `op-core.sh` (field resolution) | `labyrinth.op.work_packages.set_orchestration` | `handlers/openproject.py` |
| `gh-core.sh` (validation) | `labyrinth.github.validate` | `handlers/github.py` |
| `sak-trace.sh` (10 checks) | `labyrinth.trace.verify` | `handlers/intelligence.py` |
| `sak-gates.sh` (DAG prereqs) | `labyrinth.gates.check_ready` | `handlers/intelligence.py` |
| `sak-metrics.sh` (analytics) | `labyrinth.metrics.summary` | `handlers/intelligence.py` |

### Not Migrated (Redundant)

| Content | Reason |
|---|---|
| Playbooks | Inferior to Labyrinth agent prompts (300-800 lines each) |
| CLI scripts (`sak-cli.sh`, `op-cli.sh`, etc.) | Replaced by 40 MCP tools |
| UI Dashboard | Non-functional prototype |
| Setup scripts | Labyrinth uses Docker Compose |
| Evidence/Compliance catalogs | Redundant with existing MCP tools |

## Labyrinth MCP Tool Count

- **35 original** tools (contracts, evidence, agents, compliance, policy, projects, integrations)
- **5 new** tools migrated from SAK intelligence
- **40 total** tools in the plugin registry
