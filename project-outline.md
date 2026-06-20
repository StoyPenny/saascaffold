## Tech Stack

### Front End 
The front end website will serve as the public facing marketing wesbite, designed with speed, SEO optimization, and easy content management in mind. We use a split framework setup with a headless WordPress instance serving as the primary backend API service, with Astro running the actual delivery of the front end. 

#### Headless WordPress
- Admin is locked behind zero trust cloudflare rules on production/staging
- Serves as the primary API for the website
- Supports ACF and CPT
- Supports SEO Plugins

#### Astro
- Renders content from the WordPress API

### Backend
The backend stack will utilize LastSaaS open source SaaS starter template. 

#### LastSaaS (WASP + Stripe + Auth / Go)
This is react powered by WASP for the front end with a super lightweight backend in Go. Includes Stripe integration, Multi-tenancy Authentication, and significantly speed up the process of of scaffolding the application piping.

### Network/CDN

#### Cloudflare
Production and staging sites should be setup to use the Cloudflare CDN. They should also be adding zero trust access to the admin section of the WordPress site. 

#### NGINX/Caddy
This will serve as the reverse proxy to ensure that traffic is routed to the correct places. 

## Deployment & Setup
### Production

#### The Infrastructure Layout (On DigitalOcean)

To keep costs low while giving yourself room to scale, you can pack everything onto **one or two standard Droplets**.

##### Option A: The "All-in-One" Droplet ($12–$18/mo)

Because Go and Astro use virtually zero background memory, you can comfortably host all components on a single **$12/month Droplet** (2GB RAM / 1 vCPU) or an **$18/month Premium Intel/AMD Droplet** for faster build times.

##### Option B: The Isolated Stack ($24/mo)

- **Droplet 1 ($12/mo):** Hosts the production SaaS (Go API + React SPA) and your Headless WordPress CMS.
- **Droplet 2 ($12/mo):** Act as your staging/build environment or database node. (Though highly optional for launch).

#### The Container Architecture (Docker Compose)

On your main DigitalOcean Droplet, you will run a single `docker-compose.yml` file that manages three isolated environments.

[Image outlining a single Droplet running Docker containers for: 1. LastSaaS Go Backend, 2. WordPress + MySQL, 3. Caddy/Nginx reverse proxy, with Astro deploying statically to a CDN]

##### 1. The Headless WordPress Block

- **Container 1:** `wordpress:latest` (Configured to only serve the REST/GraphQL API).
- **Container 2:** `mysql:8.0` or `mariadb` (Isolated securely within the internal Docker network—never exposed to the public internet).

##### 2. The LastSaaS Product Block

- **Container 3:** Your compiled LastSaaS Go backend binary. (Idles at ~20MB RAM).
- **Container 4:** A lightweight web server (like Nginx or Caddy) serving the static production build of your React/Vite SPA dashboard.

##### 3. The Reverse Proxy (The Gateway)

- **Container 5:** A **Caddy Server** or **Nginx Proxy Manager** container. This listens to public ports `80` and `443`. It looks at the incoming URL and routes traffic internally:
    
    - Traffic to `api.yoursite.com` ➡️ Routes to the Go Backend container.
    - Traffic to `app.yoursite.com` ➡️ Routes to the React SPA container.
    - Traffic to `cms.yoursite.com` ➡️ Routes to the WordPress container (hidden behind a strong basic-auth or Cloudflare Access rule so only you can log in).


##### Where does Astro live? (DigitalOcean App Platform or Spaces)

You **do not** need to run a 24/7 server container for Astro. When you run `astro build`, it spits out pure static HTML/JS files.

- **The Best Setup:** Deploy your Astro folder to **DigitalOcean App Platform (Static Sites)**. It is **100% free** for up to 3 static websites. It connects directly to your GitHub repo, builds automatically when you push code, and serves it from DigitalOcean’s native edge CDN.

