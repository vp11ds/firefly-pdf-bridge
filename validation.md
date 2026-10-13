# VALIDATION.md — Step-by-step feasibility checks

For each need, run the steps and compare with the expected result. Any FAIL means stop, fix, and rerun before continuing. Never import real statements before all Phase 3 checks pass.

## V1 — Single login
1. Fresh browser profile -> `https://firefly.test:8080` -> expect Authelia login.
2. Log in with password + TOTP -> Firefly opens with no second prompt.
3. `https://importer.firefly.test:8080` -> importer home, no login/token screen.
4. `https://bridge.firefly.test:8080` -> bridge UI, no login.
5. `curl` with a spoofed auth header and no cookie -> expect redirect to Authelia, not an authenticated response.

PASS = one login opens all three apps; spoof rejected.

## V2 — One endpoint
1. `ss -tlnp | grep 8080` -> only Caddy on `127.0.0.1:8080`.
2. Attempt direct host connections to app/importer/database ports -> connection refused.

PASS = nothing is reachable from the host except through Caddy.

## V3 — PDF bridge accuracy
1. Push `sample_rbc_canada.pdf` -> compare bridge row count with PDF line items.
2. Spot-check five amounts and debit/credit signs against the PDF.
3. Repeat for `sample_synthetic_eur.pdf`.
4. Re-push both -> zero new transactions.

PASS = counts match, signs are correct, and dedupe holds.

## V4 — Tags AND/OR/NOT
1. Rule: description contains `TIM HORTONS` -> tag `coffee`.
2. Manually tag two transactions with `review`.
3. Search `coffee` AND `review` -> exactly two rows.
4. Search `coffee` NOT `review` -> remaining coffee rows only.

PASS = Boolean tag search is exact.

## V5 — Transfers
1. Link a withdrawal/deposit pair as a transfer (rule or manual).
2. Compare income/expense reports before and after linking.

PASS = the transfer is not double-counted in income/expense.

## V6 — Dashboards and reports
1. Save a tag-filtered selection; add its chart to a dashboard; reload.

PASS = saved selections drive persistent dashboard charts.

## V7 — Selective export
1. Select three transactions by checkbox and export CSV.

PASS = export contains exactly the three selected rows.

## V8 — TEST/REAL isolation
1. After TEST imports, query the REAL database.

PASS = REAL contains zero TEST transactions.

## V9 — Encrypted Cloudflare export confidentiality
1. Publish TEST data with a test passphrase.
2. Download live `data.enc.bin`; `file` identifies opaque data.
3. Inspect page source; no amounts/descriptions are present before decryption.
4. Enter wrong passphrase.

PASS = Cloudflare holds ciphertext only and wrong-passphrase decryption fails cleanly.

## V10 — One-click publish
1. Add a tag in Firefly, then use bridge Publish and enter the passphrase.
2. Open the live URL and decrypt the export.

PASS = latest tag appears after decryption.

## V11 — Backup and restore
1. Dump TEST DB, encrypt the backup, restore into a fresh TEST volume, and compare counts.

PASS = restore reproduces the original counts.

## V12 — Manual transactions
1. Add a manual transaction, tag it, then find it by tag search and in reports.

PASS = manual transactions participate in search and reports.

## Phase 0 checks
1. From `app2/`, validate config: `docker compose --project-directory . -f firefly/docker-compose.yml config --quiet`.
2. Generate the local `.env` and Authelia user DB using the documented setup scripts.
3. Add `127.0.0.1 firefly.test importer.firefly.test bridge.firefly.test auth.firefly.test` to `/etc/hosts` and trust Caddy's local root CA.
4. Start from `app2/`: `docker compose --project-directory . -f firefly/docker-compose.yml up -d`.
5. `docker compose --project-directory . -f firefly/docker-compose.yml ps` -> db, proxy, SSO, Firefly and importer are running.
6. `ss -tlnp` -> only `127.0.0.1:8080` is published by this stack.
7. Visit each `https://*.firefly.test:8080` hostname. Unauthenticated access redirects to Authelia; after TOTP, apps open without extra prompts.
8. Send client-supplied `Remote-Email` and `Remote-User` headers without an Authelia cookie -> no app session is granted.

PASS = SSO protects every app host, spoofed headers are discarded, and Caddy is the sole host-published service.
