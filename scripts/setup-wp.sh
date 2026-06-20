#!/usr/bin/env bash
# =============================================================================
# SaaSCaffold — Headless WordPress Setup & Optimization Script
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=============================================="
echo "⚡ SaaSCaffold: Headless WordPress Installer"
echo "=============================================="
echo ""

# Load environment variables
if [ -f "$ROOT_DIR/.env" ]; then
  source "$ROOT_DIR/.env"
else
  echo "❌ Error: .env file not found in project root."
  echo "Please run './scripts/setup.sh' first."
  exit 1
fi

# Helper function to update or append variables in .env
update_env_var() {
  local var_name="$1"
  local var_value="$2"
  if grep -q "^${var_name}=" "$ROOT_DIR/.env"; then
    # Replace existing variable
    sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$ROOT_DIR/.env"
  else
    # Append if not present
    echo "${var_name}=${var_value}" >> "$ROOT_DIR/.env"
  fi
}

LOCAL_PORT="${LOCAL_PORT:-80}"
WP_PORT_SUFFIX=""
if [ "$LOCAL_PORT" != "80" ]; then
  WP_PORT_SUFFIX=":${LOCAL_PORT}"
fi

# Define WordPress URLs
WP_CMS_URL="http://cms.localhost${WP_PORT_SUFFIX}"
WP_FRONTEND_URL="http://marketing.localhost${WP_PORT_SUFFIX}"

echo "Configured URLs:"
echo "  - WordPress CMS:  $WP_CMS_URL"
echo "  - Astro Frontend: $WP_FRONTEND_URL"
echo ""

# Check if Docker is running
if ! docker info &>/dev/null; then
  echo "❌ Error: Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check if WordPress container is running
WP_CONTAINER="saascaffold-wordpress"
if ! docker ps --filter "name=$WP_CONTAINER" --filter "status=running" --format "{{.Names}}" | grep -q "$WP_CONTAINER"; then
  echo "⚠️  WordPress container ($WP_CONTAINER) is not running."
  read -p "Would you like to start it now? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting WordPress database and CMS containers..."
    docker compose up -d wordpress wp-db
    echo "Waiting for services to be healthy..."
    sleep 5
  else
    echo "Aborted. Please start the containers manually and run this script again."
    exit 1
  fi
fi

# Wait for MariaDB database to be healthy
echo "Checking database connection..."
RETRIES=15
while [ $RETRIES -gt 0 ]; do
  if docker compose exec -T wp-db mysqladmin ping -u"${WP_DB_USER:-wp_user}" -p"${WP_DB_PASSWORD:-wp_password}" &>/dev/null; then
    echo "✅ Database is online and healthy."
    break
  fi
  echo "  Waiting for database... ($RETRIES attempts remaining)"
  sleep 2
  RETRIES=$((RETRIES - 1))
done

if [ $RETRIES -eq 0 ]; then
  echo "❌ Error: Database did not respond. Check docker-compose logs."
  exit 1
fi

# Install WP-CLI inside the wordpress container if not present
echo "Setting up WP-CLI in WordPress container..."
docker compose exec -T wordpress curl -s -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
docker compose exec -T wordpress chmod +x /tmp/wp-cli.phar

# Helper function to run WP-CLI commands as www-data to maintain correct file ownerships
wp_run() {
  docker compose exec -T --user www-data -e WP_CLI_CACHE_DIR=/tmp/wp-cli-cache wordpress php /tmp/wp-cli.phar "$@"
}

# Check if WordPress is installed
echo "Checking WordPress installation status..."
if ! wp_run core is-installed &>/dev/null; then
  echo "WordPress is not installed. Running automated core installation..."
  
  ADMIN_USER="admin"
  ADMIN_PASS="admin123" # Developer default
  ADMIN_EMAIL="admin@example.com"

  wp_run core install \
    --url="$WP_CMS_URL" \
    --title="SaaSCaffold Headless CMS" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASS" \
    --admin_email="$ADMIN_EMAIL" \
    --skip-email
  
  echo "=============================================="
  echo "🎉 WordPress Core Installed Successfully!"
  echo "  - URL:      $WP_CMS_URL/wp-admin"
  echo "  - Username: $ADMIN_USER"
  echo "  - Password: $ADMIN_PASS"
  echo "  (Please change these details in production)"
  echo "=============================================="
  echo ""
else
  echo "✅ WordPress is already installed."
fi

