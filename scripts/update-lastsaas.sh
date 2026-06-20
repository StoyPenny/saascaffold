#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Pulling latest changes from jonradoff/lastsaas..."
echo ""
echo "WARNING: Review the diff after this completes."
echo "Upstream changes may conflict with local customizations in lastsaas/."
echo ""

git -C "$ROOT_DIR" subtree pull \
  --prefix=lastsaas \
  https://github.com/jonradoff/lastsaas \
  master \
  --squash

echo ""
echo "Done. Run 'git log --oneline -5' to see the merge commit."
echo "If there are conflicts, resolve them and run 'git commit' to complete the merge."
echo ""
echo "After updating, verify:"
echo "  - lastsaas/backend/.air.toml still exists (re-create if upstream removed it)"
echo "  - Port numbers in lastsaas/frontend/vite.config.ts match docker-compose.yml"
echo "  - lastsaas/backend/config/dev.example.yaml doesn't introduce new required env vars"
