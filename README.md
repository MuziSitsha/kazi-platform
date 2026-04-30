# KAZI Platform

> Johannesburg-first on-demand services MVP for South Africa

Built for the KAZI client brief with Flutter, NestJS, PostgreSQL, and an AWS deployment target.

---

## Current MVP Status

```
kazi/
├── apps/
│   ├── api/          # NestJS backend API
│   ├── admin/        # React admin dashboard foundation
│   └── mobile/       # Flutter customer/provider app foundation
├── .github/
│   └── workflows/    # CI and deployment workflows
├── docs/             # Delivery and architecture docs
├── packages/
│   └── ui-tokens/    # Springbok design tokens
├── infra/
│   └── aws/          # AWS deployment templates
└── package.json      # Monorepo root
```

The repository contains a working MVP foundation for the customer app, provider app, and admin dashboard, with launch-critical integrations prepared for Firebase push, Twilio calling, Peach Payments, and AWS deployment.

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
# Fill in your PostgreSQL DATABASE_URL and other keys
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

# Flutter mobile app
cd apps/mobile
flutter pub get
flutter run

# API docs available at: http://localhost:3001/docs
```

---

## Delivery Plan

### Target stack
- Mobile apps: Flutter
- Backend API: NestJS
- Database: PostgreSQL
- Hosting: AWS

### Delivery phases
1. Backend foundation and auth
2. Booking engine, provider onboarding, and service catalogue
3. Payments, wallet, reviews, and admin operations
4. Flutter customer/provider apps and hosted checkout flow
5. Remaining realtime modules, launch hardening, and go-live readiness

### Timeline estimate
- Remaining engineering and hardening from the current repository state: roughly 2 to 4 focused weeks
- Fresh MVP build from scratch on the same scope: roughly 10 to 14 weeks

### AWS MVP cost estimate

| Service | Provider | Cost/mo | Purpose |
|---------|----------|---------|---------|
| API compute | AWS ECS Fargate or App Runner | ~R1,200–3,000 | NestJS API |
| Database | AWS RDS PostgreSQL | ~R1,000–2,500 | Primary relational database |
| Redis | AWS ElastiCache Redis | ~R700–1,500 | Jobs, throttling, caching |
| File storage | AWS S3 | ~R100–400 | Documents and images |
| Admin hosting | AWS Amplify or S3 + CloudFront | ~R100–500 | Admin dashboard |
| CDN and traffic | AWS CloudFront | ~R150–800 | Static delivery and caching |
| Push Notifications | Firebase FCM | Free | Mobile push |
| SMS OTP | Clickatell | ~R200 | SA phone verification |

Expected AWS MVP operating range: roughly R3,450 to R8,900 per month, depending on traffic and whether you run one or two API tasks.

---

## Environment Variables

See `apps/api/.env.example` for all required variables.

### Key services to configure:
- **AWS RDS PostgreSQL** — `DATABASE_URL`
- **AWS ElastiCache Redis** — `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`
- **Clickatell** — SA SMS provider for OTP verification
- **Firebase** — Push notifications (FCM)
- **Peach Payments** — SA card processing
- **Google Maps** — Live provider tracking
- **AWS S3** — Document uploads (ID verification, etc.)

---

## API Modules

| Module | Routes | Description |
|--------|--------|-------------|
| `auth` | `/api/v1/auth/*` | OTP send/verify, JWT tokens |
| `users` | `/api/v1/users/*` | Customer profiles |
| `providers` | `/api/v1/providers/*` | Provider onboarding & management |
| `bookings` | `/api/v1/bookings/*` | Booking engine (instant + scheduled) |
| `services` | `/api/v1/services/*` | Service categories |
| `payments` | `/api/v1/payments/*` | Cash settlement, wallet credits, and hosted Peach checkout initiation |
| `chat` | `/api/v1/chat/*` | Booking-scoped chat plus Twilio-ready call bridge |
| `wallet` | `/api/v1/wallet/*` | Customer wallet & provider earnings |
| `reviews` | `/api/v1/reviews/*` | Ratings & reviews |
| `promos` | `/api/v1/promos/*` | Promo codes & referrals foundation |
| `admin` | `/api/v1/admin/*` | Admin panel APIs |
| `notifications` | `/api/v1/notifications/*` | Stored notifications plus Firebase FCM delivery wiring |

## What Is Fully Implemented Now

- Customer auth with OTP and role-aware login
- Provider onboarding, availability, and document verification upload flow
- Service catalogue with instant and scheduled bookings
- Wallet balance and provider earnings bookkeeping
- Ratings and reviews after completed bookings
- Admin platform settings, provider verification queue, analytics summary, and recent payment feed
- Hosted online checkout initiation for card and EFT bookings through Peach Payments
- AWS deployment workflows for the Nest API and the admin dashboard
- Proprietary source ownership declaration in the root license file

## What Still Needs Final Integration Or Validation

- Real Firebase credentials and device-level push validation
- Real Twilio credentials and live call bridge validation
- Real Peach credentials and end-to-end hosted payment validation
- Final Android and iPhone device QA against one reachable API URL
- Final AWS staging and production rollout

---

## Deployment

Production target is AWS in `af-south-1`, fronted by CloudFront and an ALB. The exact topology is documented in [docs/aws-architecture.md](c:\Users\nkazi\OneDrive\Desktop\kazi\docs\aws-architecture.md).

### GitHub Secrets required for AWS CI/CD
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
AWS_ECR_REPOSITORY
AWS_ECS_CLUSTER
AWS_ECS_SERVICE
AWS_ECS_TASK_DEFINITION
TEST_DATABASE_URL      # Separate PostgreSQL test database
AWS_ADMIN_S3_BUCKET
AWS_ADMIN_CLOUDFRONT_DISTRIBUTION_ID
```

### Branch strategy
- `main` → production release branch
- `develop` → staging environment
- `feature/*` → PR to develop

---

## Springbok Colour Palette

```
Primary Green:  #006B3C  (Springbok dark green)
Accent Gold:    #FFB81C  (Springbok gold/amber)
White:          #FFFFFF  (Predominantly white backgrounds)
Dark:           #111111  (Text)
Light Surface:  #F6F7F4  (Warm white surface)
```

### Brand rules
- Predominantly white UI surfaces
- Green used for primary actions, headers, trust signals, and states
- Gold reserved for accent moments, highlights, badges, and CTAs
- Avoid dark-mode-first layouts and avoid generic purple SaaS palettes
- Use the shared token package in [packages/ui-tokens](c:\Users\nkazi\OneDrive\Desktop\kazi\packages\ui-tokens) as the source of truth

## AWS Reference Docs

- [docs/aws-architecture.md](c:\Users\nkazi\OneDrive\Desktop\kazi\docs\aws-architecture.md)
- [docs/client-delivery-plan.md](c:\Users\nkazi\OneDrive\Desktop\kazi\docs\client-delivery-plan.md)

---

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Commit with conventional commits: `feat:`, `fix:`, `chore:`
3. Push and create a PR to `develop`
4. CI must pass before merge

---

## License

See the root [LICENSE](c:\Users\nkazi\OneDrive\Desktop\kazi\LICENSE) file. The repository is proprietary and source ownership remains with KAZI (Pty) Ltd.
