/**
 * Agents View — Carga de trabajo, especialización y asignaciones
 */
const Agents = {
  render() {
    const agentData = [
      {
        name: '@jarvis', gates: 'G0, G1, G8, G9', role: 'Orquestador',
        color: 'var(--hud-accent-green)',
        specializations: ['Lifecycle', 'Identity', 'Evidence', 'Closure'],
        wpAssigned: 3, wpCompleted: 8, hoursLogged: 4.5,
        currentWork: [
          { wp: '#2525', subject: 'OpenProject Cleanup', status: 'Closed', gate: 'G9' },
        ]
      },
      {
        name: '@inception', gates: 'G2', role: 'Planificador',
        color: 'var(--hud-accent)',
        specializations: ['Planning', 'Requirements', 'Estimation', 'Routing'],
        wpAssigned: 4, wpCompleted: 6, hoursLogged: 8.0,
        currentWork: [
          { wp: '#2002', subject: 'SAK Web UI planning', status: 'In specification', gate: 'G2' },
          { wp: '#2005', subject: 'Lighthouse v2.1 scope', status: 'New', gate: 'G2' },
        ]
      },
      {
        name: '@gtd', gates: 'G3', role: 'Implementador',
        color: 'var(--hud-accent-purple)',
        specializations: ['Frontend', 'Backend', 'Full-stack', 'DevOps'],
        wpAssigned: 7, wpCompleted: 15, hoursLogged: 32.5,
        currentWork: [
          { wp: '#2001', subject: 'OpenProject catalog', status: 'In progress', gate: 'G3' },
          { wp: '#1914', subject: 'Navigation system', status: 'In progress', gate: 'G3' },
          { wp: '#1916', subject: 'Section layouts', status: 'In specification', gate: 'G3' },
        ]
      },
      {
        name: '@morpheus', gates: 'G4', role: 'Security Analyst',
        color: 'var(--hud-accent-yellow)',
        specializations: ['SAST', 'CVE', 'Secrets', 'Threat Surface'],
        wpAssigned: 1, wpCompleted: 3, hoursLogged: 4.0,
        currentWork: [
          { wp: '#1889', subject: 'HUD theme security scan', status: 'Developed', gate: 'G4' },
        ]
      },
      {
        name: '@agent-smith', gates: 'G5', role: 'Code Reviewer',
        color: 'var(--hud-accent-red)',
        specializations: ['Security Review', 'Bug Detection', 'Design Alignment', 'Quality'],
        wpAssigned: 1, wpCompleted: 2, hoursLogged: 3.0,
        currentWork: [
          { wp: '#1889', subject: 'HUD theme code review', status: 'In security analysis', gate: 'G5' },
        ]
      },
      {
        name: '@oracle', gates: 'G6', role: 'QA + Compliance',
        color: 'var(--hud-accent)',
        specializations: ['Functional QA', 'ISO 27001', 'ISO 9001', 'SOC2', 'ENS Alta'],
        wpAssigned: 0, wpCompleted: 2, hoursLogged: 5.0,
        currentWork: []
      },
      {
        name: '@pepper', gates: 'G7', role: 'Deployment',
        color: 'var(--hud-accent-green)',
        specializations: ['Build Pipeline', 'Deploy', 'Health Checks', 'Rollback'],
        wpAssigned: 0, wpCompleted: 1, hoursLogged: 1.5,
        currentWork: []
      },
      {
        name: '@ariadne', gates: 'G8', role: 'Evidence + Release',
        color: 'var(--hud-accent-purple)',
        specializations: ['Changelog', 'Release Notes', 'Bundle Manifest', 'Ledger'],
        wpAssigned: 0, wpCompleted: 1, hoursLogged: 2.0,
        currentWork: []
      },
    ];

    const totalAssigned = agentData.reduce((s, a) => s + a.wpAssigned, 0);
    const totalCompleted = agentData.reduce((s, a) => s + a.wpCompleted, 0);
    const totalHours = agentData.reduce((s, a) => s + a.hoursLogged, 0);

    return `
      <h1 class="main__title">AGENTS</h1>
      <p class="main__subtitle">Carga de trabajo, especializacion y asignaciones por agente</p>

      <div class="stat-row">
        <div class="stat-card">
          <div class="stat-card__value">${agentData.length}</div>
          <div class="stat-card__label">Agentes Activos</div>
        </div>
        <div class="stat-card stat-card--purple">
          <div class="stat-card__value">${totalAssigned}</div>
          <div class="stat-card__label">WPs Asignados</div>
        </div>
        <div class="stat-card stat-card--green">
          <div class="stat-card__value">${totalCompleted}</div>
          <div class="stat-card__label">WPs Completados</div>
        </div>
        <div class="stat-card stat-card--yellow">
          <div class="stat-card__value">${totalHours}h</div>
          <div class="stat-card__label">Horas Registradas</div>
        </div>
      </div>

      <!-- Agent Cards -->
      ${agentData.map(agent => {
        const utilization = agent.wpAssigned > 0 ? Math.min(100, Math.round(agent.wpAssigned / 5 * 100)) : 0;
        return `
          <div class="card" style="margin-bottom: 16px; ${agent.wpAssigned > 0 ? 'border-left: 3px solid ' + agent.color + ';' : ''}">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px;">
              <div>
                <div style="font-size: 16px; font-weight: bold; color: ${agent.color};">${escapeHtml(agent.name)}</div>
                <div style="font-size: 11px; color: var(--hud-text-dim);">${escapeHtml(agent.role)} — ${agent.gates}</div>
              </div>
              <div style="text-align: right;">
                <div style="font-size: 11px; color: var(--hud-text-dim);">CARGA</div>
                ${progressBar(utilization)}
                <div style="font-size: 11px; color: var(--hud-text-dim); margin-top: 2px;">${agent.wpAssigned} asignados</div>
              </div>
            </div>

            <!-- Specializations -->
            <div style="margin-bottom: 12px;">
              ${agent.specializations.map(s => `<span style="display: inline-block; padding: 2px 8px; margin: 2px; border: 1px solid ${agent.color}30; border-radius: 3px; font-size: 10px; color: ${agent.color};">${escapeHtml(s)}</span>`).join('')}
            </div>

            <!-- Stats -->
            <div style="display: flex; gap: 24px; font-size: 12px; margin-bottom: 12px;">
              <span><span style="color: var(--hud-accent-green); font-weight: bold;">${agent.wpCompleted}</span> completados</span>
              <span><span style="color: var(--hud-accent-yellow); font-weight: bold;">${agent.hoursLogged}h</span> registradas</span>
            </div>

            ${agent.currentWork.length > 0 ? `
              <div style="border-top: 1px solid var(--hud-border); padding-top: 8px;">
                <div style="font-size: 10px; text-transform: uppercase; letter-spacing: 1px; color: var(--hud-text-dim); margin-bottom: 6px;">Trabajo actual</div>
                ${agent.currentWork.map(w => `
                  <div style="display: flex; justify-content: space-between; align-items: center; padding: 4px 0; font-size: 12px;">
                    <span>
                      <span style="color: var(--hud-accent);">${escapeHtml(w.wp)}</span>
                      ${escapeHtml(w.subject)}
                    </span>
                    <span style="display: flex; gap: 6px; align-items: center;">
                      ${badge(w.status)}
                      <span class="gate gate--active">${w.gate}</span>
                    </span>
                  </div>
                `).join('')}
              </div>
            ` : `
              <div style="border-top: 1px solid var(--hud-border); padding-top: 8px; font-size: 12px; color: var(--hud-text-dim);">
                Sin trabajo asignado — disponible
              </div>
            `}
          </div>
        `;
      }).join('')}

      <!-- Orchestration Matrix -->
      <div class="table-container" style="margin-top: 16px;">
        <div class="table-container__title">Matriz de Especializacion vs. Dificultad</div>
        <table>
          <thead>
            <tr>
              <th>Specialization</th>
              <th>Trivial</th>
              <th>Easy</th>
              <th>Medium</th>
              <th>Hard</th>
              <th>Expert</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Frontend</td>
              <td style="color: var(--hud-accent-purple);">@gtd</td>
              <td style="color: var(--hud-accent-purple);">@gtd</td>
              <td style="color: var(--hud-accent-purple);">@gtd</td>
              <td style="color: var(--hud-accent-purple);">@gtd</td>
              <td style="color: var(--hud-accent-yellow);">@gtd + Human</td>
            </tr>
            <tr>
              <td>Backend</td>
              <td style="color: var(--hud-accent-purple);">@gtd</td>
              <td style="color: var(--hud-accent-purple);">@gtd</td>
              <td style="color: var(--hud-accent-purple);">@gtd</td>
              <td style="color: var(--hud-accent-purple);">@gtd</td>
              <td style="color: var(--hud-accent-yellow);">@gtd + Human</td>
            </tr>
            <tr>
              <td>Security</td>
              <td style="color: var(--hud-accent-yellow);">@morpheus</td>
              <td style="color: var(--hud-accent-yellow);">@morpheus</td>
              <td style="color: var(--hud-accent-yellow);">@morpheus</td>
              <td style="color: var(--hud-accent-yellow);">@morpheus</td>
              <td style="color: var(--hud-accent-red);">@morpheus + Human</td>
            </tr>
            <tr>
              <td>QA</td>
              <td style="color: var(--hud-accent);">@oracle</td>
              <td style="color: var(--hud-accent);">@oracle</td>
              <td style="color: var(--hud-accent);">@oracle</td>
              <td style="color: var(--hud-accent);">@oracle</td>
              <td style="color: var(--hud-accent-red);">@oracle + Human</td>
            </tr>
            <tr>
              <td>DevOps</td>
              <td style="color: var(--hud-accent-green);">@pepper</td>
              <td style="color: var(--hud-accent-green);">@pepper</td>
              <td style="color: var(--hud-accent-green);">@pepper</td>
              <td style="color: var(--hud-accent-green);">@pepper</td>
              <td style="color: var(--hud-accent-red);">@pepper + Human</td>
            </tr>
          </tbody>
        </table>
      </div>
    `;
  }
};