#### The Cloudflare Routing & CDN Layer

Cloudflare sits directly in front of DigitalOcean, acting as your security shield and caching vanguard.

```
                  ┌───► [Cloudflare CDN] ───► Astro Static Site (yoursite.com)
                  │
[User Request] ───┼───► [Cloudflare Proxy] ───► Droplet Proxy (app.yourdomain.com)
                  │
                  └───► [Cloudflare Access] ───► Droplet Proxy (cms.yourdomain.com)
```

##### 1. Root Domain (`yoursite.com` & `[yoursite.com/blog](https://yoursite.com/blog)`)

Point this to your static Astro deployment. Turn on **Cloudflare's Aggressive Caching**. Because your landing page and blog are static HTML generated from your headless WordPress during build time, Cloudflare will cache 99% of your traffic at the edge. If an article goes viral, your DigitalOcean droplet won't even notice—Cloudflare handles the load.

##### 2. SaaS Application Subdomain (`app.yourdomain.com` & `api.yourdomain.com`)

Point these to your DigitalOcean Droplet's public IP address with the Cloudflare proxy (Orange Cloud) **turned ON**.

- **For the React App (`app.`):** Cache everything. The React SPA is just static assets that fetch data dynamically.
- **For the Go API (`api.`):** Configure a Cloudflare **Page Rule** to **Bypass Cache**. You want your API requests to hit the Go server instantly without Cloudflare caching dynamic database responses.

##### 3. The CMS Subdomain (`cms.yourdomain.com`)

Point this to your Droplet to access your WordPress dashboard.

- **Solo Dev Security Hack:** Use **Cloudflare Zero Trust / Access** (Free for up to 50 users). You can wrap `cms.yourdomain.com` in a rule that requires a one-time pin sent to your personal email before the WordPress login screen even loads. This completely eliminates automated bot scripts trying to brute-force your `wp-admin`.

#### The Content Update Workflow

As a solo dev, you don't want to manually trigger a server deployment every time you publish a blog post in WordPress.

1. You log into `cms.yourdomain.com` and write a post.
2. When you hit "Publish," a WordPress webhook plugin (like _WP Webhooks_) automatically fires a ping to your DigitalOcean App Platform deploy hook.
3. DigitalOcean automatically wakes up, pulls down the fresh content via the WordPress API, rebuilds your Astro static files, and updates your live site in under a minute.

This infrastructure costs almost nothing, scales effortlessly to hundreds of thousands of views via Cloudflare, and protects your production application logic from your content management workflows.

### Local
Running this entire architecture locally with a single `docker-compose up` command is the ultimate way to develop. It ensures your local environment completely mirrors production, preventing any "it worked on my machine" deployment headaches.

To make this seamless for a solo dev, you can use a unified project folder structure where **Docker Compose** orchestrates all four components concurrently: the LastSaaS Go Backend, the React Dashboard, the Headless WordPress instance, and Astro.

#### 1. The Ideal Project Directory Structure

Plaintext

```
my-saas-ecosystem/
├── docker-compose.yml
├── .env.local
├── marketing-site/       # Astro project
│   ├── Dockerfile.dev
│   └── src/
├── saas-app/             # React App (Vite)
│   ├── Dockerfile.dev
│   └── src/
├── saas-backend/         # Go Backend (LastSaaS)
│   ├── Dockerfile.dev
│   └── main.go
└── wp-content-data/      # local volume for WordPress media/db
```

#### 2. The Unified `docker-compose.yml`

This single file spins up your backend database, WordPress CMS, Go API, React frontend, and Astro marketing engine. It maps local volumes so that any time you save a code file locally, the containers update instantly.

YAML

