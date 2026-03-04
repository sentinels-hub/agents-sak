# Template: Planning Tree

Estructura para planificar el árbol de Work Packages de un proyecto.

## Template

```
Epic #[ID]: [Título del Epic]
│   Versión: [vX.Y.Z]
│   Estimación total: [N]h
│
├── Feature #[ID]: [Título de la Feature]
│   │
│   └── User Story #[ID]: [Título de la US]
│       │   Contract: [CTR-xxx-YYYYMMDD]
│       │   Versión: [vX.Y.Z]
│       │   Estimación: [N]h
│       │   Prioridad: [Normal/High/Urgent/Immediate]
│       │
│       ├── Task #[ID]: [Título] ([N]h)
│       ├── Task #[ID]: [Título] ([N]h)
│       └── Task #[ID]: [Título] ([N]h)
│
├── Feature #[ID]: [Título de la Feature]
│   │
│   └── User Story #[ID]: [Título de la US]
│       │   Contract: [CTR-xxx-YYYYMMDD]
│       │   Versión: [vX.Y.Z]
│       │   Estimación: [N]h
│       │
│       ├── Task #[ID]: [Título] ([N]h)
│       └── Task #[ID]: [Título] ([N]h)
│
└── Milestone #[ID]: [Nombre del hito]
        Fecha: [YYYY-MM-DD]
```

## Ejemplo: Sentinels Hub v0.1.0

```
Epic #1837: Sentinels Hub
│   Versión: v0.1.0
│   Estimación total: 14h
│
├── Feature #1881: HUD Theme & Base Layout
│   │
│   └── User Story #1889: Implement HUD theme base
│       │   Contract: CTR-sentinels-hub-20260302
│       │   Versión: v0.1.0
│       │   Estimación: 8h
│       │   Prioridad: High
│       │
│       ├── Task #1897: Create file structure (0.5h)
│       ├── Task #1899: CSS variables & reset (1.0h)
│       ├── Task #1901: Base components (1.5h)
│       ├── Task #1903: HUD animations (1.0h)
│       ├── Task #1905: Responsive breakpoints (1.0h)
│       ├── Task #1914: Navigation system (1.0h)
│       ├── Task #1916: Section layouts (0.5h)
│       └── Task #1918: Integration & polish (1.5h)
│
├── Feature #1883: Landing Page & Navigation
│   │
│   └── User Story #1891: Create landing page
│       │   Contract: CTR-sentinels-hub-20260302
│       │   Versión: v0.1.0
│       │   Estimación: 6h
│       │   Prioridad: Normal
│       │
│       ├── Task #1907: Header with nav (1.0h)
│       ├── Task #1909: Hero section (1.0h)
│       ├── Task #1911: Content sections (2.0h)
│       └── Task #1913: Footer & polish (2.0h)
│
└── Milestone: v0.1.0 Release
        Fecha: 2026-03-14
```

## Secuencia de creación en OP

```bash
# 1. Crear Epic
openproject-sync.sh create-story <PROJECT> "Sentinels Hub" "## Contexto\n..." <STATUS_NEW> <VERSION_ID>
# → Devuelve EPIC_ID

# 2. Crear Features como hijas del Epic
openproject-sync.sh create-child <EPIC_ID> "Feature" "HUD Theme & Base Layout"

# 3. Crear User Stories como hijas de Features
openproject-sync.sh create-child <FEATURE_ID> "User story" "Implement HUD theme base" "## Contexto\n..."

# 4. Asignar contract_id a User Stories
openproject-sync.sh set-contract-id <US_ID> "CTR-sentinels-hub-20260302"

# 5. Crear Tasks como hijas de User Stories
openproject-sync.sh create-child <US_ID> "Task" "Create file structure"
openproject-sync.sh create-child <US_ID> "Task" "CSS variables & reset"
# ... etc

# 6. Estimar cada Task
openproject-sync.sh estimate <TASK_1_ID> 0.5
openproject-sync.sh estimate <TASK_2_ID> 1.0
# ... etc

# 7. Propagar versión del Epic a todos los descendientes
openproject-sync.sh propagate-version <EPIC_ID>

# 8. Validar
openproject-sync.sh validate <US_ID>
```

## Checklist de planificación

- [ ] Epic creado con descripción completa
- [ ] Features creadas como hijas del Epic
- [ ] User Stories creadas con contract_id
- [ ] Tasks creadas como breakdown de User Stories
- [ ] Todas las Tasks estimadas en horas
- [ ] Versión asignada y propagada a todos los descendientes
- [ ] risk_summary y mitigation en cada User Story
- [ ] target_branch definido
- [ ] Validación pasada sin errores
