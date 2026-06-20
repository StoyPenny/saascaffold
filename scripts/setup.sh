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
else
  echo ".env already exists — skipping copy"
fi
echo ""

# Choose site mode
echo "Site architecture:"
echo "  1) Headless WordPress + Astro  (Astro handles the marketing site; WP is a headless CMS)"
echo "  2) Traditional WordPress theme  (WP handles everything; no Astro)"
read -p "Select option [1-2, default 1]: " -n 1 -r MODE_CHOICE
echo ""

update_env_var() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ROOT_DIR/.env"; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ROOT_DIR/.env"
  else
    echo "${key}=${val}" >> "$ROOT_DIR/.env"
  fi
}

if [[ "${MODE_CHOICE:-1}" == "2" ]]; then
  update_env_var "MODE" "traditional"
  update_env_var "COMPOSE_PROFILES" ""
  echo "  Mode set to: traditional WordPress theme"
else
  update_env_var "MODE" "headless"
  update_env_var "COMPOSE_PROFILES" "headless"
  echo "  Mode set to: headless WordPress + Astro"
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
echo "  1. Edit .env — set your API keys (Stripe, Resend, JWT secrets) and"
echo "     customize SETUP_ADMIN_EMAIL / SETUP_ADMIN_PASSWORD for your admin account"
echo "  2. Start the services: docker compose up -d"
echo "  3. Run the init script: ./scripts/setup-wp.sh"
echo "     This installs WordPress AND seeds your app admin account automatically."
echo ""
echo "  App:       http://app.localhost"
echo "  Marketing: http://marketing.localhost"
echo "  CMS admin: http://cms.localhost/wp-admin"
echo ""
echo "Note: Safari doesn't auto-resolve *.localhost — see README for /etc/hosts workaround."
echo ""
