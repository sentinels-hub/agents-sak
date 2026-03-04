/**
 * Dashboard View — Overview de todos los proyectos y métricas
 */
const Dashboard = {
  render() {
    const data = DEMO_DATA;
    const totalWPs = data.workPackages.length;
    const closedWPs = data.workPackages.filter(wp => wp.status === 'Closed' || wp.status === 'Done').length;
    const inProgressWPs = data.workPackages.filter(wp => wp.status === 'In progress').length;
    const totalHours = data.workPackages.reduce((sum, wp) => sum + wp.hours, 0);

    return `
      <h1 class="main__title">DASHBOARD</h1>
      <p class="main__subtitle">Vista general del ecosistema Sentinels</p>

      <!-- Stats Row -->
      <div class="stat-row">
        <div class="stat-card">
          <div class="stat-card__value">${data.projects.length}</div>
          <div class="stat-card__label">Proyectos Activos</div>
        </div>
        <div class="stat-card stat-card--green">
          <div class="stat-card__value">${closedWPs}/${totalWPs}</div>
          <div class="stat-card__label">WPs Completados</div>
        </div>
        <div class="stat-card stat-card--purple">
          <div class="stat-card__value">${inProgressWPs}</div>
          <div class="stat-card__label">En Progreso</div>
        </div>
        <div class="stat-card stat-card--yellow">
          <div class="stat-card__value">${totalHours}h</div>
          <div class="stat-card__label">Horas Estimadas</div>
        </div>
      </div>

      <!-- Projects -->
      <div class="card-grid">
        ${data.projects.map(p => `
          <div class="card">
            <div class="card__header">
              <span class="card__title">${escapeHtml(p.name)}</span>
              ${badge(p.status)}
            </div>
            <div style="margin-bottom: 8px;">
              <span style="color: var(--hud-text-dim); font-size: 12px;">
                ${escapeHtml(p.version)} &mdash; ${p.wpClosed}/${p.wpTotal} WPs
              </span>
            </div>
            ${progressBar(p.progress)}
            <div style="text-align: right; font-size: 11px; color: var(--hud-text-dim); margin-top: 4px;">
              ${p.progress}%
            </div>
          </div>
        `).join('')}
      </div>

      <!-- Contracts & Gates -->
      <div class="table-container">
        <div class="table-container__title">Contratos Activos — Gate Pipeline</div>
        <div style="padding: 16px;">
          ${data.contracts.map(c => `
            <div style="margin-bottom: 16px;">
              <div style="font-size: 13px; color: var(--hud-text-bright); margin-bottom: 8px;">
                ${escapeHtml(c.id)}
                <span style="color: var(--hud-text-dim); font-size: 11px; margin-left: 8px;">${escapeHtml(c.project)}</span>
              </div>
              ${gatePipeline(c.gates)}
            </div>
          `).join('')}
        </div>
      </div>

      <!-- Recent WPs Table -->
      <div class="table-container">
        <div class="table-container__title">Work Packages Recientes</div>
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Tipo</th>
              <th>Subject</th>
              <th>Estado</th>
              <th>Version</th>
              <th>Horas</th>
              <th>Agente</th>
            </tr>
          </thead>
          <tbody>
            ${data.workPackages.slice(0, 8).map(wp => `
              <tr>
                <td style="color: var(--hud-accent);">#${wp.id}</td>
                <td style="color: var(--hud-text-dim);">${escapeHtml(wp.type)}</td>
                <td>${escapeHtml(wp.subject)}</td>
                <td>${badge(wp.status)}</td>
                <td>${escapeHtml(wp.version)}</td>
                <td>${wp.hours}h</td>
                <td style="color: var(--hud-accent-purple);">${escapeHtml(wp.agent)}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;
  }
};
