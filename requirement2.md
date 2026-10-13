# REQUIREMENT2.md — Bank Statements on Firefly III

Strategy: deploy the mature open-source app and build only the missing pieces (PDF bridge + one-click publisher).

Rules for every phase:
- Everything runs in Docker. Caddy is the only published port: `127.0.0.1:8080`.
- One login: Authelia password + TOTP gate in front of Firefly, importer, and bridge.
- TEST stack contains sample/synthetic data only. REAL stack comes only after Phase 3.
- Bridge/publisher makes no unexpected network calls. Cloudflare upload happens only on button click.
- Mask account numbers to the last 4 digits everywhere.

## Phase 0 — One login, one entrypoint (TEST stack)
Files: `firefly/docker-compose.yml`, `firefly/Caddyfile`, `firefly/authelia/`

- Services: Caddy proxy, Authelia SSO, Firefly III, importer, MariaDB. Only Caddy publishes `127.0.0.1:8080`; application and database ports are not published.
- Caddy applies Authelia forward-auth to Firefly, importer, and bridge. It removes client-supplied identity headers before forward-auth and only forwards identity headers returned by Authelia.
- Firefly uses the documented `AUTHENTICATION_GUARD=remote_user_guard`. After bootstrap, configure `AUTHENTICATION_GUARD_HEADER=HTTP_REMOTE_EMAIL`, matching the Authelia `Remote-Email` header and the registered Firefly account email.
- Bootstrap the first Firefly user with the same email as the SSO identity before enabling the remote-user guard. Firefly's remote-user guard delegates all authentication to the proxy and must never be reachable directly.
- Importer uses `FIREFLY_III_ACCESS_TOKEN` (Personal Access Token), not the OAuth browser flow.
- Authelia requires two-factor policy for all app hosts, TOTP, brute-force regulation, and secure session settings appropriate to the transport.
- Stack name: `firefly-test`. Phase 4 adds an isolated `firefly-real` stack; that is the TEST/REAL toggle.
- Compose command from `app2/`: `docker compose --project-directory . -f firefly/docker-compose.yml up -d`.
- Prompt: "Implement Phase 0 of requirement2.md. Prove: only 127.0.0.1:8080 listens; one Authelia login opens Firefly, importer and bridge with no further prompts; a request with a spoofed auth header is rejected, not logged in."
- Done when: single login works end-to-end and `ss -tlnp` shows only Caddy.

## Phase 1 — PDF bridge companion service (custom code #1)
Files: `bridge/` in this repository.

- Behind the same SSO gate; no bridge login. The server calls Firefly REST API with the PAT, never exposed to the browser.
- Upload PDF -> pdfplumber with per-bank YAML profiles (RBC, TD, Chase-like, synthetic) -> normalized rows -> review preview -> explicit push via API.
- Discovery report lists banks/accounts/periods and skipped files with reasons; dedupe by SHA-256; mask account numbers.
- Validate PDF magic bytes and upload-size cap. Bridge joins an internal-only Docker network with Firefly; Caddy can reach the bridge.
- Prompt: "Implement Phase 1 of requirement2.md. Parse the two sample PDFs in data/test_synthetic/, push via the Firefly API, show the discovery report plus row counts."
- Done when: both samples land with correct amounts/signs; re-push sends nothing.

## Phase 2 — Auto-tagging rules
File: `firefly/rules.md`.

- Document each Firefly rule: triggers -> multiple tags, categories, and matched-pair transfers. Manual/bulk tagging fills gaps. The official importer remains available for ad-hoc bank CSVs.
- Prompt: "Walk me through Phase 2: draft the first 10 tagging rules for the sample data and tell me exactly where to create them in the UI."
- Done when: transactions carry multiple automatic and manual tags; a transfer pair is one Firefly transfer, not two loose transactions.

## Phase 3 — Acceptance on TEST stack
No real data until every item passes.

- Fresh browser profile: one login opens all three apps with no additional prompts.
- Spoofed identity-header request is rejected; direct container ports are unreachable.
- Bridge row counts equal Firefly counts; tag AND/OR/NOT search returns exact fixture rows.
- Re-push dedupe passes; outputs/logs contain no full account numbers.
- Only `127.0.0.1:8080` listens on the host.
- Prompt: "Run the Phase 3 checklist from requirement2.md, report pass/fail per item."
- Done when: every item passes.

## Phase 4 — REAL stack
File: `firefly/docker-compose.real.yml`.

- `firefly-real` has separate hostnames, ports, database, and volumes, with the same SSO design.
- Import real statements only after Phase 3, using the bridge and rules. Keep TEST untouched.
- Done when: real data imports cleanly; TEST remains unchanged.

## Phase 5 — Encrypted export + one-click Cloudflare publish (custom code #2)
Files: `export/` in the bridge service.

- Bridge UI has one "Publish to Cloudflare" button. Click prompts for a passphrase held in memory only, pulls the latest Firefly dataset through the local REST API, encrypts AES-256-GCM using PBKDF2-HMAC-SHA256 (600,000 iterations, fresh salt per export), creates a data-free static HTML shell plus `data.enc.bin`, runs `wrangler deploy` to Cloudflare Workers Static Assets using a 0600 env file, and shows the live URL.
- Cloudflare receives ciphertext only; optional Cloudflare Access is an additional gate.
- Prompt: "Implement Phase 5 of requirement2.md."
- Done when: one click publishes end-to-end; direct `data.enc.bin` download is opaque and the page renders only with the correct passphrase.

## Production security checklist

- Publish only `127.0.0.1:8080`; pin image tags, never `latest`.
- Firefly: `APP_DEBUG=false`, `APP_ENV=production`.
- Secrets in mode-0600 `.env` files, never Git; `.env.example` contains placeholders only. Generate strong APP_KEY and database passwords.
- Authelia: enforce TOTP, brute-force regulation, HttpOnly/Secure/SameSite cookies. Secure cookies require HTTPS; plain HTTP is TEST-only and cannot satisfy this production item.
- Caddy: set security headers and strip client authentication headers before forward-auth.
- MariaDB has no published port and strong unique root/app passwords.
- Encrypt DB backups before real imports and test one restore on TEST.
- Quarterly pinned-image updates: TEST first.

## Implementation constraints and compatibility notes

- The requested hostnames `firefly.local`, `importer.local`, and `bridge.local` are sibling domains, not subdomains of one common cookie domain. A browser cannot reliably share one Authelia session cookie across them. The implementation therefore uses `firefly.test`, `importer.firefly.test`, `bridge.firefly.test`, and `auth.firefly.test`, all mapped to `127.0.0.1`, with the Authelia cookie domain `firefly.test`. These are TEST-only local names.
- Authelia session cookies are Secure and HttpOnly. The TEST stack serves HTTPS with Caddy's local internal CA on the single published port `127.0.0.1:8080`; trust that local CA in the test browser/host.
- Bootstrap is an explicit temporary stage: keep Firefly's local `web` guard while registering the matching email behind Authelia, create a PAT, set it in `.env`, then switch to `remote_user_guard` and restart. Do not expose Firefly directly during bootstrap.
- Phase 0 provides a small authenticated bridge placeholder page; PDF parsing/pushing is Phase 1.