```
version: '3.8'

services:
  # 1. DATABASE FOR WORDPRESS
  wp-db:
    image: mariadb:10.11
    container_name: saas-wp-db
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wp_user
      MYSQL_PASSWORD: wp_password
    volumes:
      - wp_db_data:/var/lib/mysql
    networks:
      - saas-network

  # 2. HEADLESS WORDPRESS CMS
  wordpress:
    depends_on:
      - wp-db
    image: wordpress:latest
    container_name: saas-wordpress
    ports:
      - "8080:80" # Accessible at http://localhost:8080/wp-admin
    environment:
      WORDPRESS_DB_HOST: wp-db:3306
      WORDPRESS_DB_USER: wp_user
      WORDPRESS_DB_PASSWORD: wp_password
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wp_uploads:/var/www/html/wp-content/uploads
    networks:
      - saas-network

  # 3. LASTSAAS GO BACKEND
  go-api:
    build:
      context: ./saas-backend
      dockerfile: Dockerfile.dev
    container_name: saas-go-api
    ports:
      - "5001:5001" # API accessible at http://localhost:5001
    volumes:
      - ./saas-backend:/app
    environment:
      - DATABASE_URL=postgres://user:pass@your-db-host:5432/db # (Or a separate local postgres container)
      - STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY}
    networks:
      - saas-network

  # 4. REACT DASHBOARD FRONTEND (Vite)
  react-app:
    build:
      context: ./saas-app
      dockerfile: Dockerfile.dev
    container_name: saas-react-dashboard
    ports:
      - "3000:3000" # Dashboard at http://localhost:3000
    volumes:
      - ./saas-app:/app
      - /app/node_modules
    environment:
      - VITE_API_URL=http://localhost:5001
    networks:
      - saas-network

  # 5. ASTRO MARKETING SITE
  astro-site:
    build:
      context: ./marketing-site
      dockerfile: Dockerfile.dev
    container_name: saas-astro-marketing
    ports:
      - "4321:4321" # Marketing site at http://localhost:4321
    volumes:
      - ./marketing-site:/app
      - /app/node_modules
    environment:
      - WORDPRESS_API_URL=http://wordpress/wp-json/wp/v2 # Pulls internally via Docker network
    networks:
      - saas-network

networks:
  saas-network:
    driver: bridge

volumes:
  wp_db_data:
  wp_uploads:
```

#### 3. The Local Development Secret: Hot Reloading (Watch Mode)

To make sure your code updates without restarting Docker, you use lightweight **Development Dockerfiles** that leverage host volume mounting and package hot-reloading.

##### For Astro & React (`Dockerfile.dev`)

Both frontend frameworks use Vite or similar dev servers that native Docker can watch.

Dockerfile

```
FROM node:lts-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 4321
# Tells the framework dev server to respond to local changes
CMD ["npm", "run", "dev", "--", "--host"] 
```

##### For LastSaaS Go Backend (`Dockerfile.dev`)

Go code needs to be compiled. To avoid manually recompiling your Go binary every time you write a line of backend code, you use a utility called **Air** for live-reloading.

Dockerfile

```
FROM golang:1.22-alpine
WORKDIR /app
# Install Air for hot-reloading Go code
RUN go install github.com/air-verse/air@latest
COPY go.mod go.sum ./
RUN go mod download
COPY . .
CMD ["air"]
```

#### The Workflow: How You Develop Day-to-Day

1. Run `docker-compose up` in your root terminal.
2. Open `http://localhost:8080/wp-admin` to configure WordPress, install your custom post types, and write dummy blog/landing page content.
3. Open `http://localhost:4321` to see your Astro marketing site. Astro queries your local WordPress container over the internal bridge network (`http://wordpress/...`), pulls down your content, and renders it.
4. Open `http://localhost:3000` to work on your actual React product dashboard. Any code modifications you make in your IDE will instantly hot-reload inside the container.
5. If you modify your database structures or routes in the Go API folder, **Air** automatically recompiles the Go binary inside the background container in under a second.

This setup costs you nothing to run locally, ensures your endpoints can cross-communicate exactly like they will in production, and gives you a single command to step into your entire software factory.

