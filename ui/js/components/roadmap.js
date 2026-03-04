/**
 * Roadmap View — Timeline de versiones con progreso
 */
const Roadmap = {
  render() {
    const data = DEMO_DATA;

    // Group versions by project
    const versionsByProject = {};
    data.versions.forEach(v => {
      if (!versionsByProject[v.project]) versionsByProject[v.project] = [];
      versionsByProject[v.project].push(v);
    });

    // Count WPs per version
    const wpCountByVersion = {};
    data.workPackages.forEach(wp => {
      const key = `${wp.project}|${wp.version}`;
      if (!wpCountByVersion[key]) wpCountByVersion[key] = { total: 0, closed: 0, hours: 0 };
      wpCountByVersion[key].total++;
      wpCountByVersion[key].hours += wp.hours;
      if (wp.status === 'Closed' || wp.status === 'Done') wpCountByVersion[key].closed++;
    });

    return `
      <h1 class="main__title">ROADMAP</h1>
      <p class="main__subtitle">Planificacion temporal de versiones y progreso</p>

      ${Object.entries(versionsByProject).map(([project, versions]) => `
        <div style="margin-bottom: 32px;">
          <h2 style="color: var(--hud-accent); font-size: 15px; margin-bottom: 16px; text-transform: uppercase; letter-spacing: 2px;">
            ${escapeHtml(project)}
          </h2>

          <div class="timeline">
            ${versions.map(v => {
              const key = `${v.project}|${v.name}`;
              const counts = wpCountByVersion[key] || { total: 0, closed: 0, hours: 0 };
              const itemClass = v.progress >= 100 ? 'complete' :
                               v.progress > 0 ? 'active' : '';

              return `
                <div class="timeline__item timeline__item--${itemClass}">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                    <div>
                      <div class="timeline__version">${escapeHtml(v.name)}</div>
                      <div class="timeline__dates">${escapeHtml(v.start)} &rarr; ${escapeHtml(v.end)}</div>
                    </div>
                    <span class="badge badge--${v.status === 'closed' ? 'closed' : v.status === 'locked' ? 'review' : 'new'}">${escapeHtml(v.status)}</span>
                  </div>

                  <div style="margin: 12px 0;">
                    ${progressBar(v.progress)}
                    <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--hud-text-dim); margin-top: 4px;">
                      <span>${counts.closed}/${counts.total} WPs</span>
                      <span>${counts.hours}h estimadas</span>
                      <span>${v.progress}%</span>
                    </div>
                  </div>

                  ${counts.total > 0 ? `
                    <div style="display: flex; gap: 16px; font-size: 11px;">
                      <span style="color: var(--hud-accent-green);">Closed: ${counts.closed}</span>
                      <span style="color: var(--hud-accent-purple);">Open: ${counts.total - counts.closed}</span>
                    </div>
                  ` : `
                    <div style="font-size: 11px; color: var(--hud-text-dim);">Sin WPs asignados</div>
                  `}
                </div>
              `;
            }).join('')}
          </div>
        </div>
      `).join('')}

      <!-- KPIs -->
      <div class="table-container">
        <div class="table-container__title">KPIs del Roadmap</div>
        <table>
          <thead>
            <tr>
              <th>KPI</th>
              <th>Target</th>
              <th>Actual</th>
              <th>Estado</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Trazabilidad completa</td>
              <td>&ge;95%</td>
              <td style="color: var(--hud-accent-green);">87%</td>
              <td>${badge('In progress')}</td>
            </tr>
            <tr>
              <td>PRs con evidencia</td>
              <td>&ge;95%</td>
              <td style="color: var(--hud-accent-green);">100%</td>
              <td>${badge('Closed')}</td>
            </tr>
            <tr>
              <td>Releases con checklist</td>
              <td>100%</td>
              <td style="color: var(--hud-accent-yellow);">75%</td>
              <td>${badge('In review')}</td>
            </tr>
            <tr>
              <td>Ratio reapertura</td>
              <td>Monitored</td>
              <td style="color: var(--hud-accent-green);">0%</td>
              <td>${badge('Closed')}</td>
            </tr>
          </tbody>
        </table>
      </div>
    `;
  }
};