if [ "${MODE:-headless}" = "traditional" ]; then
  # ===========================================================================
  # Traditional WordPress theme mode
  # ===========================================================================
  echo "🚀 Mode: Traditional WordPress theme"
  echo ""

  PLUGINS=(
    "advanced-custom-fields"
    "custom-post-type-ui"
    "wp-seopress"
    "wp-sweep"
  )

  echo "Installing plugins..."
  for plugin in "${PLUGINS[@]}"; do
    echo "  -> Processing plugin: $plugin"
    wp_run plugin install "$plugin" --activate
  done

  # Deactivate Yoast SEO if previously active
  if wp_run plugin is-active wordpress-seo &>/dev/null; then
    echo "Deactivating Yoast SEO in favor of SEOPress..."
    wp_run plugin deactivate wordpress-seo
  fi

  echo "Setting permalinks to 'postname' structure..."
  wp_run rewrite structure '/%postname%/'

  echo "Activating default theme..."
  wp_run theme activate twentytwentyfour 2>/dev/null \
    || wp_run theme activate twentytwentythree 2>/dev/null \
    || true

else
  # ===========================================================================
  # Headless WordPress + Astro mode
  # ===========================================================================
  echo "🚀 Mode: Headless WordPress + Astro"
  echo ""

  # Prompt for REST vs GraphQL
  echo "Which API architecture for your headless WordPress integrations?"
  echo "  1) REST API (Default: simple, built-in, zero WP config)"
  echo "  2) GraphQL API (Requires wp-graphql plugin, optimized queries)"
  read -p "Select option [1-2, default 1]: " -n 1 -r API_CHOICE
  echo ""

  if [[ ! "${API_CHOICE:-}" =~ ^[12]$ ]]; then
    API_CHOICE="1"
  fi

  PLUGINS=(
    "advanced-custom-fields"
    "custom-post-type-ui"
    "wp-seopress"
    "wp-sweep"
  )

  if [ "$API_CHOICE" = "2" ]; then
    echo "Selected: GraphQL API"
    PLUGINS+=("wp-graphql")
    PLUGINS+=("wp-graphql-seopress")
    echo "Copying Astro GraphQL client file to src/lib/wordpress.ts..."
    cp "$ROOT_DIR/marketing-site/src/lib/templates/wordpress-graphql.ts" "$ROOT_DIR/marketing-site/src/lib/wordpress.ts"
    update_env_var "WORDPRESS_API_URL" "http://wordpress/graphql"
  else
    echo "Selected: REST API"
    echo "Copying Astro REST client file to src/lib/wordpress.ts..."
    cp "$ROOT_DIR/marketing-site/src/lib/templates/wordpress-rest.ts" "$ROOT_DIR/marketing-site/src/lib/wordpress.ts"
    update_env_var "WORDPRESS_API_URL" "http://wordpress/wp-json/wp/v2"
  fi
  echo ""

  echo "Installing Headless Plugin Kit..."
  for plugin in "${PLUGINS[@]}"; do
    echo "  -> Processing plugin: $plugin"
    wp_run plugin install "$plugin" --activate
  done

  if [ "$API_CHOICE" = "1" ]; then
    if wp_run plugin is-active wp-graphql &>/dev/null; then
      echo "Deactivating wp-graphql (REST mode selected)..."
      wp_run plugin deactivate wp-graphql
    fi
  fi

  if wp_run plugin is-active wordpress-seo &>/dev/null; then
    echo "Deactivating Yoast SEO in favor of SEOPress..."
    wp_run plugin deactivate wordpress-seo
  fi

  echo "Activating SaaSCaffold Headless Helper plugin..."
  if wp_run plugin is-installed saas-headless-helper; then
    wp_run plugin activate saas-headless-helper
    echo "✅ Custom Headless Helper activated."
  else
    echo "❌ Error: Custom helper plugin not found. Make sure ./wp-content/plugins/saas-headless-helper is mounted correctly."
  fi

  echo "Setting permalinks to 'postname' structure..."
  wp_run rewrite structure '/%postname%/'

  echo "Configuring Headless Helper default settings..."
  wp_run option update saas_headless_frontend_url "$WP_FRONTEND_URL"
  wp_run option update saas_headless_redirect_frontend "1"
  wp_run option update saas_headless_preview_secret "saas-preview-secret-key-123"
  wp_run option update saas_headless_enable_cors "1"
  wp_run option update saas_headless_allow_svg "1"
  wp_run option update saas_headless_clean_wp_head "1"
