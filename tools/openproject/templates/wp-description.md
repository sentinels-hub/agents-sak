# Template: Descripción de Work Package

Usar este template al crear o actualizar la descripción de cualquier Work Package en OpenProject.

## Template

```markdown
## Contexto

[Descripción del contexto de negocio: por qué existe este WP, qué problema resuelve,
qué valor aporta. Incluir referencias a Epics/Features padre si aplica.]

## Plan

### Implementación
1. [Paso 1]
2. [Paso 2]
3. [Paso N]

### Riesgos
| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|------------|
| [Riesgo 1] | [Alta/Media/Baja] | [Alto/Medio/Bajo] | [Medida] |

### Dependencias
- [WP#XXXX — Descripción de la dependencia]

### Criterios de aceptación
- [ ] [AC-1: Descripción]
- [ ] [AC-2: Descripción]
- [ ] [AC-N: Descripción]

### Definition of Done
- [ ] Código implementado y commiteado con referencia [WP#ID]
- [ ] Tests verificados
- [ ] Code review aprobado
- [ ] Documentación actualizada
- [ ] Evidencia registrada

## Trazabilidad Git

- **Branch**: `feat/wp-[ID]-[descripcion-corta]`
- **PR**: [pendiente | URL]
- **Commits**: [pendiente | lista de commits]

## Verificacion

### Tests
- [ ] [Test 1: qué se verifica]
- [ ] [Test 2: qué se verifica]

### Compliance
- [ ] ISO 27001: [control aplicable]
- [ ] ISO 9001: [control aplicable]

### Cierre
- [ ] Todos los AC verificados
- [ ] Evidence bundle generado
- [ ] Ledger entry publicado
```

## Ejemplo: User Story

```markdown
## Contexto

Implementar el tema HUD base para Sentinels Hub (Epic #1837, Feature #1881).
El tema define la identidad visual de toda la plataforma: colores, tipografía,
layout y componentes base en estilo HUD futurista.

## Plan

### Implementación
1. Crear estructura de archivos CSS (hud-base, hud-components, hud-animations)
2. Definir CSS variables para el tema
3. Implementar componentes base (header, nav, cards, buttons)
4. Configurar responsive breakpoints (desktop, tablet 768px, mobile 480px)

### Riesgos
| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|------------|
| Scan lines dificultan lectura | Media | Medio | Reducir opacidad a 0.01 en zonas de contenido |
| Contraste WCAG insuficiente | Baja | Alto | Usar #ffffff sobre fondos oscuros, verificar ratios |

### Criterios de aceptación
- [ ] AC-1: Tema HUD aplicado con colores y tipografía definidos
- [ ] AC-2: Layout responsive en 3 breakpoints
- [ ] AC-3: Componentes base funcionales (header, nav, cards)
- [ ] AC-4: Performance < 100ms first paint
- [ ] AC-5: Zero dependencias externas

### Definition of Done
- [ ] Código implementado con commits [WP#1889]
- [ ] 30 tests verificados por @oracle
- [ ] Code review APPROVE por @agent-smith
- [ ] Documentación actualizada

## Trazabilidad Git

- **Branch**: `feat/wp-1837-sentinels-hub`
- **PR**: https://github.com/sentinels/hub/pull/1
- **Commits**: 8 commits (bfcaf7b...a1c2d3e)

## Verificacion

### Tests
- [ ] Tema carga sin errores en Chrome/Firefox/Safari
- [ ] Responsive correcto en 3 breakpoints
- [ ] Contraste WCAG AA en todos los textos
- [ ] No hay dependencias externas en network tab

### Cierre
- [ ] Todos los AC verificados
- [ ] Evidence bundle SHA-256 registrado
- [ ] Ledger entry publicado
```

## Uso por agentes

| Agente | Cuándo usa este template |
|--------|------------------------|
| @inception (G2) | Al crear WPs durante planificación |
| @gtd (G3) | Al actualizar sección "Trazabilidad Git" tras commits |
| @agent-smith (G5) | Al verificar que la descripción está completa |
| @oracle (G6) | Al verificar sección "Verificacion" |
