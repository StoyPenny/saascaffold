#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "  ____              ____   ____        __  __       _     _  "
echo " / ___|  __ _  __ _/ ___| / ___|__ _  / _|/ _| ___ | | __| | "
echo " \___ \ / _\` |/ _\` \___ \| |   / _\` || |_| |_ / _ \| |/ _\` | "
echo "  ___) | (_| | (_| |___) | |__| (_| ||  _|  _| (_) | | (_| | "
echo " |____/ \__,_|\__,_|____/ \____\__,_||_| |_|  \___/|_|\__,_| "
echo ""
echo "  Setup"
echo "  ====="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
MISSING=0
for cmd in docker git; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "  ERROR: $cmd is required but not installed"
    MISSING=1
  fi
done

if ! docker compose version &>/dev/null 2>&1; then
  echo "  ERROR: Docker Compose V2 required. Update Docker Desktop or install the compose plugin."
  MISSING=1
fi

if [ "$MISSING" -eq 1 ]; then
  echo ""
  echo "Please install missing prerequisites and re-run this script."
  exit 1
fi
echo "  All prerequisites found."
echo ""

# Copy .env if it doesn't exist
if [ ! -f "$ROOT_DIR/.env" ]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  echo "Created .env from .env.example"
  echo "  -> Edit .env with your API keys before running docker compose up"
else
  echo ".env already exists — skipping copy"
fi
echo ""

# Initialize git repo if needed
if [ ! -d "$ROOT_DIR/.git" ]; then
  echo "Initializing git repository..."
  git -C "$ROOT_DIR" init
  git -C "$ROOT_DIR" add .
  git -C "$ROOT_DIR" commit -m "chore: initial SaaSCaffold scaffold"
  echo "  Git repository initialized."
else
  echo "Git repository already exists — skipping init"
fi
echo ""

# Copy LastSaaS dev config if it doesn't exist yet
DEV_CONFIG="$ROOT_DIR/lastsaas/backend/config/dev.yaml"
DEV_EXAMPLE="$ROOT_DIR/lastsaas/backend/config/dev.example.yaml"
if [ -f "$DEV_EXAMPLE" ] && [ ! -f "$DEV_CONFIG" ]; then
  cp "$DEV_EXAMPLE" "$DEV_CONFIG"
  echo "Created lastsaas/backend/config/dev.yaml from example"
fi

# Add LastSaaS git subtree if not already done
if [ ! -f "$ROOT_DIR/lastsaas/go.mod" ] && [ ! -d "$ROOT_DIR/lastsaas/backend" ]; then
  echo "Pulling LastSaaS via git subtree (this may take a moment)..."
  git -C "$ROOT_DIR" subtree add \
    --prefix=lastsaas \
    https://github.com/jonradoff/lastsaas \
    master \
    --squash
  echo "  LastSaaS subtree added."
else
  echo "lastsaas/ already populated — skipping subtree add"
fi
echo ""

# Create .air.toml if LastSaaS didn't include one
AIR_TOML="$ROOT_DIR/lastsaas/backend/.air.toml"
if [ -d "$ROOT_DIR/lastsaas/backend" ] && [ ! -f "$AIR_TOML" ]; then
  echo "Creating .air.toml for Go hot reload..."
  cat > "$AIR_TOML" <<'AIREOF'
[build]
  cmd = "go build -o /tmp/saascaffold-server ./cmd/server/main.go"
  bin = "/tmp/saascaffold-server"
  include_ext = ["go", "yaml"]
  exclude_dir = ["vendor", "tmp"]
  delay = 500

[log]
  time = false
AIREOF
  echo "  Created lastsaas/backend/.air.toml"
fi
echo ""

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit .env with your API keys (Stripe, Resend, JWT secrets)"
echo "  2. Run: docker compose up"
echo "  3. Visit http://cms.localhost/wp-admin and complete the WordPress install"
echo "     (Settings -> Permalinks -> Post name)"
echo "  4. Visit http://marketing.localhost for the Astro marketing site"
echo "  5. Visit http://app.localhost for the React dashboard"
echo "  6. Visit http://api.localhost for the Go API"
echo ""
echo "Note: Safari doesn't auto-resolve *.localhost — see README for /etc/hosts workaround."
echo ""
