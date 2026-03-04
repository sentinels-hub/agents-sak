/**
 * Queries View — Colas de trabajo por agente
 */
const Queries = {
  render() {
    const agents = [
      {
        name: '@jarvis',
        gates: 'G0, G1, G8, G9',
        color: 'var(--hud-accent-green)',
        queries: [
          { name: 'Contratos por inicializar', count: 1, priority: 'Normal' },
          { name: 'Pendiente de cierre', count: 0, priority: '—' },
          { name: 'Proyectos at risk', count: 1, priority: 'High' },
        ]
      },
      {
        name: '@inception',
        gates: 'G2',
        color: 'var(--hud-accent)',
        queries: [
          { name: 'Backlog sin planificar', count: 2, priority: 'High' },
          { name: 'Sin estimación', count: 3, priority: 'Normal' },
          { name: 'Sin campos de orquestación', count: 4, priority: 'Normal' },
        ]
      },
      {
        name: '@gtd',
        gates: 'G3',
        color: 'var(--hud-accent-purple)',
        queries: [
          { name: 'Tareas pendientes', count: 5, priority: 'High' },
          { name: 'En progreso', count: 2, priority: 'Normal' },
          { name: 'Bloqueados', count: 1, priority: 'Urgent' },
        ]
      },
      {
        name: '@morpheus',
        gates: 'G4',
        color: 'var(--hud-accent-yellow)',
        queries: [
          { name: 'Pendiente de security analysis', count: 1, priority: 'High' },
          { name: 'Riesgo alto sin mitigación', count: 0, priority: '—' },
        ]
      },
      {
        name: '@agent-smith',
        gates: 'G5',
        color: 'var(--hud-accent-red)',
        queries: [
          { name: 'Pendiente de review', count: 1, priority: 'High' },
          { name: 'Reviews con findings abiertos', count: 0, priority: '—' },
        ]
      },
      {
        name: '@oracle',
        gates: 'G6',
        color: 'var(--hud-accent)',
        queries: [
          { name: 'Pendiente de QA', count: 0, priority: '—' },
          { name: 'Test failures', count: 0, priority: '—' },
        ]
      },
      {
        name: '@pepper',
        gates: 'G7',
        color: 'var(--hud-accent-green)',
        queries: [
          { name: 'Pendiente de deploy', count: 0, priority: '—' },
        ]
      },
      {
        name: '@ariadne',
        gates: 'G8',
        color: 'var(--hud-accent-purple)',
        queries: [
          { name: 'Pendiente de evidence', count: 0, priority: '—' },
        ]
      },
    ];

    const totalPending = agents.reduce((sum, a) => sum + a.queries.reduce((s, q) => s + q.count, 0), 0);
    const activeAgents = agents.filter(a => a.queries.some(q => q.count > 0)).length;

    return `
      <h1 class="main__title">WORK QUEUES</h1>
      <p class="main__subtitle">Colas de trabajo por agente — orquestacion activa via OpenProject queries</p>

      <div class="stat-row">
        <div class="stat-card">
          <div class="stat-card__value">${totalPending}</div>
          <div class="stat-card__label">Items en Cola</div>
        </div>
        <div class="stat-card stat-card--green">
          <div class="stat-card__value">${activeAgents}/${agents.length}</div>
          <div class="stat-card__label">Agentes con Trabajo</div>
        </div>
        <div class="stat-card stat-card--yellow">
          <div class="stat-card__value">${agents.reduce((s, a) => s + a.queries.filter(q => q.priority === 'Urgent').length, 0)}</div>
          <div class="stat-card__label">Items Urgentes</div>
        </div>
        <div class="stat-card stat-card--purple">
          <div class="stat-card__value">${agents.reduce((s, a) => s + a.queries.filter(q => q.count > 0 && q.priority === 'High').length, 0)}</div>
          <div class="stat-card__label">Items High Priority</div>
        </div>
      </div>

      <div class="card-grid">
        ${agents.map(agent => {
          const totalItems = agent.queries.reduce((s, q) => s + q.count, 0);
          const hasWork = totalItems > 0;

          return `
            <div class="card" style="${hasWork ? 'border-color: ' + agent.color + '; box-shadow: 0 0 8px ' + agent.color + '20;' : ''}">
              <div class="card__header">
                <span class="card__title" style="color: ${agent.color};">${escapeHtml(agent.name)}</span>
                <span style="font-size: 11px; color: var(--hud-text-dim);">${agent.gates}</span>
              </div>

              <div style="margin-bottom: 12px;">
                <span style="font-size: 24px; font-weight: bold; color: ${hasWork ? agent.color : 'var(--hud-text-dim)'};">${totalItems}</span>
                <span style="font-size: 11px; color: var(--hud-text-dim); margin-left: 4px;">items en cola</span>
              </div>

              ${agent.queries.map(q => `
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 4px 0; font-size: 12px; border-top: 1px solid rgba(30,58,95,0.3);">
                  <span style="color: ${q.count > 0 ? 'var(--hud-text)' : 'var(--hud-text-dim)'};">
                    ${escapeHtml(q.name)}
                  </span>
                  <span style="display: flex; align-items: center; gap: 8px;">
                    ${q.priority !== '—' && q.count > 0 ? `<span class="badge badge--${q.priority === 'Urgent' ? 'blocked' : q.priority === 'High' ? 'review' : 'new'}" style="font-size: 9px;">${q.priority}</span>` : ''}
                    <span style="color: ${q.count > 0 ? agent.color : 'var(--hud-text-dim)'}; font-weight: bold; min-width: 20px; text-align: right;">${q.count}</span>
                  </span>
                </div>
              `).join('')}
            </div>
          `;
        }).join('')}
      </div>

      <!-- Orchestration Flow -->
      <div class="card" style="margin-top: 16px;">
        <div class="card__title" style="margin-bottom: 12px;">Flujo de Orquestacion</div>
        <div style="font-size: 12px; color: var(--hud-text-dim); line-height: 2;">
          <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
            <span class="gate gate--passed">G0</span><span style="color: var(--hud-accent-green);">@jarvis</span>
            <span class="trace-arrow">&rarr;</span>
            <span class="gate gate--passed">G1</span><span style="color: var(--hud-accent-green);">@jarvis</span>
            <span class="trace-arrow">&rarr;</span>
            <span class="gate gate--active">G2</span><span style="color: var(--hud-accent);">@inception</span>
            <span class="trace-arrow">&rarr;</span>
            <span class="gate gate--active">G3</span><span style="color: var(--hud-accent-purple);">@gtd</span>
            <span class="trace-arrow">&rarr;</span>
            <span class="gate gate--active">G4</span><span style="color: var(--hud-accent-yellow);">@morpheus</span>
            <span class="trace-arrow">&rarr;</span>
            <span class="gate gate--active">G5</span><span style="color: var(--hud-accent-red);">@agent-smith</span>
            <span class="trace-arrow">&rarr;</span>
            <span class="gate">G6</span><span>@oracle</span>
            <span class="trace-arrow">&rarr;</span>
            <span class="gate">G7</span><span>@pepper</span>
            <span class="trace-arrow">&rarr;</span>
            <span class="gate">G8</span><span>@ariadne</span>
            <span class="trace-arrow">&rarr;</span>
            <span class="gate">G9</span><span>@jarvis</span>
          </div>
        </div>
      </div>
    `;
  }
};
