# OpenProject — Playbooks de Agentes

Un **playbook** define exactamente cómo un agente interactúa con OpenProject: qué query ejecuta para saber qué hacer, cómo procesa cada WP, y cómo deja el estado para el siguiente agente.

## Flujo universal

```
1. LEER    → Ejecutar query principal → obtener cola de trabajo
2. EVALUAR → Verificar relaciones (blocked?) → seleccionar WP
3. LEER    → Leer campos del WP (difficulty, specialization, tech stack)
4. ACTUAR  → Ejecutar el trabajo del gate
5. ESCRIBIR → Actualizar WP (status, campos, comentario governance)
6. REPETIR → Re-ejecutar query → siguiente WP
7. REPORTAR → Cuando cola vacía → reportar turno completado
```

## Playbooks disponibles

| Agente | Gates | Playbook |
|--------|-------|----------|
| @jarvis | G0, G1, G8, G9 | [jarvis.md](jarvis.md) — Orquestador del ciclo de vida |
| @inception | G2 | [inception.md](inception.md) — Planificador |
| @gtd | G3 | [gtd.md](gtd.md) — Implementador |
| @morpheus | G4 | [morpheus.md](morpheus.md) — Analista de seguridad |
| @agent-smith | G5 | [agent-smith.md](agent-smith.md) — Revisor de código |
| @oracle | G6 | [oracle.md](oracle.md) — QA + Compliance |
| @pepper | G7 | [pepper.md](pepper.md) — Deployment |
| @ariadne | G8 | [ariadne.md](ariadne.md) — Evidence + Release |

## Principio de diseño

> **El agente NO decide qué hacer. OpenProject le dice qué hacer.**
>
> La query es el punto de entrada. Los campos del WP son las instrucciones.
> Las relaciones son las restricciones. El status es el resultado.
