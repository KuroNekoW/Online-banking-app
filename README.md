# Mobile Online Banking System

Mobile banking MVP for SE113. It consists of a Flutter client in `app/`, a FastAPI backend in `backend/`, and PostgreSQL. The functional specification is in [`docs/docs.docx`](docs/docs.docx); the database diagram source is [`docs/database-erd.puml`](docs/database-erd.puml).

## Project handoff

This README is the technical starting point for anyone continuing the project. The database schema, primary API groups, and the first backend test suite are implemented and verified.

Current implementation status:

- PostgreSQL schema and Alembic migrations are complete for the MVP entities.
- Baseline `CUSTOMER`/`ADMIN` roles, permissions, and an idempotently seeded Admin are present.
- API supports authentication, registration OTP, profile/accounts, beneficiaries, transfers, transaction history, notifications, and Admin-lite operations.
- Backend tests run against an isolated PostgreSQL instance and cover the critical auth, authorization, ownership, idempotency, and internal-ledger path.

## Architecture and important paths

| Path | Responsibility |
| --- | --- |
| `app/` | Flutter client for authentication, accounts, transfers, transaction history, beneficiaries, notifications, and profile management. See [`app/README.md`](app/README.md) for frontend setup and API connection details. |
| `backend/main.py` | FastAPI application and router registration. |
| `backend/app/api/` | HTTP routers: `auth.py`, `customer.py`, `transfers.py`, `admin.py`. |
| `backend/app/db/models.py` | SQLAlchemy mapping for all current banking tables and enums. |
| `backend/alembic/versions/` | Schema migrations; never edit an applied migration in a shared environment. |
| `backend/app/services/otp.py` | OTP creation/verification policy. |
| `backend/app/services/otp_delivery.py` | SMTP OTP delivery to local Mailpit. |
| `backend/tests/` | Integration-style backend tests and shared fixtures. |
| `docker-compose.yml` | Development API/PostgreSQL and the isolated `postgres-test` profile. |

## Run the development stack

1. Copy `.env.example` to `.env` and replace the sample credentials and JWT secret.
2. Start the stack (API, PostgreSQL, and local email inbox):

   ```powershell
   docker compose up --build
   ```

3. Browse the OpenAPI contract at `http://localhost:8000/docs`, call `http://localhost:8000/health`, and view OTP emails at `http://localhost:8025`.

The API container automatically runs `alembic upgrade head` and then the idempotent seed command. For direct local backend development, copy `backend/.env.example` to `backend/.env`, install `backend/requirements.txt`, and run Alembic from `backend/`.

The default development Admin is configured by `SEED_ADMIN_EMAIL` and `SEED_ADMIN_PASSWORD`. Never deploy with the sample `.env` values.

## Run the Flutter frontend

Start the backend stack first with `docker compose up --build -d`, then verify that `http://127.0.0.1:8000/health` returns `{"status":"ok"}`. In PowerShell, move into `app/`, install dependencies, and run the client on Chrome:

```powershell
Set-Location .\app
flutter pub get
flutter run -d chrome
```

Flutter Web and Windows desktop default to `http://127.0.0.1:8000`; the Android emulator uses `http://10.0.2.2:8000`. The backend allows local `localhost` and `127.0.0.1` origins for Web development. For a physical device, configure the computer's LAN IP in the login or profile API settings. See [`app/README.md`](app/README.md) for prerequisites, Android/Windows instructions, and troubleshooting.

## API implementation map

OpenAPI (`/docs`) is the canonical request/response contract. The main paths are:

| Area | Endpoints |
| --- | --- |
| System | `GET /health` |
| Authentication | `POST /auth/register`, `/auth/register/verify`, `/auth/otp/{challenge_id}/resend`, `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/password-reset`, `/auth/password-reset/confirm`, `/auth/change-password`; `GET /auth/me` |
| Customer | `GET/PATCH /profile`; `GET /accounts`, `/accounts/{id}`, `/accounts/{id}/balance`; beneficiary CRUD; `GET /transactions`, `/transactions/{id}`; notifications list/read |
| Transfers | `POST /transfers`, `POST /transfers/{id}/confirm`, `POST /transfers/{id}/authenticate`, `GET /transfers/{id}`, `GET /transfers/by-reference/{reference}` |
| Admin | Customer list/detail/lock/unlock, roles, role assignment, and audit-log listing under `/admin` |

All protected endpoints require `Authorization: Bearer <access_token>`. A refresh token is hashed at rest and rotated at `POST /auth/refresh`.

## Business invariants

These rules are essential when modifying the transfer or ledger code:

