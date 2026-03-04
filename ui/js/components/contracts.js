/**
 * Contracts View — Vista unificada por contrato
 * Gate pipeline + trace chain + compliance scores + evidence timeline
 */
const Contracts = {
  render() {
    const data = DEMO_DATA;

    return `
      <h1 class="main__title">CONTRACTS</h1>
      <p class="main__subtitle">Vista unificada: gates, trazabilidad, compliance y evidencia por contrato</p>

      ${data.contracts.map(c => {
        const t = c.traceability;
        const gatesPassed = c.gates.filter(g => g.status === 'passed').length;
        const gatesTotal = c.gates.length;
        const traceScore = Object.values(t).filter(Boolean).length;
        const traceTotal = Object.values(t).length;

        // Compliance score (simulated from gates)
        const compliancePct = Math.round(gatesPassed / gatesTotal * 100);

        return `
          <div class="card" style="margin-bottom: 24px;">
            <div class="card__header">
              <span class="card__title">${escapeHtml(c.id)}</span>
              <span style="color: var(--hud-text-dim); font-size: 12px;">${escapeHtml(c.project)}</span>
            </div>

            <!-- Gate Pipeline -->
            <div style="margin-bottom: 16px;">
              <div style="font-size: 11px; color: var(--hud-text-dim); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px;">
                Gate Pipeline
              </div>
              ${gatePipeline(c.gates)}
              <div style="font-size: 11px; color: var(--hud-text-dim); margin-top: 4px;">
                ${gatesPassed}/${gatesTotal} gates passed
              </div>
            </div>

            <!-- Trace Chain -->
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
              <div style="display: flex; align-items: center; gap: 12px; margin-top: 8px;">
                <span style="font-size: 11px; color: var(--hud-text-dim);">CHAIN:</span>
                <div style="flex: 1;">
                  ${progressBar(Math.round(traceScore / traceTotal * 100))}
                </div>
                <span style="font-size: 13px; color: var(--hud-accent);">
                  ${traceScore}/${traceTotal}
                </span>
              </div>
            </div>

            <!-- Compliance & Evidence Summary -->
            <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; margin-bottom: 16px;">
              <div style="background: var(--hud-bg-secondary); padding: 12px; border-radius: 4px; border: 1px solid var(--hud-border);">
                <div style="font-size: 10px; color: var(--hud-text-dim); text-transform: uppercase; letter-spacing: 1px;">Compliance</div>
                <div style="font-size: 24px; font-weight: bold; color: ${compliancePct >= 80 ? 'var(--hud-accent-green)' : compliancePct >= 50 ? 'var(--hud-accent-yellow)' : 'var(--hud-accent-red)'};">
                  ${compliancePct}%
                </div>
              </div>
              <div style="background: var(--hud-bg-secondary); padding: 12px; border-radius: 4px; border: 1px solid var(--hud-border);">
                <div style="font-size: 10px; color: var(--hud-text-dim); text-transform: uppercase; letter-spacing: 1px;">Evidence</div>
                <div style="font-size: 24px; font-weight: bold; color: ${t.evidence ? 'var(--hud-accent-green)' : 'var(--hud-accent-red)'};">
                  ${t.evidence ? 'OK' : '--'}
                </div>
              </div>
              <div style="background: var(--hud-bg-secondary); padding: 12px; border-radius: 4px; border: 1px solid var(--hud-border);">
                <div style="font-size: 10px; color: var(--hud-text-dim); text-transform: uppercase; letter-spacing: 1px;">Ledger</div>
                <div style="font-size: 24px; font-weight: bold; color: ${t.ledger ? 'var(--hud-accent-green)' : 'var(--hud-accent-red)'};">
                  ${t.ledger ? 'OK' : '--'}
                </div>
              </div>
            </div>

            <!-- Gate Detail Table -->
            <div class="table-container" style="margin-top: 0;">
              <div class="table-container__title">Gate Status Detail</div>
              <table>
                <thead>
                  <tr>
                    <th>Gate</th>
                    <th>Status</th>
                    <th>Agent</th>
                    <th>Description</th>
                  </tr>
                </thead>
                <tbody>
                  ${c.gates.map(g => {
                    const gateInfo = {
                      G0: { agent: '@jarvis', desc: 'Contract initialized' },
                      G1: { agent: '@jarvis', desc: 'Identity verified' },
                      G2: { agent: '@inception', desc: 'Plan approved' },
                      G3: { agent: '@gtd', desc: 'Implementation tracked' },
                      G4: { agent: '@morpheus', desc: 'Security analysis' },
                      G5: { agent: '@agent-smith', desc: 'Code review' },
                      G6: { agent: '@oracle', desc: 'QA verification' },
                      G7: { agent: '@pepper', desc: 'Deployment' },
                      G8: { agent: '@ariadne', desc: 'Evidence export' },
                      G9: { agent: '@jarvis', desc: 'Closure' },
                    };
                    const info = gateInfo[g.name] || { agent: '?', desc: '?' };
                    const statusColor = g.status === 'passed' ? 'var(--hud-accent-green)'
                      : g.status === 'active' ? 'var(--hud-accent)'
                      : 'var(--hud-text-dim)';
                    return `
                      <tr>
                        <td style="color: var(--hud-accent);">${g.name}</td>
                        <td><span style="color: ${statusColor};">${g.status.toUpperCase()}</span></td>
                        <td style="color: var(--hud-text-dim);">${info.agent}</td>
                        <td style="color: var(--hud-text-dim);">${info.desc}</td>
                      </tr>
                    `;
                  }).join('')}
                </tbody>
              </table>
            </div>
          </div>
        `;
      }).join('')}

      <!-- Cross-tool CLI Reference -->
      <div class="card" style="margin-top: 16px;">
        <div class="card__title" style="margin-bottom: 12px;">Cross-tool CLI Commands</div>
        <div style="font-size: 12px; color: var(--hud-text-dim); line-height: 1.8;">
          <div><span style="color: var(--hud-accent);">sak trace</span> &lt;CTR&gt; --journal-path &lt;PATH&gt; — E2E traceability check</div>
          <div><span style="color: var(--hud-accent);">sak gates status</span> &lt;CTR&gt; --journal-path &lt;PATH&gt; — Gate status report</div>
          <div><span style="color: var(--hud-accent);">sak gates next</span> &lt;CTR&gt; --journal-path &lt;PATH&gt; — Next gate to complete</div>
          <div><span style="color: var(--hud-accent);">sak metrics summary</span> &lt;CTR&gt; --journal-path &lt;PATH&gt; — Full metrics</div>
          <div><span style="color: var(--hud-accent);">sak status</span> &lt;CTR&gt; --journal-path &lt;PATH&gt; — Quick cross-tool status</div>
        </div>
      </div>
    `;
  }
};
