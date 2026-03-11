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
VERSION="$(python3 -c "import json; print(json.load(open('${REPO_DIR}/.claude-plugin/plugin.json'))['version'])")"
CACHE_DIR="${PLUGINS_DIR}/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}/${VERSION}"
GIT_SHA="$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || echo "unknown")"
NOW="$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='milliseconds').replace('+00:00','Z'))")"

mkdir -p "${PLUGINS_DIR}"

# Register marketplace (if not already pointing here)
python3 -c "
import json, os
path = '${PLUGINS_DIR}/known_marketplaces.json'
data = json.load(open(path)) if os.path.exists(path) else {}
entry = data.get('${MARKETPLACE_NAME}', {}).get('source', {})
if entry.get('source') == 'directory' and entry.get('path') == '${REPO_DIR}':
    raise SystemExit(0)
data['${MARKETPLACE_NAME}'] = {
    'source': {'source': 'directory', 'path': '${REPO_DIR}'},
    'installLocation': '${REPO_DIR}',
    'lastUpdated': '${NOW}'
}
json.dump(data, open(path, 'w'), indent=2); open(path, 'a').write('\n')
print('Registered marketplace')
"

# Sync plugin to cache
rsync -a --delete --exclude='.git' --exclude='.worktrees' --exclude='node_modules' --exclude='.orphaned_at' \
  "${REPO_DIR}/" "${CACHE_DIR}/"

# Register installed plugin
python3 -c "
import json, os
path = '${PLUGINS_DIR}/installed_plugins.json'
data = json.load(open(path)) if os.path.exists(path) else {'version': 2, 'plugins': {}}
existing = data.setdefault('plugins', {}).get('${PLUGIN_KEY}', [{}])
installed_at = existing[0].get('installedAt', '${NOW}') if existing else '${NOW}'
data['plugins']['${PLUGIN_KEY}'] = [{
    'scope': 'user', 'installPath': '${CACHE_DIR}', 'version': '${VERSION}',
    'installedAt': installed_at, 'lastUpdated': '${NOW}', 'gitCommitSha': '${GIT_SHA}'
}]
json.dump(data, open(path, 'w'), indent=2); open(path, 'a').write('\n')
"

echo "Installed ${PLUGIN_NAME} v${VERSION} (${GIT_SHA:0:7}). Restart Claude Code to use."
