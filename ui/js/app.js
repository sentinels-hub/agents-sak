/**
 * Agents SAK — Main Application
 * Zero dependencies. Vanilla JS.
 */

const App = {
  currentView: 'dashboard',
  views: {},

  init() {
    this.registerViews();
    this.bindNavigation();
    this.navigate(window.location.hash.slice(1) || 'dashboard');
  },

  registerViews() {
    this.views = {
      dashboard: Dashboard,
      backlog: Backlog,
      roadmap: Roadmap,
      traceability: Traceability,
      queries: Queries,
      agents: Agents,
      contracts: Contracts,
    };
  },

  bindNavigation() {
    document.querySelectorAll('[data-view]').forEach(el => {
      el.addEventListener('click', (e) => {
        e.preventDefault();
        this.navigate(el.dataset.view);
      });
    });
    window.addEventListener('hashchange', () => {
      this.navigate(window.location.hash.slice(1) || 'dashboard');
    });
  },

  navigate(viewName) {
    if (!this.views[viewName]) viewName = 'dashboard';
    this.currentView = viewName;
    window.location.hash = viewName;

    // Update nav
    document.querySelectorAll('[data-view]').forEach(el => {
      el.classList.toggle('active', el.dataset.view === viewName);
    });

    // Render view
    const main = document.getElementById('main-content');
    if (main && this.views[viewName]) {
      main.innerHTML = this.views[viewName].render();
      if (this.views[viewName].afterRender) {
        this.views[viewName].afterRender();
      }
    }
  }
};

// ─── Utility Functions ───────────────────────────────────

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function badge(status) {
  const map = {
    'New': 'new',
    'In specification': 'new',
    'In progress': 'progress',
    'Developed': 'developed',
    'In review': 'review',
    'In security analysis': 'review',
    'Verification': 'review',
    'Closed': 'closed',
    'Done': 'closed',
    'On hold': 'blocked',
    'Test failed': 'blocked',
    'Blocked': 'blocked',
  };
  const cls = map[status] || 'new';
  return `<span class="badge badge--${cls}">${escapeHtml(status)}</span>`;
}

function progressBar(percent) {
  return `<div class="progress"><div class="progress__fill" style="width:${percent}%"></div></div>`;
}

function gatePipeline(gates) {
  return `<div class="gate-pipeline">${gates.map(g =>
    `<span class="gate gate--${g.status}">${g.name}</span>`
  ).join('')}</div>`;
}

// ─── Demo Data ───────────────────────────────────────────
// Datos de demostración basados en proyectos reales de Sentinels

const DEMO_DATA = {
  projects: [
    {
      id: 'sentinels-hub',
      name: 'Sentinels Hub',
      version: 'v0.1.0',
      progress: 85,
      wpTotal: 15,
      wpClosed: 13,
      wpInProgress: 2,
      status: 'In progress'
    },
    {
      id: 'agents-sak',
      name: 'Agents SAK',
      version: 'v0.1.0',
      progress: 30,
      wpTotal: 8,
      wpClosed: 2,
      wpInProgress: 4,
      status: 'In progress'
    },
    {
      id: 'sentinels-lighthouse',
      name: 'Sentinels Lighthouse',
      version: 'v2.0.0',
      progress: 95,
      wpTotal: 12,
      wpClosed: 11,
      wpInProgress: 1,
      status: 'In review'
    }
  ],
  workPackages: [
    { id: 1837, type: 'Epic', subject: 'Sentinels Hub', status: 'In progress', version: 'v0.1.0', hours: 14, agent: '@inception', gate: 'G3', project: 'sentinels-hub' },
    { id: 1881, type: 'Feature', subject: 'HUD Theme & Base Layout', status: 'Developed', version: 'v0.1.0', hours: 8, agent: '@gtd', gate: 'G5', project: 'sentinels-hub' },
    { id: 1889, type: 'User story', subject: 'Implement HUD theme base', status: 'Developed', version: 'v0.1.0', hours: 8, agent: '@gtd', gate: 'G5', project: 'sentinels-hub' },
    { id: 1897, type: 'Task', subject: 'Create file structure', status: 'Closed', version: 'v0.1.0', hours: 0.5, agent: '@gtd', gate: 'G9', project: 'sentinels-hub' },
    { id: 1899, type: 'Task', subject: 'CSS variables & reset', status: 'Closed', version: 'v0.1.0', hours: 1, agent: '@gtd', gate: 'G9', project: 'sentinels-hub' },
    { id: 2001, type: 'User story', subject: 'OpenProject catalog', status: 'In progress', version: 'v0.1.0', hours: 4, agent: '@gtd', gate: 'G3', project: 'agents-sak' },
    { id: 2002, type: 'User story', subject: 'SAK Web UI', status: 'New', version: 'v0.1.0', hours: 6, agent: '@inception', gate: 'G2', project: 'agents-sak' },
    { id: 2525, type: 'Epic', subject: 'OpenProject Cleanup', status: 'Closed', version: 'v0.1.0', hours: 8, agent: '@jarvis', gate: 'G9', project: 'fresh-start' },
  ],
  versions: [
    { name: 'v0.1.0', project: 'sentinels-hub', start: '2026-03-01', end: '2026-03-14', status: 'open', progress: 85 },
    { name: 'v0.2.0', project: 'sentinels-hub', start: '2026-03-15', end: '2026-03-28', status: 'open', progress: 0 },
    { name: 'v0.1.0', project: 'agents-sak', start: '2026-03-04', end: '2026-03-18', status: 'open', progress: 30 },
    { name: 'v0.2.0', project: 'agents-sak', start: '2026-03-19', end: '2026-04-02', status: 'open', progress: 0 },
    { name: 'v2.0.0', project: 'sentinels-lighthouse', start: '2026-02-01', end: '2026-03-01', status: 'locked', progress: 95 },
  ],
  contracts: [
    {
      id: 'CTR-sentinels-hub-20260302',
      project: 'sentinels-hub',
      gates: [
        { name: 'G0', status: 'passed' },
        { name: 'G1', status: 'passed' },
        { name: 'G2', status: 'passed' },
        { name: 'G3', status: 'passed' },
        { name: 'G4', status: 'passed' },
        { name: 'G5', status: 'active' },
        { name: 'G6', status: 'pending' },
        { name: 'G7', status: 'pending' },
        { name: 'G8', status: 'pending' },
        { name: 'G9', status: 'pending' },
      ],
      traceability: {
        contract: true,
        wp: true,
        branch: true,
        commits: true,
        pr: true,
        evidence: false,
        ledger: false,
      }
    },
    {
      id: 'CTR-agents-sak-20260304',
      project: 'agents-sak',
      gates: [
        { name: 'G0', status: 'passed' },
        { name: 'G1', status: 'passed' },
        { name: 'G2', status: 'passed' },
        { name: 'G3', status: 'active' },
        { name: 'G4', status: 'pending' },
        { name: 'G5', status: 'pending' },
        { name: 'G6', status: 'pending' },
        { name: 'G7', status: 'pending' },
        { name: 'G8', status: 'pending' },
        { name: 'G9', status: 'pending' },
      ],
      traceability: {
        contract: true,
        wp: true,
        branch: true,
        commits: true,
        pr: false,
        evidence: false,
        ledger: false,
      }
    }
  ]
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => App.init());
