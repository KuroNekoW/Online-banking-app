# Online banking app

## Start the database and API

1. Copy `.env.example` to `.env` and replace the sample password.
2. Run `docker compose up --build`.
3. Open `http://localhost:8000/docs` or check `http://localhost:8000/health`.

The API container runs `alembic upgrade head` before it starts. For local backend development, copy `backend/.env.example` to `backend/.env`, install `backend/requirements.txt`, then run `alembic upgrade head` from `backend`.

## Data model

`banking.transaction_entries` is the source ledger. Every posted transaction must sum to zero; an outgoing account entry is negative and an incoming entry is positive. The database rejects an unbalanced posted transaction at commit time. Keep posted ledger entries immutable; correct an error by recording a reversing transaction.

## MVP database coverage

The schema implements the MVP use cases in `docs.docx`: registration and OTP verification (`registration_requests`, `otp_challenges`), login and revocable sessions (`auth_sessions`), customer/admin roles (`roles`, `permissions`, `user_roles`), beneficiary management, internal/interbank-simulation transfer workflow (`transfers`), immutable ledger entries, notifications, and administrator audit logs. OTPs and refresh tokens are stored only as hashes.

The ERD source is available in [`docs/database-erd.puml`](docs/database-erd.puml).
