# Singularity

Personal data platform combining a vault (file storage), AI agents, and social coordination via circles.

## Stack

- **Elixir/Phoenix 1.8** with LiveView
- **Postgres 17** with pgvector (optional, graceful fallback)
- **daisyUI** + Tailwind for UI components
- **Swoosh + Resend** for email
- **Fly.io** for hosting (auto-deploys from main via GitHub Actions)

## Architecture

### Core Domains

- **Vault** (`Singularity.Vault`) — flat file storage with optional folder paths. No collections — files belong directly to users. Ingestion pipeline extracts metadata/text per content type.
- **Circles** (`Singularity.Circles`) — named groups of users for sharing. Share files with a circle at metadata/read/write access levels.
- **Agents** (`Singularity.Agents`) — AI agent definitions with GenServer runtime. Each agent is a supervised process via DynamicSupervisor + Registry.
- **Feed** (`Singularity.Feed`) — append-only event log with PubSub real-time broadcast.
- **Permissions** (`Singularity.Permissions`) — legacy per-user grants, being replaced by circles.

### Key Patterns

- Contexts follow standard Phoenix conventions (`lib/singularity/<context>.ex` + `lib/singularity/<context>/*.ex`)
- LiveView pages at `lib/singularity_web/live/`
- Agent runtime: `Singularity.Agents.Runtime` GenServer, registered via `Singularity.Agents.Registry`
- Ingestion: pluggable handler behaviour (`Singularity.Ingestion.Handler`), currently text + generic

## Development

```bash
mix setup          # install deps, create db, migrate, build assets
mix phx.server     # start at localhost:4000
mix ecto.migrate   # run migrations
mix test           # run tests
```

## Deployment

- **Fly.io**: `fly deploy` or push to main (auto-deploys via `.github/workflows/fly-deploy.yml`)
- **Render**: also configured via `render.yaml` (secondary)
- Secrets on Fly: `SECRET_KEY_BASE`, `DATABASE_URL`, `RESEND_API_KEY`, `MAIL_FROM`

## Email

- Resend adapter in prod, local adapter in dev (`/dev/mailbox`)
- Domain: `singularity.estefanos.xyz`
- Sender: `noreply@singularity.estefanos.xyz` (via `MAIL_FROM` env var)
