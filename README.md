# SaaSCaffold

One-command local dev stack combining a Go + React SaaS application, a marketing site, and WordPress — all wired together with Caddy and Docker Compose.

Clone it, run setup, and have a production-grade full-stack SaaS environment running in minutes.

**Choose your site architecture during setup:**
- **Headless mode** — Astro handles the marketing site; WordPress is a headless CMS behind the scenes
- **Traditional mode** — WordPress handles everything with a theme; no Astro container

## What's included

| Component | Tech | Purpose |
|---|---|---|
| **SaaS Backend** | Go 1.25 + gorilla/mux | REST API, auth, Stripe billing, multi-tenancy |
| **SaaS Frontend** | React 19 + Vite + TypeScript | Product dashboard |
| **Marketing Site** | Astro 5 *(headless mode)* | Static site built from WordPress content |
| **CMS** | WordPress + MariaDB | Content management (headless API or traditional theme) |
| **Reverse Proxy** | Caddy 2 | Local subdomain routing; automatic HTTPS in production |
| **Database** | MongoDB 7 | SaaS application data |

The SaaS backend and frontend come from [LastSaaS](https://github.com/jonradoff/lastsaas) (included via git subtree — upstream updates are one command away).

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine 25+ with Compose plugin)
- Git

Minimum 4 GB RAM recommended.

## Quick Start

```bash
git clone https://github.com/yourusername/saascaffold.git
cd saascaffold
chmod +x scripts/setup.sh && ./scripts/setup.sh
```

The setup script will:
1. Copy `.env.example` to `.env`
2. Prompt you to choose **headless + Astro** or **traditional WordPress theme** — this sets `MODE` and `COMPOSE_PROFILES` in `.env` so Docker Compose knows which containers to start
3. Initialize a git repo (if needed)
4. Pull LastSaaS via git subtree
5. Create a hot-reload config for the Go backend

Then edit `.env` with your API keys and start everything:

```bash
docker compose up -d
./scripts/setup-wp.sh
```

`setup-wp.sh` installs WordPress, activates the right plugins for your chosen mode, and seeds your admin account using the `SETUP_ADMIN_*` values in `.env`. Admin credentials are printed at the end.

## Local URLs

Default port is `80`. If port 80 is already in use (e.g. another project), set `LOCAL_PORT=8080` in `.env`.

| Service | URL (default) | URL (LOCAL_PORT=8080) |
|---|---|---|
| Marketing site | http://marketing.localhost | http://marketing.localhost:8080 |
| SaaS dashboard | http://app.localhost | http://app.localhost:8080 |
| Go API | http://api.localhost | http://api.localhost:8080 |
| WordPress admin | http://cms.localhost/wp-admin | http://cms.localhost:8080/wp-admin |

> **Safari users:** Safari doesn't auto-resolve `*.localhost`. Add these lines to `/etc/hosts`:
> ```
> 127.0.0.1  marketing.localhost
> 127.0.0.1  app.localhost
> 127.0.0.1  api.localhost
> 127.0.0.1  cms.localhost
> ```

## First-Time Setup

`./scripts/setup-wp.sh` handles everything after `docker compose up -d`:

- Installs WordPress core if not already installed
- Installs and activates plugins for your chosen mode (headless or traditional)
- In **headless mode**: prompts for REST or GraphQL, copies the matching Astro WordPress client, configures CORS and frontend redirects
- In **traditional mode**: activates a default theme, skips headless-only plugins
- Seeds your app admin account (email/password come from `SETUP_ADMIN_*` in `.env`)

**To change the default admin credentials**, edit these in `.env` before running the script:
```
SETUP_ADMIN_EMAIL=you@yourcompany.com
SETUP_ADMIN_PASSWORD=YourSecurePassword1!
```

The script is idempotent — WordPress install and the admin account seed are both skipped if already done, so it's safe to re-run.

## Headless WordPress & SEO Integration

SaaSCaffold is configured to use **SEOPress** for search engine optimization. It operates in two modes depending on what you selected during `./scripts/setup-wp.sh`:

### A. REST API Mode (Default)
Astro queries the `/wp-json/wp/v2` endpoints. SEOPress automatically appends the `seopress_meta` object to the post response object.
You can access it directly inside your Astro layouts or page templates:
```typescript
const title = post.seopress_meta.title;
const description = post.seopress_meta.description;
const canonicalUrl = post.seopress_meta.canonical;
const ogTitle = post.seopress_meta.opengraph_title;
const noIndex = post.seopress_meta.robots_index === 'noindex';
```

