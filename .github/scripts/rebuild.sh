#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for yarnpkg/berry
# Runs on existing source tree (no clone).
# CWD is expected to be packages/docusaurus (docusaurusRoot) of the staging repo.
# Installs deps from repo root, then builds.

echo "=== rebuild.sh: yarnpkg/berry ==="

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

# --- Corepack + Yarn 4.x ---
echo "Enabling corepack..."
corepack enable || npm install -g corepack
corepack prepare yarn@4.5.0 --activate
echo "Yarn version: $(yarn --version)"

# --- Install from repo root ---
# packages/docusaurus lives 2 levels down from repo root
DOCUSAURUS_DIR="$(pwd)"
REPO_ROOT="$(cd ../.. && pwd)"

echo "Repo root: $REPO_ROOT"
echo "Docusaurus dir: $DOCUSAURUS_DIR"

cd "$REPO_ROOT"
echo "Installing root dependencies..."
yarn install

# --- Build ---
cd "$DOCUSAURUS_DIR"
echo "Running docusaurus build..."
NODE_OPTIONS="--max-old-space-size=4096" yarn docusaurus build

echo "[DONE] Build complete."