fi

echo ""
echo "=============================================="
echo "🎉 WordPress Setup Complete!"
echo "=============================================="
if [ "${MODE:-headless}" = "traditional" ]; then
  echo "  Mode:      Traditional WordPress theme"
  echo "  CMS:       $WP_CMS_URL/wp-admin"
  echo "  Public:    http://marketing.localhost${WP_PORT_SUFFIX}"
else
  echo "  Mode:      Headless + Astro"
  if [ "${API_CHOICE:-1}" = "2" ]; then
    echo "  API:       GraphQL"
  else
    echo "  API:       REST"
  fi
  echo "  CMS:       $WP_CMS_URL/wp-admin"
  echo "  Marketing: $WP_FRONTEND_URL (Astro)"
fi
echo ""

# =============================================================================
# Initialize LastSaaS App Backend
# =============================================================================
echo "=============================================="
echo "⚡ Initializing LastSaaS App Backend"
echo "=============================================="
echo ""

GO_API_CONTAINER="saascaffold-go-api"
SKIP_APP_SETUP=0

if ! docker ps --filter "name=$GO_API_CONTAINER" --filter "status=running" --format "{{.Names}}" | grep -q "$GO_API_CONTAINER"; then
  echo "⚠️  Go API container ($GO_API_CONTAINER) is not running."
  read -p "Would you like to start it now? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting Go API and MongoDB containers..."
    docker compose up -d go-api mongo
    echo "Waiting for services to start..."
    sleep 8
  else
    echo "Skipping app backend setup."
    echo "When ready, run:"
    echo "  docker exec saascaffold-go-api go run ./cmd/lastsaas setup"
    echo ""
    SKIP_APP_SETUP=1
  fi
fi

if [ "$SKIP_APP_SETUP" != "1" ]; then
  SETUP_ORG_NAME="${SETUP_ORG_NAME:-My Organization}"
  SETUP_ADMIN_NAME="${SETUP_ADMIN_NAME:-Admin}"
  SETUP_ADMIN_EMAIL="${SETUP_ADMIN_EMAIL:-admin@example.com}"
  SETUP_ADMIN_PASSWORD="${SETUP_ADMIN_PASSWORD:-ChangeMe123!}"

  echo "Building LastSaaS CLI (this may take a moment)..."
  if ! docker exec "$GO_API_CONTAINER" go build -o /tmp/lastsaas-cli ./cmd/lastsaas 2>&1; then
    echo "❌ Failed to build LastSaaS CLI. Check that the go-api container is healthy."
    echo "   Run manually once it's ready:"
    echo "   docker exec saascaffold-go-api go run ./cmd/lastsaas setup"
  else
    echo "Running app setup..."
    RETRIES=10
    APP_SETUP_OK=0
    while [ "$RETRIES" -gt 0 ]; do
      if docker exec "$GO_API_CONTAINER" /tmp/lastsaas-cli setup \
          --org "$SETUP_ORG_NAME" \
          --name "$SETUP_ADMIN_NAME" \
          --email "$SETUP_ADMIN_EMAIL" \
          --password "$SETUP_ADMIN_PASSWORD"; then
        APP_SETUP_OK=1
        break
      fi
      echo "  Waiting for database... ($RETRIES attempts remaining)"
      sleep 5
      RETRIES=$((RETRIES - 1))
    done

    if [ "$APP_SETUP_OK" = "1" ]; then
      echo ""
      echo "=============================================="
      echo "🎉 App Backend Ready!"
      echo "  App URL:  http://app.localhost${WP_PORT_SUFFIX}"
      echo "  Email:    $SETUP_ADMIN_EMAIL"
      echo "  Password: $SETUP_ADMIN_PASSWORD"
      echo "  (Update SETUP_ADMIN_* in .env before sharing)"
      echo "=============================================="
    else
      echo "❌ App setup timed out. The database may still be starting."
      echo "   Run manually once ready:"
      echo "   docker exec saascaffold-go-api go run ./cmd/lastsaas setup"
    fi
  fi
fi

echo ""
echo "=============================================="
echo "✅ All done! Your stack is ready:"
echo "  App:       http://app.localhost${WP_PORT_SUFFIX}"
echo "  Marketing: http://marketing.localhost${WP_PORT_SUFFIX}"
echo "  CMS admin: $WP_CMS_URL/wp-admin"
echo "=============================================="
echo ""
