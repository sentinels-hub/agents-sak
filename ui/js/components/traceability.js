/**
 * Traceability View — Cadena Git <-> OP <-> Evidence
 */
const Traceability = {
  render() {
    const data = DEMO_DATA;

    return `
      <h1 class="main__title">TRACEABILITY</h1>
      <p class="main__subtitle">Cadena de trazabilidad Git - OpenProject - Evidence</p>

      <!-- Contract Traceability -->
      ${data.contracts.map(c => {
        const t = c.traceability;
        return `
          <div class="card" style="margin-bottom: 24px;">
            <div class="card__header">
              <span class="card__title">${escapeHtml(c.id)}</span>
              <span style="color: var(--hud-text-dim); font-size: 12px;">${escapeHtml(c.project)}</span>
            </div>

            <!-- Gate Pipeline -->
            <div style="margin-bottom: 16px;">
              ${gatePipeline(c.gates)}
            </div>

            <!-- Traceability Chain -->
            <div style="margin-bottom: 16px;">
              <div style="font-size: 11px; color: var(--hud-text-dim); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px;">
                Cadena de trazabilidad
              </div>
              <div class="trace-chain">
                <span class="trace-node ${t.contract ? 'trace-node--linked' : 'trace-node--missing'}">Contract</span>
                <span class="trace-arrow">&rarr;</span>
                <span class="trace-node ${t.wp ? 'trace-node--linked' : 'trace-node--missing'}">WP</span>
                <span class="trace-arrow">&rarr;</span>
                <span class="trace-node ${t.branch ? 'trace-node--linked' : 'trace-node--missing'}">Branch</span>
                <span class="trace-arrow">&rarr;</span>
                <span class="trace-node ${t.commits ? 'trace-node--linked' : 'trace-node--missing'}">Commits</span>
                <span class="trace-arrow">&rarr;</span>
                <span class="trace-node ${t.pr ? 'trace-node--linked' : 'trace-node--missing'}">PR</span>
                <span class="trace-arrow">&rarr;</span>
                <span class="trace-node ${t.evidence ? 'trace-node--linked' : 'trace-node--missing'}">Evidence</span>
                <span class="trace-arrow">&rarr;</span>
                <span class="trace-node ${t.ledger ? 'trace-node--linked' : 'trace-node--missing'}">Ledger</span>
              </div>
            </div>

            <!-- Traceability Score -->
            <div style="display: flex; align-items: center; gap: 12px;">
              <span style="font-size: 11px; color: var(--hud-text-dim);">COMPLETITUD:</span>
              <div style="flex: 1;">
                ${progressBar(Math.round(Object.values(t).filter(Boolean).length / Object.values(t).length * 100))}
              </div>
              <span style="font-size: 13px; color: var(--hud-accent);">
                ${Object.values(t).filter(Boolean).length}/${Object.values(t).length}
              </span>
            </div>
          </div>
        `;
      }).join('')}

      <!-- Traceability Matrix -->
      <div class="table-container">
        <div class="table-container__title">Matriz de Trazabilidad por Work Package</div>
        <table>
          <thead>
            <tr>
              <th>WP</th>
              <th>Subject</th>
              <th>Contract</th>
              <th>Branch</th>
              <th>Commit</th>
              <th>PR</th>
              <th>Evidence</th>
              <th>Score</th>
            </tr>
          </thead>
          <tbody>
            ${data.workPackages.filter(wp => wp.type === 'User story' || wp.type === 'Epic').map(wp => {
              // Simulate traceability based on gate progression
              const gateNum = parseInt(wp.gate.replace('G', ''));
              const hasContract = gateNum >= 0;
              const hasBranch = gateNum >= 3;
              const hasCommit = gateNum >= 3;
              const hasPR = gateNum >= 5;
              const hasEvidence = gateNum >= 8;
              const fields = [hasContract, hasBranch, hasCommit, hasPR, hasEvidence];
              const score = fields.filter(Boolean).length;

              return `
                <tr>
                  <td style="color: var(--hud-accent);">#${wp.id}</td>
                  <td>${escapeHtml(wp.subject)}</td>
                  <td>${hasContract ? '<span style="color: var(--hud-accent-green);">OK</span>' : '<span style="color: var(--hud-accent-red);">--</span>'}</td>
                  <td>${hasBranch ? '<span style="color: var(--hud-accent-green);">OK</span>' : '<span style="color: var(--hud-accent-red);">--</span>'}</td>
                  <td>${hasCommit ? '<span style="color: var(--hud-accent-green);">OK</span>' : '<span style="color: var(--hud-accent-red);">--</span>'}</td>
                  <td>${hasPR ? '<span style="color: var(--hud-accent-green);">OK</span>' : '<span style="color: var(--hud-accent-red);">--</span>'}</td>
                  <td>${hasEvidence ? '<span style="color: var(--hud-accent-green);">OK</span>' : '<span style="color: var(--hud-accent-red);">--</span>'}</td>
                  <td>
                    <span style="color: ${score >= 4 ? 'var(--hud-accent-green)' : score >= 2 ? 'var(--hud-accent-yellow)' : 'var(--hud-accent-red)'};">
                      ${score}/5
                    </span>
                  </td>
                </tr>
              `;
            }).join('')}
          </tbody>
        </table>
      </div>

      <!-- Traceability Rules -->
      <div class="card" style="margin-top: 16px;">
        <div class="card__title" style="margin-bottom: 12px;">Reglas de Trazabilidad Sentinels</div>
        <div style="font-size: 12px; color: var(--hud-text-dim); line-height: 1.8;">
          <div><span style="color: var(--hud-accent);">1.</span> Todo WP debe tener contract_id (User Stories obligatorio)</div>
          <div><span style="color: var(--hud-accent);">2.</span> Branch naming: feat/wp-&lt;ID&gt;-&lt;desc&gt;</div>
          <div><span style="color: var(--hud-accent);">3.</span> Commit format: type(scope): desc [WP#ID]</div>
          <div><span style="color: var(--hud-accent);">4.</span> Evidence bundle con SHA-256 y hash chain</div>
          <div><span style="color: var(--hud-accent);">5.</span> No closure (G9) sin cadena completa</div>
        </div>
      </div>
    `;
  }
};
