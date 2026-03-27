#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/yarnpkg/berry"
BRANCH="master"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== prepare.sh: yarnpkg/berry ==="

# --- Node version (20+) ---
NODE_20_PATH="/opt/hostedtoolcache/node/20.19.1/x64/bin"
if [ -d "$NODE_20_PATH" ]; then
    export PATH="$NODE_20_PATH:$PATH"
fi

NODE_MAJOR=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1 || echo "0")
if [ "$NODE_MAJOR" -lt "20" ]; then
    echo "Looking for Node 20 in hostedtoolcache..."
    HOSTED_NODE=$(ls /opt/hostedtoolcache/node/ 2>/dev/null | grep '^20\.' | tail -1)
    if [ -n "$HOSTED_NODE" ]; then
        export PATH="/opt/hostedtoolcache/node/$HOSTED_NODE/x64/bin:$PATH"
    fi
    NODE_MAJOR=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1 || echo "0")
    if [ "$NODE_MAJOR" -lt "18" ]; then
        echo "ERROR: Need Node 18+ but have $(node --version 2>/dev/null || echo 'not found')."
        exit 1
    fi
fi
echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"

# --- Corepack + Yarn 4.x ---
echo "Enabling corepack..."
corepack enable || npm install -g corepack
corepack prepare yarn@4.5.0 --activate
echo "Yarn version: $(yarn --version)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning $REPO_URL (depth 1)..."
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
    echo "Clone complete"
else
    echo "source-repo/ already exists, skipping clone"
fi

cd "$REPO_DIR"

# --- Install root dependencies ---
# Berry uses PnP (Plug'n'Play) via .yarnrc.yml
echo "Installing root dependencies..."
yarn install

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

echo "[DONE] Repository is ready for docusaurus commands."
