#!/usr/bin/env bash
set -euo pipefail

# setup.sh — Set up superpowers-extended-cc for use with Claude Code
# Reentrant: safe to run repeatedly; skips steps already completed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
PLUGINS_DIR="${CLAUDE_DIR}/plugins"
MARKETPLACES_FILE="${PLUGINS_DIR}/known_marketplaces.json"
INSTALLED_FILE="${PLUGINS_DIR}/installed_plugins.json"

MARKETPLACE_NAME="superpowers-extended-cc-marketplace"
PLUGIN_NAME="superpowers-extended-cc"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_NAME}"

FORK_REMOTE="git@github.com:alxmyth/superpowers.git"
UPSTREAM_REMOTE="https://github.com/pcvelz/superpowers"

# Read version from plugin.json
PLUGIN_VERSION="$(python3 -c "import json; print(json.load(open('${SCRIPT_DIR}/.claude-plugin/plugin.json'))['version'])")"
CACHE_DIR="${PLUGINS_DIR}/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}/${PLUGIN_VERSION}"

log()  { printf '  ✓ %s\n' "$1"; }
skip() { printf '  · %s (already done)\n' "$1"; }
info() { printf '\n%s\n' "$1"; }

# --------------------------------------------------------------------------- #
# Step 1: Git remotes
# --------------------------------------------------------------------------- #
info "=== Git Remotes ==="

cd "${SCRIPT_DIR}"

# origin → alxmyth fork
current_origin="$(git remote get-url origin 2>/dev/null || echo "")"
if [ "${current_origin}" = "${FORK_REMOTE}" ]; then
  skip "origin → ${FORK_REMOTE}"
elif [ -z "${current_origin}" ]; then
  git remote add origin "${FORK_REMOTE}"
  log "Added origin → ${FORK_REMOTE}"
else
  # origin points elsewhere — check if it's the upstream
  if echo "${current_origin}" | grep -q "pcvelz/superpowers"; then
    git remote rename origin upstream 2>/dev/null || true
    git remote add origin "${FORK_REMOTE}"
    log "Renamed old origin to upstream, set origin → ${FORK_REMOTE}"
  else
    echo "  ⚠ origin points to ${current_origin} (unexpected — not changing)"
  fi
fi

# upstream → pcvelz
current_upstream="$(git remote get-url upstream 2>/dev/null || echo "")"
if echo "${current_upstream}" | grep -q "pcvelz/superpowers"; then
  skip "upstream → pcvelz/superpowers"
elif [ -z "${current_upstream}" ]; then
  git remote add upstream "${UPSTREAM_REMOTE}"
  log "Added upstream → ${UPSTREAM_REMOTE}"
fi

# Set tracking branch
current_tracking="$(git config --get branch.main.remote 2>/dev/null || echo "")"
if [ "${current_tracking}" = "origin" ]; then
  skip "main tracks origin/main"
else
  git branch --set-upstream-to=origin/main main 2>/dev/null || true
  log "Set main to track origin/main"
fi

# --------------------------------------------------------------------------- #
# Step 2: Ensure plugin directories exist
# --------------------------------------------------------------------------- #
info "=== Plugin Directories ==="

mkdir -p "${PLUGINS_DIR}/cache" "${PLUGINS_DIR}/marketplaces"
log "Ensured ${PLUGINS_DIR} exists"

# --------------------------------------------------------------------------- #
# Step 3: Register marketplace
# --------------------------------------------------------------------------- #
info "=== Marketplace Registration ==="

if [ ! -f "${MARKETPLACES_FILE}" ]; then
  echo '{}' > "${MARKETPLACES_FILE}"
  log "Created ${MARKETPLACES_FILE}"
fi

if python3 -c "
import json, sys
data = json.load(open('${MARKETPLACES_FILE}'))
entry = data.get('${MARKETPLACE_NAME}', {})
source = entry.get('source', {})
if source.get('source') == 'directory' and source.get('path') == '${SCRIPT_DIR}':
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  skip "Marketplace '${MARKETPLACE_NAME}' registered"
else
  python3 -c "
