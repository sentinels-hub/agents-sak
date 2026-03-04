#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# gh-cli.sh — CLI modular para GitHub (Sentinels)
# ─────────────────────────────────────────────────────────────
# Operaciones de GitHub con convenciones Sentinels:
# branches, PRs, commits, labels, trazabilidad.
#
# Requiere: gh (autenticado), git, jq
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gh-core.sh"

# ═══════════════════════════════════════════════════════════════
# COMMANDS
# ═══════════════════════════════════════════════════════════════

# ─── branch create ────────────────────────────────────────────

cmd_branch_create() {
  local type="$1"
  local wp_id="$2"
  local description="$3"

  require_git_repo

  local branch_name
  branch_name="$(build_branch_name "$type" "$wp_id" "$description")"
  validate_branch_name "$branch_name" || return 1

  git checkout main 2>/dev/null && git pull origin main 2>/dev/null
  git checkout -b "$branch_name"

  echo "Branch creada: $branch_name"
  echo "WP: #$wp_id"
}

# ─── branch validate ─────────────────────────────────────────

cmd_branch_validate() {
  local branch="${1:-$(git branch --show-current 2>/dev/null)}"

  if validate_branch_name "$branch"; then
    local wp_id
    wp_id="$(wp_id_from_branch "$branch")"
    echo "OK: $branch (WP#$wp_id)"
  fi
}

# ─── branch list ──────────────────────────────────────────────

cmd_branch_list() {
  require_git_repo
  local repo
  repo="$(current_repo)"

  echo "Branches activas en $repo:"
  echo ""
  gh api "repos/$repo/branches" --paginate --jq '.[].name' | while read -r name; do
    if [[ "$name" =~ ^(feat|fix|chore|docs|refactor|test)/wp- ]]; then
      local wp_id
      wp_id="$(wp_id_from_branch "$name")"
      echo "  $name  (WP#$wp_id)"
    else
      echo "  $name"
    fi
  done
}

# ─── commit validate ─────────────────────────────────────────

cmd_commit_validate() {
  require_git_repo

  local base="${1:-main}"
  local commits
  commits="$(git log "$base"..HEAD --format="%s" 2>/dev/null)"

  if [ -z "$commits" ]; then
    echo "No hay commits en el branch actual vs $base"
    return 0
  fi

  local total=0
  local valid=0
  local invalid=0

  while IFS= read -r msg; do
    total=$((total + 1))
    if validate_commit_message "$msg" 2>/dev/null; then
      valid=$((valid + 1))
    else
      invalid=$((invalid + 1))
      echo "  INVALID: $msg"
    fi
  done <<< "$commits"

  echo ""
  echo "Total: $total | Valid: $valid | Invalid: $invalid"

  [ "$invalid" -eq 0 ] && return 0 || return 1
}

# ─── pr create ────────────────────────────────────────────────

