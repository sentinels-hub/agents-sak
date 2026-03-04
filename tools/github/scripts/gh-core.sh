#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# gh-core.sh — Funciones compartidas para GitHub CLI (Sentinels)
# ─────────────────────────────────────────────────────────────
# Requiere: gh (GitHub CLI, autenticado), git, jq
# Importar con:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/gh-core.sh"
# ─────────────────────────────────────────────────────────────

GITHUB_ORG="${GITHUB_ORG:-sentinels-hub}"

# ─── Validations ──────────────────────────────────────────────

require_gh() {
  if ! command -v gh &>/dev/null; then
    echo "ERROR: gh (GitHub CLI) no está instalado" >&2
    exit 1
  fi
  if ! gh auth status &>/dev/null; then
    echo "ERROR: gh no está autenticado. Ejecuta: gh auth login" >&2
    exit 1
  fi
}

require_git_repo() {
  if ! git rev-parse --git-dir &>/dev/null; then
    echo "ERROR: no estás en un repositorio git" >&2
    exit 1
  fi
}

# ─── Repo detection ──────────────────────────────────────────

# Get current repo in owner/name format
current_repo() {
  gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || {
    local remote_url
    remote_url="$(git remote get-url origin 2>/dev/null || echo "")"
    echo "$remote_url" | sed -E 's|.*github\.com[:/]||; s|\.git$||'
  }
}

# Get just the repo name (no org)
current_repo_name() {
  current_repo | sed 's|.*/||'
}

# ─── Branch utilities ─────────────────────────────────────────

# Validate branch name against Sentinels convention
validate_branch_name() {
  local name="$1"
  if [[ "$name" =~ ^(feat|fix|chore|docs|refactor|test)/wp-[0-9]+-[a-z0-9-]+$ ]]; then
    return 0
  else
    echo "ERROR: branch name inválido: $name" >&2
    echo "  Formato: <type>/wp-<WP_ID>-<descripcion>" >&2
    echo "  Ejemplo: feat/wp-1897-oauth2-provider" >&2
    return 1
  fi
}

# Extract WP ID from branch name
wp_id_from_branch() {
  local name="$1"
  echo "$name" | sed -E 's|.*/wp-([0-9]+)-.*|\1|'
}

# Build branch name from components
build_branch_name() {
  local type="$1"
  local wp_id="$2"
  local description="$3"

  # Sanitize description: lowercase, replace spaces with hyphens, remove special chars
  description="$(echo "$description" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/-$//')"

  echo "${type}/wp-${wp_id}-${description}"
}

# ─── Commit utilities ─────────────────────────────────────────

# Validate commit message format
validate_commit_message() {
  local msg="$1"
  if [[ "$msg" =~ ^(feat|fix|chore|docs|build|refactor|test)(\([a-z0-9-]+\))?:\ .+\ \[WP#[0-9]+\]$ ]]; then
    return 0
  else
    echo "ERROR: commit message inválido: $msg" >&2
    echo "  Formato: type(scope): description [WP#ID]" >&2
    return 1
  fi
}

# Extract WP IDs from commit messages in current branch
wp_ids_from_commits() {
  git log main..HEAD --format="%s" 2>/dev/null | grep -oP '\[WP#\K[0-9]+' | sort -u
}

# ─── PR utilities ─────────────────────────────────────────────

# Build PR title from branch name and description
build_pr_title() {
  local branch="$1"
  local description="$2"
  local wp_id

  wp_id="$(wp_id_from_branch "$branch")"
  local type
  type="$(echo "$branch" | cut -d/ -f1)"

  echo "${type}: ${description} [WP#${wp_id}]"
}

# ─── Label management ─────────────────────────────────────────

GATE_LABELS=(
  "gate:G0:#1E3A5F:Contract initialized"
  "gate:G1:#1E3A5F:Identity verified"
  "gate:G2:#00C9FF:Plan approved"
  "gate:G3:#7B61FF:Implementation tracked"
  "gate:G4:#FFD700:Security analysis"
  "gate:G5:#FF4444:Code review"
  "gate:G6:#00C9FF:QA verification"
  "gate:G7:#00FF88:Deployment"
  "gate:G8:#7B61FF:Evidence export"
  "gate:G9:#1E3A5F:Closure"
)

AGENT_LABELS=(
  "agent:jarvis:#00FF88:Orchestrator"
  "agent:inception:#00C9FF:Planner"
  "agent:gtd:#7B61FF:Implementer"
  "agent:morpheus:#FFD700:Security"
  "agent:agent-smith:#FF4444:Reviewer"
  "agent:oracle:#00C9FF:QA"
  "agent:pepper:#00FF88:Deployment"
  "agent:ariadne:#7B61FF:Evidence"
)

# Create governance labels in a repo
create_governance_labels() {
  local repo="$1"

  for label_spec in "${GATE_LABELS[@]}" "${AGENT_LABELS[@]}"; do
    local name color description
    name="$(echo "$label_spec" | cut -d: -f1-2)"
    color="$(echo "$label_spec" | cut -d: -f3 | sed 's/#//')"
    description="$(echo "$label_spec" | cut -d: -f4)"

    if gh label create "$name" --color "$color" --description "$description" --repo "$repo" 2>/dev/null; then
      echo "  Creada: $name"
    else
      echo "  Ya existe: $name"
    fi
  done
}
