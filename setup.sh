#!/usr/bin/env bash
# Install superpowers-extended-cc plugin into Claude Code.
# Reentrant — safe to run repeatedly.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
PLUGINS_DIR="${CLAUDE_DIR}/plugins"
MARKETPLACE_NAME="superpowers-extended-cc-marketplace"
PLUGIN_NAME="superpowers-extended-cc"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_NAME}"
VERSION="$(node -p "require('${REPO_DIR}/.claude-plugin/plugin.json').version")"
CACHE_DIR="${PLUGINS_DIR}/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}/${VERSION}"
GIT_SHA="$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || echo "unknown")"
NOW="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"

mkdir -p "${PLUGINS_DIR}"

# Register marketplace (if not already pointing here)
node -e "
const fs = require('fs');
const path = '${PLUGINS_DIR}/known_marketplaces.json';
const data = fs.existsSync(path) ? JSON.parse(fs.readFileSync(path, 'utf8')) : {};
const entry = (data['${MARKETPLACE_NAME}'] || {}).source || {};
if (entry.source === 'directory' && entry.path === '${REPO_DIR}') process.exit(0);
data['${MARKETPLACE_NAME}'] = {
  source: { source: 'directory', path: '${REPO_DIR}' },
  installLocation: '${REPO_DIR}',
  lastUpdated: '${NOW}'
};
fs.writeFileSync(path, JSON.stringify(data, null, 2) + '\n');
console.log('Registered marketplace');
"

# Sync plugin to cache
rsync -a --delete --exclude='.git' --exclude='.worktrees' --exclude='node_modules' --exclude='.orphaned_at' \
  "${REPO_DIR}/" "${CACHE_DIR}/"

# Register installed plugin
node -e "
const fs = require('fs');
const path = '${PLUGINS_DIR}/installed_plugins.json';
const data = fs.existsSync(path) ? JSON.parse(fs.readFileSync(path, 'utf8')) : { version: 2, plugins: {} };
if (!data.plugins) data.plugins = {};
const existing = data.plugins['${PLUGIN_KEY}'] || [{}];
const installedAt = (existing[0] || {}).installedAt || '${NOW}';
data.plugins['${PLUGIN_KEY}'] = [{
  scope: 'user', installPath: '${CACHE_DIR}', version: '${VERSION}',
  installedAt: installedAt, lastUpdated: '${NOW}', gitCommitSha: '${GIT_SHA}'
}];
fs.writeFileSync(path, JSON.stringify(data, null, 2) + '\n');
"

echo "Installed ${PLUGIN_NAME} v${VERSION} (${GIT_SHA:0:7}). Restart Claude Code to use."