cmd_pr_create() {
  local wp_id="$1"
  local contract_id="$2"
  local gate="${3:-G3}"
  local summary="${4:-}"

  require_git_repo
  require_gh

  local branch repo
  branch="$(git branch --show-current)"
  repo="$(current_repo)"

  validate_branch_name "$branch" || return 1

  if [ -z "$wp_id" ]; then
    wp_id="$(wp_id_from_branch "$branch")"
  fi

  local type
  type="$(echo "$branch" | cut -d/ -f1)"

  if [ -z "$summary" ]; then
    summary="$(echo "$branch" | sed -E 's|.*/wp-[0-9]+-||; s/-/ /g')"
  fi

  local title="${type}: ${summary} [WP#${wp_id}]"

  local commit_count
  commit_count="$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')"

  # Get agent from git config or default
  local agent="@gtd"

  local body
  body="$(cat <<PREOF
## Contrato
- **Contract ID**: $contract_id
- **Work Package**: WP#$wp_id
- **Gate**: $gate

## Resumen
$summary

## Trazabilidad
- **Branch**: \`$branch\`
- **Commits**: $commit_count commits
- **Repo**: $repo

## Verificación
- [ ] Tests pasan
- [ ] Sin secretos expuestos
- [ ] Lint OK
- [ ] Funcionalidad verificada según AC

## Governance
[$agent] | contract: $contract_id | gate: $gate | PR ready for review
PREOF
)"

  # Push branch first
  git push -u origin "$branch" 2>/dev/null || true

  gh pr create \
    --title "$title" \
    --body "$body" \
    --base main \
    --head "$branch" \
    --label "gate:$gate,agent:gtd"

  echo ""
  echo "PR creado para WP#$wp_id"
}

# ─── pr list ──────────────────────────────────────────────────

cmd_pr_list() {
  local repo="${1:-$(current_repo)}"
  local state="${2:-open}"

  gh pr list --repo "$repo" --state "$state" \
    --json number,title,headRefName,labels,state \
    --jq '.[] | "  #\(.number)\t\(.state)\t\(.headRefName)\t\(.title)"'
}

# ─── pr link-wp ───────────────────────────────────────────────
# Registra la URL del PR en OpenProject

cmd_pr_link_wp() {
  local pr_number="$1"
  local wp_id="$2"

  require_gh

  local repo pr_url
  repo="$(current_repo)"
  pr_url="https://github.com/$repo/pull/$pr_number"

  # Si op-cli.sh está disponible, vincular
  local op_cli="$SCRIPT_DIR/../../openproject/scripts/op-cli.sh"
  if [ -x "$op_cli" ]; then
    echo "Vinculando PR #$pr_number → WP#$wp_id en OpenProject..."
    # This would use set-custom-field via openproject-sync.sh
    echo "  PR URL: $pr_url"
    echo "  (Usa openproject-sync.sh set-github-pr $wp_id $pr_url)"
  else
    echo "PR URL: $pr_url"
    echo "WP: #$wp_id"
    echo "Vincula manualmente: openproject-sync.sh set-github-pr $wp_id $pr_url"
  fi
}

# ─── labels setup ─────────────────────────────────────────────

cmd_labels_setup() {
  local repo="${1:-$(current_repo)}"

  require_gh

  echo "Creando labels de governance en $repo..."
  create_governance_labels "$repo"
  echo ""
  echo "Labels configurados."
}

# ─── labels list ──────────────────────────────────────────────

cmd_labels_list() {
  local repo="${1:-$(current_repo)}"

  gh label list --repo "$repo" --json name,color,description \
    --jq '.[] | "  \(.name)\t#\(.color)\t\(.description // "")"' | sort
}

# ─── repo setup ───────────────────────────────────────────────
# Configura un repo con settings Sentinels

cmd_repo_setup() {
  local repo="${1:-$(current_repo)}"

  require_gh

  echo "Configurando $repo con settings Sentinels..."

  # Repo settings
  gh api "repos/$repo" -X PATCH \
    -f allow_squash_merge=true \
    -f allow_merge_commit=false \
    -f allow_rebase_merge=true \
    -f delete_branch_on_merge=true \
    -f allow_auto_merge=true \
    > /dev/null 2>&1 && echo "  [OK] Repo settings" || echo "  [WARN] Repo settings (puede requerir admin)"

  # Labels
  create_governance_labels "$repo"

  echo ""
  echo "Setup completado para $repo"
}

# ─── traceability check ──────────────────────────────────────
# Verifica trazabilidad Git del branch actual

cmd_traceability_check() {
  require_git_repo

  local branch
  branch="$(git branch --show-current)"

  echo "=== Traceability Check ==="
  echo ""

  # Branch name
  if validate_branch_name "$branch" 2>/dev/null; then
    echo "  [OK] Branch: $branch"
  else
    echo "  [FAIL] Branch: $branch (naming inválido)"
  fi

  # WP ID
  local wp_id
  wp_id="$(wp_id_from_branch "$branch" 2>/dev/null || echo "")"
  if [ -n "$wp_id" ] && [ "$wp_id" != "$branch" ]; then
    echo "  [OK] WP: #$wp_id"
  else
    echo "  [FAIL] WP: no se puede extraer del branch name"
  fi

  # Commits format
  local total=0 valid=0
  while IFS= read -r msg; do
    [ -z "$msg" ] && continue
    total=$((total + 1))
    if [[ "$msg" =~ \[WP#[0-9]+\]$ ]]; then
      valid=$((valid + 1))
    fi
  done <<< "$(git log main..HEAD --format="%s" 2>/dev/null)"

  if [ "$total" -eq 0 ]; then
    echo "  [INFO] Commits: ninguno aún"
  elif [ "$valid" -eq "$total" ]; then
    echo "  [OK] Commits: $valid/$total con WP tag"
  else
    echo "  [WARN] Commits: $valid/$total con WP tag"
  fi

  # PR exists?
  local pr_count
  pr_count="$(gh pr list --head "$branch" --json number --jq 'length' 2>/dev/null || echo "0")"
  if [ "$pr_count" -gt 0 ]; then
    echo "  [OK] PR: existe"
  else
    echo "  [INFO] PR: no creado aún"
  fi

  echo ""
}

# ═══════════════════════════════════════════════════════════════
# USAGE & ROUTER
# ═══════════════════════════════════════════════════════════════

usage() {
  cat <<'EOF'
gh-cli.sh — CLI de GitHub para Sentinels

Branches:
  gh-cli.sh branch create <TYPE> <WP_ID> <DESCRIPTION>
  gh-cli.sh branch validate [BRANCH_NAME]
  gh-cli.sh branch list

Commits:
  gh-cli.sh commit validate [BASE_BRANCH]

Pull Requests:
  gh-cli.sh pr create <WP_ID> <CONTRACT_ID> [GATE] [SUMMARY]
  gh-cli.sh pr list [REPO] [STATE]
  gh-cli.sh pr link-wp <PR_NUMBER> <WP_ID>

Labels:
  gh-cli.sh labels setup [REPO]
  gh-cli.sh labels list [REPO]

Repository:
  gh-cli.sh repo setup [REPO]

Traceability:
  gh-cli.sh traceability check

Examples:
  gh-cli.sh branch create feat 1897 "oauth2 provider"
  gh-cli.sh commit validate
  gh-cli.sh pr create 1897 CTR-sentinels-hub-20260302 G3
  gh-cli.sh labels setup sentinels-hub/agents-sak
  gh-cli.sh traceability check

Requires:
  gh (GitHub CLI, authenticated)
  git
  jq
EOF
}

main() {
  if [ $# -lt 1 ]; then
    usage
    exit 1
  fi

  local domain="$1"
  shift

  case "$domain" in
    branch)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        create)    cmd_branch_create "$@" ;;
        validate)  cmd_branch_validate "$@" ;;
        list)      cmd_branch_list "$@" ;;
        *)         echo "ERROR: subcomando desconocido: branch $subcmd" >&2; exit 1 ;;
      esac
      ;;
    commit)
      local subcmd="${1:-validate}"
      shift 2>/dev/null || true
      case "$subcmd" in
        validate)  cmd_commit_validate "$@" ;;
        *)         echo "ERROR: subcomando desconocido: commit $subcmd" >&2; exit 1 ;;
      esac
      ;;
    pr)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        create)   cmd_pr_create "$@" ;;
        list)     cmd_pr_list "$@" ;;
        link-wp)  cmd_pr_link_wp "$@" ;;
        *)        echo "ERROR: subcomando desconocido: pr $subcmd" >&2; exit 1 ;;
      esac
      ;;
    labels)
      local subcmd="${1:-list}"
      shift 2>/dev/null || true
      case "$subcmd" in
        setup)  cmd_labels_setup "$@" ;;
        list)   cmd_labels_list "$@" ;;
        *)      echo "ERROR: subcomando desconocido: labels $subcmd" >&2; exit 1 ;;
      esac
      ;;
    repo)
      local subcmd="${1:-setup}"
      shift 2>/dev/null || true
      case "$subcmd" in
        setup)  cmd_repo_setup "$@" ;;
        *)      echo "ERROR: subcomando desconocido: repo $subcmd" >&2; exit 1 ;;
      esac
      ;;
    traceability)
      local subcmd="${1:-check}"
      shift 2>/dev/null || true
      case "$subcmd" in
        check)  cmd_traceability_check "$@" ;;
        *)      echo "ERROR: subcomando desconocido: traceability $subcmd" >&2; exit 1 ;;
      esac
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "ERROR: dominio desconocido: $domain" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