### B. GraphQL Mode
If you chose GraphQL, the `wp-graphql` and `wp-graphql-seopress` plugins are active. You can retrieve SEO properties in a single round-trip query:
```graphql
query GetPostBySlug($slug: ID!) {
  post(id: $slug, idType: SLUG) {
    title
    content
    seo {
      title
      metaDesc
      canonical
      metaRobotsNoindex
      opengraphTitle
      opengraphDescription
    }
  }
}
```

### C. Redirects in a Headless Setup
Because visitors directly access your Astro frontend, WordPress redirects do not trigger for public traffic. 

*   **Vanity & Marketing Redirects:** Manage these at the frontend level. Add them to Astro's `astro.config.mjs` `redirects` configuration (for local development) or configure them directly via **Cloudflare Redirect Rules** in production for maximum edge performance.
*   **CMS Safety Net:** The custom `saas-headless-helper` plugin automatically forwards any crawler or legacy traffic landing directly on the CMS domain (e.g., `cms.yoursite.com/some-page`) to the corresponding page on the Astro site (`yoursite.com/some-page`).

## Environment Variables

Copy `.env.example` to `.env` and fill in:

- **JWT secrets** — generate with `openssl rand -hex 32`
- **Stripe keys** — from your Stripe dashboard (test keys are fine for dev)
- **Resend API key** — for transactional email
- **OAuth credentials** — optional, for social login

The rest (MongoDB, WordPress DB) have working defaults and don't need changes for local dev.

## Updating LastSaaS

To pull the latest changes from the upstream LastSaaS repo:

```bash
./scripts/update-lastsaas.sh
```

This runs a `git subtree pull` and squash-merges upstream changes. Review the diff before committing — local customizations to files inside `lastsaas/` may require manual conflict resolution.

## Architecture

```
                     ┌─────────────────────────────────────────────┐
                     │           Docker Compose (local)             │
                     │                                              │
  Browser            │  Caddy ──► marketing.localhost ──► Astro    │
     │               │        ──► app.localhost ──────► React      │
     └──► port 80 ───┤        ──► api.localhost ──────► Go API     │
                     │        ──► cms.localhost ──────► WordPress   │
                     │                                              │
                     │  MongoDB ◄── Go API                         │
                     │  MariaDB ◄── WordPress                      │
                     └─────────────────────────────────────────────┘
```

**Production layout (DigitalOcean):**

```
  yoursite.com ──► Cloudflare CDN ──► DO App Platform (Astro static)
  app.domain.com ─┐
  api.domain.com ─┼──► Cloudflare Proxy ──► Droplet (Caddy + containers)
  cms.domain.com ─┘         ↑
                     Cloudflare Zero Trust
                     (protects cms.domain.com)
```

The Astro marketing site is deployed separately as a free static site on DigitalOcean App Platform. It rebuilds automatically when WordPress content is published via a deploy webhook.

## Production Deployment

See `docker-compose.prod.yml` for the production service configuration.

1. Provision a DigitalOcean Droplet (2 GB RAM / 1 vCPU minimum, $12/mo)
2. Install Docker on the Droplet
3. Clone this repo onto the Droplet
4. Copy `.env.example` to `.env` and fill in production values
5. Set `DOMAIN` and `CADDY_EMAIL` in `.env`
6. Run `docker compose -f docker-compose.prod.yml up -d`
7. Caddy provisions HTTPS certificates automatically

For the Astro site: connect `marketing-site/` to DigitalOcean App Platform (free tier), set `WORDPRESS_API_URL` to your production WordPress URL, and configure a WordPress deploy webhook to trigger rebuilds on publish.

## Project Structure

```
saascaffold/
├── caddy/
│   ├── Caddyfile.headless    # Dev routing: marketing → Astro
│   ├── Caddyfile.traditional # Dev routing: marketing → WordPress
│   └── Caddyfile             # Production (HTTPS, env var domains)
├── lastsaas/                 # LastSaaS git subtree (Go API + React)
├── marketing-site/           # Astro marketing site (headless mode only)
│   └── src/lib/wordpress.ts  # WordPress API client (copied by setup-wp.sh)
├── scripts/
│   ├── setup.sh              # First-time setup (mode choice, .env, git, subtree)
│   ├── setup-wp.sh           # Post-startup init (WP, plugins, admin account)
│   └── update-lastsaas.sh    # Pull upstream LastSaaS updates
├── Dockerfile.go-api-dev     # Go backend with Air hot reload
├── Dockerfile.react-dev      # React frontend with Vite
├── docker-compose.yml        # Local development
├── docker-compose.prod.yml   # Production reference
└── .env.example              # All environment variables documented
```

## License

MIT
