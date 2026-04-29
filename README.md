# KAZI Platform 🟢🟡

> On-Demand Services Platform for South Africa — Uber for Home Services

Built with Flutter · NestJS · PostgreSQL (Supabase) · Railway · Vercel

---

## Project Structure

```
kazi/
├── apps/
│   ├── api/          # NestJS backend API
│   ├── admin/        # React admin dashboard (Vite + Tailwind)
│   └── mobile/       # Flutter apps (customer + provider)
├── packages/
│   ├── shared-types/ # Shared TypeScript types across apps
│   └── ui-tokens/    # Design system tokens (colours, spacing)
├── .github/
│   └── workflows/    # CI/CD (GitHub Actions)
├── railway.toml      # Railway deployment config
└── package.json      # Monorepo root
```

---

## Quick Start

### Prerequisites
- Node.js 20+
- Yarn 1.22+
- Docker (optional, for local Postgres + Redis)
- Flutter 3.x (for mobile)

### 1. Clone & install
```bash
git clone https://github.com/YOUR_ORG/kazi-platform.git
cd kazi-platform
yarn install
```

### 2. Environment setup
```bash
cp apps/api/.env.example apps/api/.env.local
# Fill in your Supabase DATABASE_URL and other keys
```

### 3. Local database (Docker)
```bash
docker-compose up -d
# Starts Postgres on :5432 and Redis on :6379
```

### 4. Start development
```bash
# Backend API (port 3001)
yarn dev:api

# Admin dashboard (port 5173)
yarn dev:admin

# API docs available at: http://localhost:3001/docs
```

---

## Infrastructure (MVP Stack — ~R865/month)

| Service | Provider | Cost/mo | Purpose |
|---------|----------|---------|---------|
| API Hosting | Railway.app | ~R190 | NestJS + Redis |
| Database | Supabase Pro | ~R475 | PostgreSQL + Auth + Storage |
| Admin Hosting | Vercel | Free | React dashboard |
| File Storage | Cloudflare R2 | R0–80 | Documents & images |
| Push Notifications | Firebase FCM | Free | Mobile push |
| SMS OTP | Clickatell | ~R200 | SA phone verification |

> Migrate to AWS af-south-1 when you hit 5,000+ active users/month.

---

## Environment Variables

See `apps/api/.env.example` for all required variables.

### Key services to configure:
- **Supabase** — `DATABASE_URL` from Supabase Dashboard > Settings > Database
- **Railway** — Provides `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD` automatically
- **Clickatell** — SA SMS provider for OTP verification
- **Firebase** — Push notifications (FCM)
- **Peach Payments** — SA card processing
- **Google Maps** — Live provider tracking
- **Cloudflare R2** — Document uploads (ID verification, etc.)

---

## API Modules

| Module | Routes | Description |
|--------|--------|-------------|
| `auth` | `/api/v1/auth/*` | OTP send/verify, JWT tokens |
| `users` | `/api/v1/users/*` | Customer profiles |
| `providers` | `/api/v1/providers/*` | Provider onboarding & management |
| `bookings` | `/api/v1/bookings/*` | Booking engine (instant + scheduled) |
| `services` | `/api/v1/services/*` | Service categories |
| `payments` | `/api/v1/payments/*` | Peach Payments integration |
| `chat` | WebSocket | Real-time messaging |
| `wallet` | `/api/v1/wallet/*` | Customer wallet & provider earnings |
| `reviews` | `/api/v1/reviews/*` | Ratings & reviews |
| `promos` | `/api/v1/promos/*` | Promo codes & referrals |
| `admin` | `/api/v1/admin/*` | Admin panel APIs |
| `notifications` | Internal | Firebase FCM push |

---

## Deployment

### GitHub Secrets required
```
RAILWAY_TOKEN          # From Railway dashboard
VERCEL_TOKEN           # From Vercel dashboard
VERCEL_ORG_ID          # From Vercel
VERCEL_PROJECT_ID      # From Vercel
TEST_DATABASE_URL      # Separate test DB on Supabase
```

### Branch strategy
- `main` → auto-deploys to production (Railway + Vercel)
- `develop` → staging environment
- `feature/*` → PR to develop

---

## Springbok Colour Palette

```
Primary Green:  #006B3F  (Springbok dark green)
Accent Gold:    #FFB81C  (Springbok gold/amber)
White:          #FFFFFF  (Predominantly white backgrounds)
Dark:           #111111  (Text)
```

---

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Commit with conventional commits: `feat:`, `fix:`, `chore:`
3. Push and create a PR to `develop`
4. CI must pass before merge

---

## License

Proprietary — All source code owned by KAZI (Pty) Ltd. All rights reserved.
