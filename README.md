# MKT-SRV

A TypeScript-first marketing server that can email, track, host funnel pages, and power automations (including AI-driven features). The project aims to integrate with Mautic while remaining modular so you can swap providers and infrastructure over time.

## Features

- **Email campaigns**: broadcasts, drip/automation sequences, templating, and provider abstraction (SES/SendGrid/Postmark).
- **Tracking & analytics**: link tracking/redirector, page view tracking, UTM capture, webhooks, and contact timeline.
- **Funnel hosting**: fast Next.js funnel pages with forms, A/B tests, and shared UI primitives.
- **Automations & AI**: rules-based workflows, lead scoring, and optional AI assistants for copy and segmentation.
- **Mautic integration (optional)**: sync contacts, segments, and campaign events.

## Tech Stack (planned)

- **Language**: TypeScript
- **Web app**: Next.js (App Router)
- **Runtime**: Node.js 20+
- **Database**: PostgreSQL (via Prisma)
- **Cache/Queue**: Redis (BullMQ for jobs)
- **Email providers**: pluggable adapters (SES/SendGrid/Postmark)
- **Analytics/Tracking**: first-party tracking pixel + redirector service
- **Mautic**: optional self-host via Docker

> Note: This repository is at project inception; modules will be added incrementally.

## Monorepo layout (proposed)

```
apps/
  web/          # Next.js app for funnels, admin, and public pages
  worker/       # Job runner (queues, scheduled tasks)
packages/
  core/         # Domain models, services, adapters, shared logic
  ui/           # Shared UI components for Next.js
  tracking/     # Pixel, link redirector, and event ingestion
```

## Getting Started

### Prerequisites

- Node.js 20+
- pnpm (or npm/yarn)
- Docker (for optional Mautic or dependencies)

### Setup

1. Clone the repository
   ```bash
   git clone https://github.com/adammmanka/MKT-SRV.git
   cd MKT-SRV
   ```
2. Install dependencies (to be added as code lands)
   ```bash
   pnpm install
   ```
3. Copy environment config
   ```bash
   cp .env.example .env
   ```
4. Fill required environment variables in `.env` (draft list):
   - DATABASE_URL=postgres://...
   - REDIS_URL=redis://...
   - EMAIL_PROVIDER=ses|sendgrid|postmark
   - EMAIL_FROM=marketing@example.com
   - MAUTIC_URL=https://your-mautic.example.com
   - MAUTIC_USERNAME=...
   - MAUTIC_PASSWORD=...
   - NEXT_PUBLIC_SITE_URL=http://localhost:3000
   - ENCRYPTION_KEY=...

### Run Mautic locally (optional)

You can self-host Mautic via Docker for local development. Refer to Mautic's official images and compose examples. A minimal outline:

```bash
docker run -d \
  --name mautic \
  -p 8080:80 \
  -e MAUTIC_DB_HOST=your-db \
  -e MAUTIC_DB_USER=mautic \
  -e MAUTIC_DB_PASSWORD=mautic \
  -e MAUTIC_DB_NAME=mautic \
  mautic/mautic:latest
```

### Development

- Web (Next.js):
  ```bash
  pnpm dev
  ```
- Worker (jobs/queues):
  ```bash
  pnpm worker:dev
  ```

## Deployment

- Next.js hosting (e.g., Vercel) for `apps/web`.
- Worker on a Node runtime (e.g., Fly.io/Render/Heroku) and managed Redis.
- PostgreSQL via a managed service (e.g., Neon, RDS).

## Security & Compliance

- Enforced unsubscribe/opt-out and preference management
- GDPR/CCPA considerations for data collection and subject requests
- Signed links and CSRF protections on forms

## Roadmap

- [ ] Scaffold Next.js app and workspace
- [ ] Tracking pixel and link redirector
- [ ] Email provider abstraction and templates
- [ ] Mautic sync: contacts, segments, campaign events
- [ ] Automations engine and AI helpers

## Contributing

PRs are welcome. Please open an issue to discuss substantial changes or new modules.

## License

MIT