import json, datetime
path = '${MARKETPLACES_FILE}'
data = json.load(open(path))
data['${MARKETPLACE_NAME}'] = {
    'source': {'source': 'directory', 'path': '${SCRIPT_DIR}'},
    'installLocation': '${SCRIPT_DIR}',
    'lastUpdated': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')
}
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
  log "Registered marketplace '${MARKETPLACE_NAME}' → ${SCRIPT_DIR}"
fi

# --------------------------------------------------------------------------- #
# Step 4: Cache plugin
# --------------------------------------------------------------------------- #
info "=== Plugin Cache ==="

needs_sync=false
if [ -d "${CACHE_DIR}" ]; then
  # Check if cache is stale by comparing key files
  if diff -q "${SCRIPT_DIR}/.claude-plugin/plugin.json" "${CACHE_DIR}/.claude-plugin/plugin.json" &>/dev/null &&
     diff -rq "${SCRIPT_DIR}/skills" "${CACHE_DIR}/skills" &>/dev/null &&
     diff -rq "${SCRIPT_DIR}/hooks" "${CACHE_DIR}/hooks" &>/dev/null; then
    skip "Cache at ${CACHE_DIR} is up to date"
  else
    needs_sync=true
  fi
else
  needs_sync=true
fi

if [ "${needs_sync}" = true ]; then
  mkdir -p "${CACHE_DIR}"
  rsync -a --delete \
    --exclude '.git' \
    --exclude '.worktrees' \
    --exclude 'worktrees' \
    --exclude 'node_modules' \
    --exclude '.orphaned_at' \
    "${SCRIPT_DIR}/" "${CACHE_DIR}/"
  log "Synced plugin to cache (v${PLUGIN_VERSION})"
fi

# --------------------------------------------------------------------------- #
# Step 5: Register installed plugin
# --------------------------------------------------------------------------- #
info "=== Plugin Registration ==="

if [ ! -f "${INSTALLED_FILE}" ]; then
  echo '{"version": 2, "plugins": {}}' > "${INSTALLED_FILE}"
  log "Created ${INSTALLED_FILE}"
fi

GIT_SHA="$(git -C "${SCRIPT_DIR}" rev-parse HEAD 2>/dev/null || echo "unknown")"

if python3 -c "
import json, sys
data = json.load(open('${INSTALLED_FILE}'))
plugins = data.get('plugins', {})
entries = plugins.get('${PLUGIN_KEY}', [])
if entries and entries[0].get('version') == '${PLUGIN_VERSION}' and entries[0].get('gitCommitSha') == '${GIT_SHA}':
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  skip "Plugin '${PLUGIN_KEY}' registered (v${PLUGIN_VERSION}, ${GIT_SHA:0:7})"
else
  python3 -c "
import json, datetime
path = '${INSTALLED_FILE}'
data = json.load(open(path))
if 'plugins' not in data:
    data['plugins'] = {}
now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')
existing = data['plugins'].get('${PLUGIN_KEY}', [{}])
installed_at = existing[0].get('installedAt', now) if existing else now
data['plugins']['${PLUGIN_KEY}'] = [{
    'scope': 'user',
    'installPath': '${CACHE_DIR}',
    'version': '${PLUGIN_VERSION}',
    'installedAt': installed_at,
    'lastUpdated': now,
    'gitCommitSha': '${GIT_SHA}'
}]
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
  log "Registered plugin '${PLUGIN_KEY}' (v${PLUGIN_VERSION}, ${GIT_SHA:0:7})"
fi

# --------------------------------------------------------------------------- #
# Done
# --------------------------------------------------------------------------- #
info "=== Setup Complete ==="
echo "  Plugin: ${PLUGIN_NAME} v${PLUGIN_VERSION}"
echo "  Cache:  ${CACHE_DIR}"
echo "  Remote: origin → ${FORK_REMOTE}"
echo "         upstream → ${UPSTREAM_REMOTE}"
echo ""
echo "  Start a new Claude Code session to use the updated skills."