- `banking.transaction_entries` is the balance source of truth. Do **not** store a mutable balance column or update balance directly.
- A posted transaction must sum to zero. A debit entry is negative; a credit entry is positive.
- Create a ledger transaction as `pending`, insert both entries, then set it to `posted`. The database rejects entries added to a posted transaction and also rejects an unbalanced posting at commit time.
- Posted ledger entries are immutable. Correct a mistake with a reversing transaction.
- Transfer creation is idempotent per customer and `idempotency_key`.
- Accounts, beneficiaries, transactions, and transfers must always be constrained to the current authenticated owner; never trust a client-supplied user ID.
- Admin lock revokes active sessions. Admin endpoints must use `get_current_admin` rather than only checking that a token exists.
- OTP and refresh-token secrets are stored as hashes. Never return or log an OTP in a production HTTP response.

## OTP delivery

Local development sends OTP emails through Mailpit. `docker compose up --build` starts Mailpit with:

- Web inbox: `http://localhost:8025`
- SMTP relay for the API: `mailpit:1025` inside Docker; port `1025` is also exposed on the host.

Messages are captured locally and are not sent to real mailboxes. The OTP is not included in API
responses or application logs. Open the inbox, select the latest message for the recipient email,
and enter its six-digit code in the app.

### Registration OTP flow

1. The frontend calls `POST /auth/register` with `email`, `phone`, `full_name`, and `password`.
2. The API returns `challenge_id` and `expires_at`, then sends the code to Mailpit.
3. The user reads the code at `http://localhost:8025` and enters it in the frontend.
4. The frontend calls `POST /auth/register/verify` with `{ "challenge_id": "...", "code": "123456" }`.
5. To request another code, call `POST /auth/otp/{challenge_id}/resend`. The existing challenge
   is rotated; its resend cooldown and send limit apply.

Transfer authentication follows the same pattern: call `POST /transfers/{id}/confirm`, read the
email in Mailpit, then submit `{ "code": "123456" }` to
`POST /transfers/{id}/authenticate`.

OTP expiry, attempt count, resend cooldown, and resend count are controlled by `OTP_EXPIRY_MINUTES`,
`OTP_MAX_ATTEMPTS`, and `OTP_RESEND_COOLDOWN_SECONDS` settings. Mailpit needs no account or external
credentials. Tests replace the SMTP delivery adapter with an in-memory fake.

For deployment beyond local demo, replace Mailpit with an authenticated email/SMS provider, manage
provider credentials through secrets, and add delivery-failure handling and monitoring.

## Backend tests

Tests use `postgres-test`, a disposable database on port `5433`; they never connect to the development database on port `5432`. The suite runs the real Alembic migration chain, truncates and reseeds its own data before every test, and uses a fake OTP delivery provider.

Run from the repository root:

```powershell
docker compose --profile test up -d postgres-test
docker compose run --rm -e PYTHONPATH=/code -e TEST_DATABASE_URL=postgresql+psycopg://banking_test:banking_test_password@postgres-test:5432/banking_test api pytest -q
docker compose --profile test rm -s -f postgres-test
```

Use `-vv -s` instead of `-q` to see each named test, or run one module:

```powershell
docker compose run --rm -e PYTHONPATH=/code -e TEST_DATABASE_URL=postgresql+psycopg://banking_test:banking_test_password@postgres-test:5432/banking_test api pytest -vv -s tests/test_transfers.py
```

Current test coverage:

- Registration + OTP verification creates a Customer with an account.
- Customer cannot use Admin endpoints or access another customer's account/beneficiary.
- Admin lock revokes an active Customer session.
- Internal transfer rejects insufficient funds, is idempotent, requires OTP, changes both balances, and produces a balanced ledger transaction.

Test setup and concrete request data are in `backend/tests/conftest.py`; individual scenarios are in `test_auth.py`, `test_customer.py`, and `test_transfers.py`.

## Remaining work

Prioritize these items before considering the backend production-ready:

1. Add test coverage for refresh/logout, password reset, OTP resend/expiry/attempt limits, notifications, pagination, role assignment, audit logs, and interbank state transitions.
2. Enforce the documented failed-login threshold using `failed_login_count` and lock the user when the configured limit is exceeded.
3. Replace Mailpit with a genuine OTP email/SMS provider and add delivery observability before deployment.
4. Add interbank simulation reconciliation so `pending_external` can become `completed` or `failed`.
5. Add stable Pydantic response schemas to every endpoint instead of returning ORM objects in a few list/detail routes.
6. Add CI to run the PostgreSQL test suite on every pull request, then integrate the Flutter client.

When changing schema, create a new Alembic revision and add/adjust tests in the same change. Re-run the test command above before handing off work.
