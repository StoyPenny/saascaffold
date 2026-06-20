# SaaSCaffold

One-command local dev stack combining a Go + React SaaS application, an Astro marketing site, and a headless WordPress CMS — all wired together with Caddy and Docker Compose.

Clone it, run setup, and have a production-grade full-stack SaaS environment running in minutes.

## What's included

| Component | Tech | Purpose |
|---|---|---|
| **SaaS Backend** | Go 1.25 + gorilla/mux | REST API, auth, Stripe billing, multi-tenancy |
| **SaaS Frontend** | React 19 + Vite + TypeScript | Product dashboard |
| **Marketing Site** | Astro 5 | Static site built from WordPress content |
| **CMS** | Headless WordPress + MariaDB | Content API for the marketing site |
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
2. Initialize a git repo (if needed)
3. Pull LastSaaS via git subtree
4. Create a hot-reload config for the Go backend

Then edit `.env` with your API keys and start everything:

```bash
docker compose up
```

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

## First-Time WordPress Setup

1. Visit http://cms.localhost/wp-admin (or with your `LOCAL_PORT`: http://cms.localhost:8080/wp-admin)
2. Complete the WordPress 5-minute install
3. Go to **Settings → Permalinks → Post name** (required for REST API slugs to work)
4. Create a test post — it will appear on the marketing site automatically

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
│   ├── Caddyfile.dev        # Local dev routing (HTTP, *.localhost)
│   └── Caddyfile            # Production (HTTPS, env var domains)
├── lastsaas/                # LastSaaS git subtree (Go API + React)
├── marketing-site/          # Astro marketing site
│   └── src/lib/wordpress.ts # WordPress API integration
├── scripts/
│   ├── setup.sh             # First-time setup
│   └── update-lastsaas.sh   # Pull upstream LastSaaS updates
├── Dockerfile.go-api-dev    # Go backend with Air hot reload
├── Dockerfile.react-dev     # React frontend with Vite
├── docker-compose.yml       # Local development
├── docker-compose.prod.yml  # Production reference
└── .env.example             # All environment variables documented
```

## License

MIT
