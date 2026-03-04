/**
 * Backlog View — Work Packages organizados por versión
 */
const Backlog = {
  render() {
    const data = DEMO_DATA;
    const versions = data.versions.filter(v => v.status === 'open');

    // Group WPs by version
    const wpsByVersion = {};
    data.workPackages.forEach(wp => {
      const key = `${wp.project}|${wp.version}`;
      if (!wpsByVersion[key]) wpsByVersion[key] = [];
      wpsByVersion[key].push(wp);
    });

    return `
      <h1 class="main__title">BACKLOG</h1>
      <p class="main__subtitle">Work Packages organizados por version e iteracion</p>

      <!-- Version Backlogs -->
      ${versions.map(v => {
        const key = `${v.project}|${v.name}`;
        const wps = wpsByVersion[key] || [];
        const closed = wps.filter(wp => wp.status === 'Closed' || wp.status === 'Done').length;
        const totalHours = wps.reduce((sum, wp) => sum + wp.hours, 0);

        return `
          <div class="table-container" style="margin-bottom: 24px;">
            <div class="table-container__title" style="display: flex; justify-content: space-between; align-items: center;">
              <span>
                ${escapeHtml(v.project)} / ${escapeHtml(v.name)}
                <span style="color: var(--hud-text-dim); font-size: 11px; margin-left: 8px;">
                  ${escapeHtml(v.start)} &rarr; ${escapeHtml(v.end)}
                </span>
              </span>
              <span style="font-size: 11px;">
                <span style="color: var(--hud-accent-green);">${closed}</span>/<span>${wps.length}</span> WPs
                &mdash; ${totalHours}h est.
              </span>
            </div>
            <div style="padding: 8px 16px;">
              ${progressBar(v.progress)}
              <div style="text-align: right; font-size: 11px; color: var(--hud-text-dim); margin-top: 4px;">
                ${v.progress}% completado
              </div>
            </div>
            ${wps.length > 0 ? `
              <table>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Tipo</th>
                    <th>Subject</th>
                    <th>Estado</th>
                    <th>Horas</th>
                    <th>Gate</th>
                    <th>Agente</th>
                  </tr>
                </thead>
                <tbody>
                  ${wps.map(wp => `
                    <tr>
                      <td style="color: var(--hud-accent);">#${wp.id}</td>
                      <td style="color: var(--hud-text-dim);">${escapeHtml(wp.type)}</td>
                      <td>${escapeHtml(wp.subject)}</td>
                      <td>${badge(wp.status)}</td>
                      <td>${wp.hours}h</td>
                      <td><span class="gate gate--${wp.gate === 'G9' ? 'passed' : 'active'}">${wp.gate}</span></td>
                      <td style="color: var(--hud-accent-purple);">${escapeHtml(wp.agent)}</td>
                    </tr>
                  `).join('')}
                </tbody>
              </table>
            ` : `
              <div class="empty-state">
                <div class="empty-state__icon">[ ]</div>
                <div class="empty-state__text">No hay Work Packages en esta version</div>
              </div>
            `}
          </div>
        `;
      }).join('')}

      <!-- Unversioned (Product Backlog) -->
      <div class="table-container">
        <div class="table-container__title">
          Product Backlog
          <span style="color: var(--hud-text-dim); font-size: 11px; margin-left: 8px;">
            Sin version asignada
          </span>
        </div>
        <div class="empty-state">
          <div class="empty-state__icon">&gt;_</div>
          <div class="empty-state__text">Todos los WPs tienen version asignada</div>
        </div>
      </div>
    `;
  }
};
